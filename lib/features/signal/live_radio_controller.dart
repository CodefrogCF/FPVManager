import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';
import 'live_link_assessment.dart';
import 'rf_profile_settings.dart';
import 'live_sampling_policy.dart';
import 'live_terrain_sampler.dart';
import 'radio_analysis.dart';

class LiveRadioSettings {
  const LiveRadioSettings({
    this.enabled = true,
    this.useSpawn = true,
    this.showGroundStationMarker = true,
    this.showSignalPath = true,
    this.rfProfiles = const RfProfileSettings(),
    this.signal = const SignalSettings(
      pilot: Wgs84Coordinate(latitude: 46.8, longitude: 8.3),
    ),
  });
  final bool enabled, useSpawn, showGroundStationMarker, showSignalPath;
  final SignalSettings signal;
  final RfProfileSettings rfProfiles;
}

class LiveRadioController extends ChangeNotifier {
  LiveRadioController({
    required this.send,
    required this.sample,
    DateTime Function()? now,
    LiveSamplingTier Function(double)? chooseTier,
  }) : now = now ?? DateTime.now,
       chooseTier = chooseTier ?? LiveSamplingPolicy.forDistance;
  final Future<void> Function(Map<String, dynamic>) send;
  final Future<List<double>> Function(List<Wgs84Coordinate>) sample;
  final DateTime Function() now;
  final LiveSamplingTier Function(double) chooseTier;
  LiveRadioSettings settings = const LiveRadioSettings();
  String status = 'Disabled';
  RadioPathResult? result;
  LiveLinkAssessment assessment = const LiveLinkAssessment();
  LiveTerrainSampleResult? samplingDiagnostics;

  /// Last known ground station, independent of the aircraft's moving position.
  Wgs84Coordinate? groundStation;
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
  int _revision = 0, _flightId = -1, _terrainGeneration = 0;
  bool _retryLatestPose = false;
  double _speedMetersPerSecond = 0;
  bool _monitorEnabled = false;
  ({Wgs84Coordinate position, Wgs84Coordinate home, double height})? _pose;
  DateTime? _lastAttempt, _lastFreeSpacePreview;
  Timer? _expiry;
  Future<void>? _pending;
  Future<void> get settled => _pending ?? Future.value();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> configure(LiveRadioSettings value) async {
    value.signal.validate();
    value.rfProfiles.validate();
    settings = LiveRadioSettings(
      enabled: value.enabled,
      useSpawn: value.useSpawn,
      showGroundStationMarker: value.showGroundStationMarker,
      showSignalPath: value.showSignalPath,
      signal: SignalSettings.fromJson(value.signal.toJson()),
      rfProfiles: value.rfProfiles,
    );
    _pose = null;
    _active = false;
    _lastAttempt = null;
    _lastFreeSpacePreview = null;
    _invalidate(clear: true);
    status = value.enabled ? 'Waiting for an active flight' : 'Disabled';
    _notify();
    await _syncMonitor();
    if (settings.enabled) {
      // Fixed stations can be marked before flight telemetry arrives.
      _publishStation(settings.useSpawn ? null : settings.signal.pilot);
      _schedule();
    }
  }

  void renderer(bool available) {
    _available = available;
    _active = false;
    _pose = null;
    _flightId = -1;
    _lastAttempt = null;
    _lastFreeSpacePreview = null;
    _invalidate(clear: true);
    status = settings.enabled ? 'Terrain / renderer unavailable' : 'Disabled';
    _notify();
    if (available) {
      unawaited(
        _syncMonitor()
            .then((_) {
              if (settings.enabled && !settings.useSpawn) {
                _publishStation(settings.signal.pilot);
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _invalidate({bool clear = false}) {
    ++_revision;
    ++_terrainGeneration;
    _retryLatestPose = false;
    current = false;
    loading = false;
    assessment = const LiveLinkAssessment();
    samplingDiagnostics = null;
    _expiry?.cancel();
    if (clear) {
      result = null;
      obstruction = null;
      calculatedAt = null;
      transmitter = null;
      transmitterHeight = null;
      groundStation = null;
    }
    unawaited(_mapUnknown());
  }

  // A profile can become too old for the HUD without invalidating a newer
  // terrain query already in flight. Only a changed flight, provider or
  // configuration increments _terrainGeneration.
  void _expirePosition() {
    ++_revision;
    current = false;
    assessment = const LiveLinkAssessment();
    _expiry?.cancel();
    unawaited(_mapUnknown());
  }

  Future<void> _mapUnknown() async {
    if (_disposed || !settings.enabled) return;
    final messageRevision = _revision;
    final pose = _pose;
    final pilot = pose == null
        ? null
        : (settings.useSpawn ? pose.home : settings.signal.pilot);
    final distance = pose == null || pilot == null
        ? null
        : routeDistance(pilot, pose.position);
    try {
      await send({
        if (distance != null && distance.isFinite && distance >= 1)
          'distanceMeters': distance,
        'type': 'set-live-radio-result',
        'revision': messageRevision,
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
    _lastFreeSpacePreview = null;
    _invalidate(clear: true);
    status = available
        ? 'Terrain changed; awaiting a new profile'
        : 'Terrain unavailable';
    _notify();
    if (available) {
      unawaited(
        _syncMonitor()
            .then((_) {
              if (settings.enabled && !settings.useSpawn) {
                _publishStation(settings.signal.pilot);
              }
            })
            .catchError((Object _) {}),
      );
    }
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
      'useSpawn': settings.useSpawn,
      'showGroundStationMarker': settings.showGroundStationMarker,
      'showSignalPath': settings.showSignalPath,
      'rfProfiles': settings.rfProfiles.toJson(),
    });
    _monitorEnabled = enabled;
  }

  // The marker is separate from the ray layer: a missing or expired terrain
  // profile must not make the operator's chosen ground location disappear.
  void _publishStation(Wgs84Coordinate? point) {
    groundStation = point;
    if (!_available || _disposed || !settings.enabled) return;
    unawaited(
      send({
        'type': 'set-live-radio-ground-station',
        'revision': _revision,
        'position': point == null
            ? null
            : {'latitude': point.latitude, 'longitude': point.longitude},
      }).catchError((Object _) {}),
    );
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
      final speed = data['speed'];
      _speedMetersPerSecond =
          speed is num && speed.isFinite && speed >= 0 && speed <= 200
          ? speed.toDouble()
          : 0;
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
      final station = settings.useSpawn ? _pose!.home : settings.signal.pilot;
      if (groundStation?.latitude != station.latitude ||
          groundStation?.longitude != station.longitude) {
        _publishStation(station);
      }
      // A missing terrain provider must not prevent free-space-only RF
      // diagnostics. These are never converted into control/video quality.
      if (!_available) {
        status = 'Unknown: terrain unavailable (free-space estimate only)';
        if (_lastAttempt == null ||
            now().difference(_lastAttempt!) >=
                LiveSamplingPolicy.interval(_speedMetersPerSecond)) {
          _lastAttempt = now();
          unawaited(_mapUnknown());
        }
        _notify();
        return;
      }
      if (current &&
          result != null &&
          (routeDistance(_pose!.position, result!.target) >
                  LiveSamplingPolicy.maximumStaleness(
                    _speedMetersPerSecond,
                    routeDistance(station, _pose!.position),
                  ) ||
              (_pose!.height - result!.altitude!).abs() > 12)) {
        status = 'Drone moved beyond the last profile';
        _expirePosition();
        _notify();
      }
      // Free-space diagnostics can be displayed immediately, even while the
      // first terrain request is still pending. Keep it separate from RF LQ.
      if (!current &&
          !loading &&
          (_lastFreeSpacePreview == null ||
              now().difference(_lastFreeSpacePreview!) >
                  const Duration(seconds: 1))) {
        _lastFreeSpacePreview = now();
        unawaited(_mapUnknown());
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
    final pose = _pose!;
    final station = settings.useSpawn ? pose.home : settings.signal.pilot;
    final distance = routeDistance(station, pose.position);
    if (_lastAttempt != null &&
        now().difference(_lastAttempt!) <
            LiveSamplingPolicy.interval(_speedMetersPerSecond, distance)) {
      return;
    }
    _lastAttempt = now();
    final operation = _calculate();
    _pending = operation;
    unawaited(operation.whenComplete(() {
      _pending = null;
      if (_retryLatestPose && !_disposed) {
        _retryLatestPose = false;
        _schedule();
      }
    }));
  }

  // Terrain samples are fixed world positions. When a fast aircraft moves
  // during a query, a deep obstruction at an already sampled point can still
  // be verified for the NEW ray. Do not extrapolate clear reception: only a
  // sampled, interior obstruction at least 8 m below the updated ray may be
  // used, and the sample must lie within 2 m of that ray horizontally.
  RadioPathResult? _recheckObservedBlockage(
    LiveTerrainSampleResult sampled,
    SignalSettings signal,
    Wgs84Coordinate target,
    double targetHeight,
  ) {
    final original = sampled.path.profile;
    if (original.length < 3) return null;
    final length = routeDistance(signal.pilot, target);
    if (!length.isFinite || length < 2 || length > radioMaximumPathMeters) {
      return null;
    }
    final matched = <RadioPathSample>[original.first];
    for (final sample in original.skip(1)) {
      final fromStation = routeDistance(signal.pilot, sample.position);
      final fromTarget = routeDistance(target, sample.position);
      final along = (length * length + fromStation * fromStation -
              fromTarget * fromTarget) /
          (2 * length);
      final lateral = math.sqrt(math.max(
        0,
        fromStation * fromStation - along * along,
      ));
      if (along > 2 && along < length - 2 && lateral <= 2) {
        matched.add(sample);
      }
    }
    if (matched.length < 3) return null;
    final verified = calculateRadioLink(
      settings: signal,
      target: target,
      altitude: targetHeight,
      pilotHeight: original.first.ground + signal.antennaHeight,
      positions: [for (final p in matched) p.position],
      heights: [for (final p in matched) p.ground],
    );
    if (verified.state != RadioPathState.obstructed ||
        (verified.minimumClearance ?? 0) > -8 ||
        !verified.profile.skip(1).any((p) => p.clearance <= -8)) {
      return null;
    }
    return verified;
  }

  Future<void> _calculate() async {
    final startedAt = now();
    final generation = _terrainGeneration, pose = _pose!, config = settings;
    bool valid() =>
        !_disposed &&
        generation == _terrainGeneration &&
        settings.enabled &&
        _active &&
        !_paused &&
        _available;
    final pilot = config.useSpawn ? pose.home : config.signal.pilot;
    final distance = routeDistance(pilot, pose.position);
    if (!distance.isFinite ||
        distance < 1 ||
        distance > radioMaximumPathMeters) {
      status = distance < 1
          ? 'Unknown: vertical path / less than 1 m'
          : 'Unknown: beyond the 50 km terrain analysis limit';
      _invalidate();
      _notify();
      return;
    }
    loading = true;
    status = 'Updating ${chooseTier(distance).name} terrain profile';
    _notify();
    try {
      final signal = SignalSettings(
        pilot: pilot,
        antennaHeight: config.signal.antennaHeight,
        frequencyMhz: config.signal.frequencyMhz,
        clearanceFraction: config.signal.clearanceFraction,
        useSurfaces: config.signal.useSurfaces,
        surfaces: config.signal.surfaces,
      );
      final sampled = await LiveTerrainSampler.calculate(
        signal: signal,
        target: pose.position,
        targetHeight: pose.height,
        distanceMeters: distance,
        tier: chooseTier(distance),
        sample: sample,
        valid: valid,
      );
      if (!valid()) return;
      var calculated = sampled.path;
      var publishedPose = pose;
      var updatedFromExistingSamples = false;
      samplingDiagnostics = sampled;
      if (!valid()) return;
      if (_pose == null ||
          routeDistance(_pose!.position, pose.position) >
              LiveSamplingPolicy.maximumStaleness(
                _speedMetersPerSecond,
                distance,
              ) ||
          (_pose!.height - pose.height).abs() > 12) {
        final latest = _pose;
        final rechecked = latest == null
            ? null
            : _recheckObservedBlockage(
                sampled,
                signal,
                latest.position,
                latest.height,
              );
        if (rechecked == null) {
          status = 'Unknown: profile overtaken by flight';
          _expirePosition();
          _retryLatestPose = true;
          _notify();
          return;
        }
        // Physical evidence for obstruction only. Incomplete recent sampling
        // must never be promoted to a clear RF link.
        calculated = rechecked;
        publishedPose = latest!;
        updatedFromExistingSamples = true;
      }
      result = calculated;
      assessment = LiveLinkAssessment.fromTerrainProfile(
        calculated,
        sampledAt: now(),
        coverageLimited: sampled.coverageLimited || updatedFromExistingSamples,
        maximumSampleGapMeters: sampled.maximumGapMeters,
        samplingTier: sampled.tier.name,
      );
      transmitter = pilot;
      transmitterHeight =
          calculated.profile.first.ground + signal.antennaHeight;
      calculatedAt = now();
      current = true;
      _armExpiry();
      status = updatedFromExistingSamples
          ? 'Potential obstruction (rechecked against sampled terrain)'
          : switch (calculated.state) {
        RadioPathState.unknown => 'Unknown',
        RadioPathState.obstructed => 'Potential obstruction',
        RadioPathState.fresnelIntrusion => 'Fresnel intrusion',
        RadioPathState.noSampledObstruction =>
          sampled.coverageLimited
              ? 'Unknown: coarse terrain coverage (no sampled obstruction)'
              : 'No sampled obstruction',
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
        'revision': ++_revision,
        'flightId': _flightId,
        'expiresAtMs': calculatedAt!
            .add(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
        'state': calculated.state.name,
        'distanceMeters': routeDistance(pilot, publishedPose.position),
        'sampling': {
          'tier': sampled.tier.name,
          'samples': sampled.sampleCount,
          'coarseSamples': sampled.coarseCount,
          'refinedSamples': sampled.refinedCount,
          'queries': sampled.queryCount,
          'elapsedMs': now().difference(startedAt).inMilliseconds,
          'maximumGapMeters': sampled.maximumGapMeters,
          'limited': sampled.coverageLimited || updatedFromExistingSamples,
          if (updatedFromExistingSamples) 'recheckedMovingPath': true,
        },
        'showPilot': false,
        'assessment': assessment.toJson(),
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
            'latitude': publishedPose.position.latitude,
            'longitude': publishedPose.position.longitude,
            'height': publishedPose.height,
            'ground': calculated.profile.last.ground,
            if (updatedFromExistingSamples) 'groundFromNearbySample': true,
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
        status = 'Unknown: terrain profile unavailable';
        _expirePosition();
        _notify();
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
        assessment = const LiveLinkAssessment();
        unawaited(_mapUnknown());
        _notify();
      }
    });
  }
}
