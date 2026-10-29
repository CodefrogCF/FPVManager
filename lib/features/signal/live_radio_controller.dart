import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';
import 'radio_analysis.dart';

class LiveRadioSettings {
  const LiveRadioSettings({
    this.enabled = false,
    this.useSpawn = true,
    this.signal = const SignalSettings(
      pilot: Wgs84Coordinate(latitude: 46.8, longitude: 8.3),
    ),
  });
  final bool enabled, useSpawn;
  final SignalSettings signal;
}

class LiveRadioController extends ChangeNotifier {
  LiveRadioController({
    required this.send,
    required this.sample,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Future<void> Function(Map<String, dynamic>) send;
  final Future<List<double>> Function(List<Wgs84Coordinate>) sample;
  final DateTime Function() now;
  LiveRadioSettings settings = const LiveRadioSettings();
  String status = 'Disabled';
  RadioPathResult? result;
  RadioPathSample? obstruction;
  DateTime? calculatedAt;
  Wgs84Coordinate? transmitter;
  double? transmitterHeight;
  bool loading = false,
      current = false,
      _disposed = false,
      _available = false,
      _active = false,
      _paused = false;
  int _revision = 0, _flightId = -1;
  bool _monitorEnabled = false;
  ({Wgs84Coordinate position, Wgs84Coordinate home, double height})? _pose;
  DateTime? _lastAttempt;
  Timer? _expiry;
  Future<void>? _pending;
  Future<void> get settled => _pending ?? Future.value();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> configure(LiveRadioSettings value) async {
    value.signal.validate();
    settings = LiveRadioSettings(
      enabled: value.enabled,
      useSpawn: value.useSpawn,
      signal: SignalSettings.fromJson(value.signal.toJson()),
    );
    _pose = null;
    _active = false;
    _lastAttempt = null;
    _invalidate(clear: true);
    status = value.enabled ? 'Waiting for an active flight' : 'Disabled';
    _notify();
    await _syncMonitor();
    if (settings.enabled) _schedule();
  }

  void renderer(bool available) {
    _available = available;
    _active = false;
    _pose = null;
    _flightId = -1;
    _lastAttempt = null;
    _invalidate(clear: true);
    status = settings.enabled ? 'Terrain / renderer unavailable' : 'Disabled';
    _notify();
    if (available) unawaited(_syncMonitor().catchError((Object _) {}));
  }

  void _invalidate({bool clear = false}) {
    ++_revision;
    current = false;
    loading = false;
    _expiry?.cancel();
    if (clear) {
      result = null;
      obstruction = null;
      calculatedAt = null;
      transmitter = null;
      transmitterHeight = null;
    }
    unawaited(_mapUnknown());
  }

  Future<void> _mapUnknown() async {
    if (!_available || _disposed || !settings.enabled) return;
    try {
      await send({
        'type': 'set-live-radio-result',
        'revision': _revision,
        'state': 'unknown',
        'message': settings.enabled
            ? 'Unknown · open radio details'
            : 'Disabled',
        'rays': [],
      });
    } catch (_) {}
  }

  void terrainChanged(bool available) {
    _available = available;
    _lastAttempt = null;
    _invalidate(clear: true);
    status = available
        ? 'Terrain changed; awaiting a new profile'
        : 'Terrain unavailable';
    _notify();
    if (available) unawaited(_syncMonitor().catchError((Object _) {}));
  }

  Future<void> _syncMonitor() async {
    if (!_available || _disposed || (!settings.enabled && !_monitorEnabled)) {
      return;
    }
    final enabled = settings.enabled;
    await send({
      'type': 'set-flight-radio-monitor',
      'revision': _revision,
      'enabled': enabled,
    });
    _monitorEnabled = enabled;
  }

  void telemetry(Map<String, dynamic> data) {
    if (!settings.enabled || _disposed) return;
    final active = data['active'],
        paused = data['paused'],
        id = data['flightId'];
    if (active is! bool || paused is! bool || id is! int) return;
    double read(String key, double min, double max) {
      final v = data[key];
      if (v is! num || !v.isFinite || v < min || v > max) {
        throw const FormatException('Invalid live position');
      }
      return v.toDouble();
    }

    try {
      final modeChanged =
          id != _flightId || active != _active || paused != _paused;
      if (id != _flightId) {
        _flightId = id;
        _lastAttempt = null;
        _invalidate(clear: true);
      }
      _active = active;
      _paused = paused;
      if (!active || paused) {
        if (!modeChanged) return;
        status = paused
            ? 'Paused · last calculation is not live'
            : 'Flight ended';
        _invalidate();
        _notify();
        return;
      }
      _pose = (
        position: Wgs84Coordinate(
          latitude: read('latitude', -89.9, 89.9),
          longitude: read('longitude', -180, 180),
        ),
        home: Wgs84Coordinate(
          latitude: read('homeLatitude', -89.9, 89.9),
          longitude: read('homeLongitude', -180, 180),
        ),
        height: read('height', -100000, 100000),
      );
      if (current &&
          result != null &&
          (routeDistance(_pose!.position, result!.target) > 100 ||
              (_pose!.height - result!.altitude!).abs() > 30)) {
        status = 'Drone moved beyond the last profile';
        _invalidate();
        _notify();
      }
      _schedule();
    } on FormatException {
      status = 'Unknown: invalid position';
      _invalidate();
      _notify();
    }
  }

  void _schedule() {
    if (_disposed ||
        !settings.enabled ||
        !_active ||
        _paused ||
        !_available ||
        _pose == null ||
        _pending != null) {
      return;
    }
    if (_lastAttempt != null &&
        now().difference(_lastAttempt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAttempt = now();
    final operation = _calculate();
    _pending = operation;
    unawaited(operation.whenComplete(() => _pending = null));
  }

  Future<void> _calculate() async {
    final token = ++_revision, pose = _pose!, config = settings;
    bool valid() =>
        !_disposed &&
        token == _revision &&
        settings.enabled &&
        _active &&
        !_paused &&
        _available;
    final pilot = config.useSpawn ? pose.home : config.signal.pilot;
    final distance = routeDistance(pilot, pose.position);
    if (distance < 1 || distance > 6000) {
      status = distance < 1
          ? 'Unknown: vertical path / less than 1 m'
          : 'Unknown: beyond the 6 km live profile limit';
      _invalidate();
      _notify();
      return;
    }
    loading = true;
    status = 'Updating terrain profile';
    _notify();
    try {
      final plan = RouteSamplingPlan.create([
        RouteWaypointInput(position: pilot),
        RouteWaypointInput(position: pose.position),
      ], spacing: 25);
      final positions = plan.samples
          .map((p) => p.position)
          .toList(growable: false);
      final heights = await sample(positions);
      if (!valid()) return;
      final signal = SignalSettings(
        pilot: pilot,
        antennaHeight: config.signal.antennaHeight,
        frequencyMhz: config.signal.frequencyMhz,
        clearanceFraction: config.signal.clearanceFraction,
        useSurfaces: config.signal.useSurfaces,
        surfaces: config.signal.surfaces,
      );
      final calculated = calculateRadioLink(
        settings: signal,
        target: pose.position,
        altitude: pose.height,
        pilotHeight: heights.first + signal.antennaHeight,
        positions: positions,
        heights: heights,
      );
      if (!valid()) return;
      if (_pose == null ||
          routeDistance(_pose!.position, pose.position) > 100 ||
          (_pose!.height - pose.height).abs() > 30) {
        status = 'Unknown: profile overtaken by flight';
        current = false;
        await _mapUnknown();
        return;
      }
      result = calculated;
      transmitter = pilot;
      transmitterHeight = heights.first + signal.antennaHeight;
      calculatedAt = now();
      current = true;
      _armExpiry();
      status = switch (calculated.state) {
        RadioPathState.unknown => 'Unknown',
        RadioPathState.obstructed => 'Potential obstruction',
        RadioPathState.fresnelIntrusion => 'Fresnel intrusion',
        RadioPathState.noSampledObstruction => 'No sampled obstruction',
      };
      double margin(RadioPathSample p) =>
          calculated.state == RadioPathState.obstructed
          ? p.clearance
          : p.clearance - signal.clearanceFraction * p.radius;
      final worst = calculated.profile.reduce(
        (a, b) => margin(a) < margin(b) ? a : b,
      );
      obstruction =
          calculated.state == RadioPathState.obstructed ||
              calculated.state == RadioPathState.fresnelIntrusion
          ? worst
          : null;
      await send({
        'type': 'set-live-radio-result',
        'revision': token,
        'flightId': _flightId,
        'expiresAtMs': calculatedAt!
            .add(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
        'state': calculated.state.name,
        'message': status,
        'pilot': {
          'latitude': pilot.latitude,
          'longitude': pilot.longitude,
          'height': transmitterHeight,
        },
        'frequencyMhz': signal.frequencyMhz,
        'fraction': signal.clearanceFraction,
        'selected': 0,
        'rays': [
          {
            'latitude': pose.position.latitude,
            'longitude': pose.position.longitude,
            'height': pose.height,
            'ground': heights.last,
            'state': calculated.state.name,
          },
        ],
        if (calculated.state == RadioPathState.obstructed ||
            calculated.state == RadioPathState.fresnelIntrusion)
          'obstruction': {
            'latitude': worst.position.latitude,
            'longitude': worst.position.longitude,
            'height': worst.surface,
          },
      });
      if (!valid()) return;
    } catch (_) {
      if (valid()) {
        current = false;
        status = 'Unknown: terrain profile unavailable';
        await _mapUnknown();
      }
    } finally {
      if (valid()) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    _expiry?.cancel();
    super.dispose();
  }

  void _armExpiry() {
    _expiry?.cancel();
    final stamp = calculatedAt;
    _expiry = Timer(const Duration(seconds: 5), () {
      if (!_disposed && settings.enabled && current && calculatedAt == stamp) {
        status = 'Unknown: profile older than 5 seconds';
        current = false;
        unawaited(_mapUnknown());
        _notify();
      }
    });
  }
}
