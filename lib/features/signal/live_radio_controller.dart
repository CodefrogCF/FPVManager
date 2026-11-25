import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';
import 'live_link_assessment.dart';
import 'live_radio_diagnostics.dart';
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
    Duration Function()? elapsed,
    this.requestTimeout = const Duration(seconds: 12),
    LiveSamplingTier Function(double)? chooseTier,
  }) : now = now ?? DateTime.now,
       elapsed = elapsed ?? _monotonicClock(),
       chooseTier = chooseTier ?? LiveSamplingPolicy.forDistance;
  final Future<void> Function(Map<String, dynamic>) send;
  final Future<List<double>> Function(List<Wgs84Coordinate>) sample;
  final DateTime Function() now;
  final Duration Function() elapsed;
  final Duration requestTimeout;
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
  int? _unsupportedTerrainGeneration;
  bool _retryLatestPose = false;
  double _speedMetersPerSecond = 0;
  bool _monitorEnabled = false;
  ({Wgs84Coordinate position, Wgs84Coordinate home, double height})? _pose;
  // The pose a pending terrain profile is actually sampling. New telemetry
  // does not cancel that query; it requests a fresh pass as soon as possible.
  ({Wgs84Coordinate position, double height})? _inFlightPose;
  Duration? _lastAttempt,
      _lastFreeSpacePreview,
      _lastValidElapsed,
      _poseObservedAt;
  Timer? _expiry, _wake, _diagnosticTimer;
  Duration? _lastDiagnostic;
  Completer<void>? _cancelRequest;
  int _requestSequence = 0;
  int _poseSequence = 0, _lastAttemptPoseSequence = -1;
  int? _activeRequest;
  final _diagnostics = LiveRadioDiagnostics();
  bool diagnosticsEnabled = false;
  int get generation => _terrainGeneration;
  int? get requestId => _activeRequest;
  Map<String, Object?> get diagnostics => {
    ..._diagnostics.snapshot(),
    'active': _activeRequest == null ? 0 : 1,
    'queued': _retryLatestPose ? 1 : 0,
    'ageMs': _lastValidElapsed == null
        ? null
        : (elapsed() - _lastValidElapsed!).inMilliseconds,
    'distanceMeters': _pose == null
        ? null
        : routeDistance(
            settings.useSpawn ? _pose!.home : settings.signal.pilot,
            _pose!.position,
          ),
    'movementMeters': _pose == null || result == null
        ? null
        : routeDistance(result!.target, _pose!.position),
    'los': current ? assessment.visibility.name : 'unknown',
  };
  void setDiagnosticsEnabled(bool enabled) {
    diagnosticsEnabled = enabled;
    _diagnosticTimer?.cancel();
    _diagnosticTimer = null;
    _lastDiagnostic = null;
    if (_available && !_disposed) {
      if (enabled) _lastDiagnostic = elapsed();
      unawaited(
        send({
          'type': 'set-live-radio-diagnostics',
          'enabled': enabled,
          if (enabled) 'diagnostics': _diagnosticPayload(),
        }).catchError((Object _) {}),
      );
    }
    _notify();
  }

  Map<String, Object?> _diagnosticPayload() => diagnostics..remove('history');

  void _publishDiagnostics() {
    if (!diagnosticsEnabled || !_available || _disposed) return;
    final remaining = _lastDiagnostic == null
        ? Duration.zero
        : const Duration(seconds: 1) - (elapsed() - _lastDiagnostic!);
    if (remaining > Duration.zero) {
      _diagnosticTimer ??= Timer(remaining, () {
        _diagnosticTimer = null;
        _publishDiagnostics();
      });
      return;
    }
    _lastDiagnostic = elapsed();
    unawaited(
      send({
        'type': 'set-live-radio-diagnostics',
        'enabled': true,
        'diagnostics': _diagnosticPayload(),
      }).catchError((Object _) {}),
    );
  }

  void recordTerrainDiagnostics(Map<String, dynamic> data) {
    if (data['provider'] case final String provider) {
      _diagnostics.provider = provider;
    }
  }

  Future<void>? _pending;
  Future<void> get settled async {
    while (_pending != null) {
      await _pending;
    }
  }

  void _notify() {
    if (!_disposed) {
      _publishDiagnostics();
      notifyListeners();
    }
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

  void _invalidate({
    bool clear = false,
    String quality = 'unknown',
    String? error,
  }) {
    ++_revision;
    ++_terrainGeneration;
    _unsupportedTerrainGeneration = null;
    _wake?.cancel();
    _wake = null;
    _cancelRequest?.complete();
    _cancelRequest = null;
    _retryLatestPose = false;
    _inFlightPose = null;
    current = false;
    loading = false;
    assessment = const LiveLinkAssessment();
    _diagnostics.quality = quality;
    _diagnostics.errorDetail = null;
    _diagnostics.errorCategory =
        error ?? (_available ? 'SUPERSEDED' : 'TERRAIN_UNAVAILABLE');
    samplingDiagnostics = null;
    _expiry?.cancel();
    if (clear) {
      result = null;
      obstruction = null;
      calculatedAt = null;
      _lastValidElapsed = null;
      transmitter = null;
      transmitterHeight = null;
      groundStation = null;
    }
    unawaited(_mapUnknown());
  }

  // A profile can become too old for the HUD without invalidating a newer
  // terrain query already in flight. Only a changed flight, provider or
  // configuration increments _terrainGeneration.
  void _expirePosition({String quality = 'stale', String error = 'STALE'}) {
    ++_revision;
    current = false;
    assessment = const LiveLinkAssessment();
    _diagnostics.quality = quality;
    _diagnostics.errorCategory = error;
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
        'observation': _observation(),
        'analysisRequestId': _activeRequest,
        'generation': _terrainGeneration,
        if (diagnosticsEnabled) 'diagnostics': _diagnosticPayload(),
        'message':
            _diagnostics.errorDetail ??
            (settings.enabled ? 'Unknown · open radio details' : 'Disabled'),
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
    if (diagnosticsEnabled) setDiagnosticsEnabled(true);
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
      _poseObservedAt = elapsed();
      ++_poseSequence;
      final station = settings.useSpawn ? _pose!.home : settings.signal.pilot;
      // A flying aircraft may move materially during a detailed terrain
      // request. Do not interrupt the in-flight work or mistake its old ray
      // for the new one; queue the latest position for immediate follow-up.
      // This is especially important for mountain flying at high speed.
      final requested = _inFlightPose;
      if (_pending != null &&
          requested != null &&
          (routeDistance(requested.position, _pose!.position) >=
                  math.max(6, _speedMetersPerSecond * 0.12) ||
              (requested.height - _pose!.height).abs() >= 6)) {
        _retryLatestPose = true;
      }
      if (groundStation?.latitude != station.latitude ||
          groundStation?.longitude != station.longitude) {
        _publishStation(station);
      }
      // A missing terrain provider must not prevent free-space-only RF
      // diagnostics. These are never converted into control/video quality.
      if (!_available) {
        status = 'Unknown: terrain unavailable (free-space estimate only)';
        if (_lastAttempt == null ||
            elapsed() - _lastAttempt! >=
                LiveSamplingPolicy.interval(_speedMetersPerSecond)) {
          _lastAttempt = elapsed();
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
              elapsed() - _lastFreeSpacePreview! >
                  const Duration(seconds: 1))) {
        _lastFreeSpacePreview = elapsed();
        unawaited(_mapUnknown());
      }
      _schedule();
    } on FormatException {
      status = 'Unknown: invalid position';
      _invalidate(quality: 'error', error: 'INVALID_RESULT');
      _notify();
    }
  }

  void _schedule() {
    if (_disposed ||
        !settings.enabled ||
        !_active ||
        _paused ||
        !_available ||
        _pose == null) {
      return;
    }
    if (_unsupportedTerrainGeneration == _terrainGeneration) {
      // A documented provider restriction cannot recover by retrying the
      // same query at flight-update rate. Retry after provider/config change.
      _retryLatestPose = false;
      return;
    }
    if (_pending != null || _activeRequest != null) {
      _retryLatestPose = true;
      return;
    }
    if (_poseObservedAt == null ||
        elapsed() - _poseObservedAt! >= const Duration(seconds: 5)) {
      _retryLatestPose = false;
      status = 'Unknown: last aircraft position older than 5 seconds';
      _expirePosition();
      _notify();
      return;
    }
    if (_lastAttempt != null && _poseSequence == _lastAttemptPoseSequence) {
      // A throttle wakeup can precede the next rendered pose by one frame.
      // Wait for that telemetry instead of starting another old-position scan.
      _retryLatestPose = false;
      return;
    }
    final pose = _pose!;
    final station = settings.useSpawn ? pose.home : settings.signal.pilot;
    final distance = routeDistance(station, pose.position);
    final interval = LiveSamplingPolicy.interval(
      _speedMetersPerSecond,
      distance,
    );
    if (_lastAttempt != null) {
      final remaining = interval - (elapsed() - _lastAttempt!);
      if (remaining > Duration.zero) {
        // One latest-pose slot and one wakeup, even if telemetry stops here.
        _retryLatestPose = true;
        _wake ??= Timer(remaining, () {
          _wake = null;
          if (_retryLatestPose) _schedule();
        });
        return;
      }
    }
    _wake?.cancel();
    _wake = null;
    _retryLatestPose = false;
    _lastAttempt = elapsed();
    _lastAttemptPoseSequence = _poseSequence;
    final id = ++_requestSequence;
    _activeRequest = id;
    final cancel = Completer<void>();
    _cancelRequest = cancel;
    _diagnostics.start(id, _terrainGeneration, elapsed().inMicroseconds / 1000);
    final operation = _calculate(id, cancel);
    _pending = operation;
    unawaited(
      operation.whenComplete(() {
        _pending = null;
        _activeRequest = null;
        if (identical(_cancelRequest, cancel)) _cancelRequest = null;
        if (!cancel.isCompleted) cancel.complete();
        _inFlightPose = null;
        _publishDiagnostics();
        if (_retryLatestPose && !_disposed) {
          _retryLatestPose = false;
          _schedule();
        }
      }),
    );
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
      final along =
          (length * length +
              fromStation * fromStation -
              fromTarget * fromTarget) /
          (2 * length);
      final lateral = math.sqrt(
        math.max(0, fromStation * fromStation - along * along),
      );
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

  Future<T> _bounded<T>(
    Future<T> work,
    Duration started,
    Completer<void> cancel,
  ) {
    final remaining = requestTimeout - (elapsed() - started);
    return Future.any<T>([
      work,
      cancel.future.then<T>((_) => throw const _SupersededRequest()),
    ]).timeout(remaining > Duration.zero ? remaining : Duration.zero);
  }

  Map<String, Object?> _observation({Duration? capturedAt}) => {
    'quality': _diagnostics.quality,
    'ageMs': (capturedAt ?? _lastValidElapsed) == null
        ? null
        : (elapsed() - (capturedAt ?? _lastValidElapsed!)).inMilliseconds,
    'freshnessMs': 5000,
    'errorCategory': _diagnostics.errorCategory,
    'reason': _diagnostics.errorDetail,
  };

  Future<void> _calculate(int request, Completer<void> cancel) async {
    final startedAt = elapsed(), poseObservedAt = _poseObservedAt!;
    final capturedAt = now().subtract(startedAt - poseObservedAt);
    final generation = _terrainGeneration, pose = _pose!, config = settings;
    _inFlightPose = (position: pose.position, height: pose.height);
    bool valid() =>
        !_disposed &&
        _activeRequest == request &&
        !cancel.isCompleted &&
        generation == _terrainGeneration &&
        settings.enabled &&
        _active &&
        !_paused &&
        _available;
    final pilot = config.useSpawn ? pose.home : config.signal.pilot;
    final distance = routeDistance(pilot, pose.position);
    if (!distance.isFinite ||
        distance < 0 ||
        distance > radioMaximumPathMeters) {
      status = !distance.isFinite || distance < 0
          ? 'Unknown: invalid RF path coordinates'
          : 'Unknown: beyond the 50 km terrain analysis limit';
      _invalidate(error: 'INVALID_RESULT');
      _diagnostics.finish(
        elapsed().inMicroseconds / 1000,
        success: false,
        error: 'INVALID_RESULT',
      );
      _notify();
      return;
    }
    final tier = chooseTier(distance);
    loading = true;
    if (!current) {
      _diagnostics.quality = 'pending';
      _diagnostics.errorCategory = 'PENDING';
      unawaited(_mapUnknown());
    }
    status = 'Updating ${tier.name} terrain profile';
    _notify();
    var publishing = false;
    try {
      final signal = SignalSettings(
        pilot: pilot,
        antennaHeight: config.signal.antennaHeight,
        frequencyMhz: config.signal.frequencyMhz,
        clearanceFraction: config.signal.clearanceFraction,
        useSurfaces: config.signal.useSurfaces,
        surfaces: config.signal.surfaces,
      );
      final sampled = await _bounded(
        LiveTerrainSampler.calculate(
          signal: signal,
          target: pose.position,
          targetHeight: pose.height,
          distanceMeters: distance,
          tier: tier,
          completeFirstPass: _speedMetersPerSecond >= 12,
          sample: (positions) async {
            _diagnostics.samples += positions.length;
            final heights = await sample(positions);
            if (valid()) {
              final count = heights
                  .where((h) => h.isFinite && h.abs() <= 100000)
                  .length;
              _diagnostics.validSamples += math.min(count, positions.length);
              _diagnostics.missingSamples += math.max(
                0,
                positions.length - count,
              );
            }
            return heights;
          },
          valid: valid,
          // Expensive refinement on a departed flight ray only delays the next
          // live request. A sampled obstruction remains independently useful;
          // a sparse clear ray is never accepted as an authoritative result.
          shouldRefine: () {
            final latest = _pose;
            return latest != null &&
                routeDistance(latest.position, pose.position) <=
                    LiveSamplingPolicy.maximumStaleness(
                      _speedMetersPerSecond,
                      distance,
                    ) &&
                (latest.height - pose.height).abs() <= 12;
          },
        ),
        startedAt,
        cancel,
      );
      if (!valid()) return;
      // A slow response is not a new observation of the aircraft at completion.
      // Preserve the existing five-second horizon from the captured pose.
      if (elapsed() - poseObservedAt >= const Duration(seconds: 5)) {
        status = 'Unknown: captured profile older than 5 seconds';
        _expirePosition();
        _diagnostics.finish(
          elapsed().inMicroseconds / 1000,
          success: false,
          error: 'STALE',
        );
        _notify();
        return;
      }
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
          _diagnostics.finish(
            elapsed().inMicroseconds / 1000,
            success: false,
            error: 'STALE',
          );
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
      if (calculated.state == RadioPathState.unknown ||
          calculated.profile.isEmpty) {
        throw const FormatException('RF endpoints less than 1 m apart');
      }
      result = calculated;
      assessment = LiveLinkAssessment.fromTerrainProfile(
        calculated,
        sampledAt: capturedAt,
        coverageLimited: sampled.coverageLimited || updatedFromExistingSamples,
        maximumSampleGapMeters: sampled.maximumGapMeters,
        samplingTier: sampled.tier.name,
      );
      transmitter = pilot;
      transmitterHeight =
          calculated.profile.first.ground + signal.antennaHeight;
      calculatedAt = now();
      _lastValidElapsed = poseObservedAt;
      current = true;
      _diagnostics.quality =
          assessment.visibility == LivePathVisibility.unknown ||
              (sampled.coverageLimited &&
                  calculated.state == RadioPathState.noSampledObstruction)
          ? 'unknown'
          : 'valid';
      _diagnostics.errorCategory = _diagnostics.quality == 'valid'
          ? null
          : 'TERRAIN_UNAVAILABLE';
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
      publishing = true;
      await _bounded(
        send({
          'type': 'set-live-radio-result',
          'revision': ++_revision,
          'flightId': _flightId,
          'expiresAtMs': now()
              .subtract(elapsed() - poseObservedAt)
              .add(const Duration(seconds: 5))
              .millisecondsSinceEpoch,
          'state': calculated.state.name,
          'observation': _observation(capturedAt: poseObservedAt),
          'analysisRequestId': request,
          'generation': generation,
          if (diagnosticsEnabled) 'diagnostics': _diagnosticPayload(),
          'distanceMeters': math.sqrt(
            math.pow(routeDistance(pilot, publishedPose.position), 2) +
                math.pow(publishedPose.height - transmitterHeight!, 2),
          ),
          'sampling': {
            'tier': sampled.tier.name,
            'samples': sampled.sampleCount,
            'coarseSamples': sampled.coarseCount,
            'refinedSamples': sampled.refinedCount,
            'queries': sampled.queryCount,
            'elapsedMs': (elapsed() - startedAt).inMilliseconds,
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
        }),
        startedAt,
        cancel,
      );
      if (!valid()) return;
      _diagnostics.finish(
        elapsed().inMicroseconds / 1000,
        success: _diagnostics.quality == 'valid',
        error: _diagnostics.errorCategory,
      );
    } catch (error) {
      if (valid()) {
        // Distinguish exhausted terrain requests from an RF link loss. Both
        // must remain UNKNOWN, never an invented clear or disconnected link.
        final message = error.toString().toLowerCase();
        final category =
            error is TimeoutException ||
                message.contains('timeout') ||
                message.contains('timed out')
            ? 'TIMEOUT'
            : message.contains('terrain_unavailable')
            ? 'TERRAIN_UNAVAILABLE'
            : publishing ||
                  message.contains('bridge') ||
                  message.contains('globe')
            ? 'BRIDGE_ERROR'
            : error is FormatException || error is ArgumentError
            ? 'INVALID_RESULT'
            : 'SAMPLING_ERROR';
        status = category == 'TIMEOUT'
            ? 'Unknown: terrain request timed out'
            : 'Unknown: terrain profile unavailable';
        if (category == 'TERRAIN_UNAVAILABLE' && message.contains('bkg')) {
          _unsupportedTerrainGeneration = generation;
          _diagnostics.provider = 'BKG 3D Beta';
          _diagnostics.errorDetail =
              'BKG 3D Beta: RF height reference unverified';
          status = 'Unknown: ${_diagnostics.errorDetail}';
        }
        _expirePosition(
          quality: category == 'TERRAIN_UNAVAILABLE' ? 'unknown' : 'error',
          error: category,
        );
        _diagnostics.finish(
          elapsed().inMicroseconds / 1000,
          success: false,
          error: category,
        );
        _notify();
      } else {
        _diagnostics.finish(
          elapsed().inMicroseconds / 1000,
          success: false,
          error: 'SUPERSEDED',
        );
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
    _wake?.cancel();
    _diagnosticTimer?.cancel();
    if (_cancelRequest case final cancel? when !cancel.isCompleted) {
      cancel.complete();
    }
    super.dispose();
  }

  void _armExpiry() {
    _expiry?.cancel();
    final stamp = calculatedAt;
    final remaining =
        const Duration(seconds: 5) - (elapsed() - _lastValidElapsed!);
    _expiry = Timer(remaining > Duration.zero ? remaining : Duration.zero, () {
      if (!_disposed && settings.enabled && current && calculatedAt == stamp) {
        status = 'Unknown: profile older than 5 seconds';
        current = false;
        assessment = const LiveLinkAssessment();
        _diagnostics.quality = 'stale';
        _diagnostics.errorCategory = 'STALE';
        unawaited(_mapUnknown());
        _notify();
      }
    });
  }
}

Duration Function() _monotonicClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

class _SupersededRequest implements Exception {
  const _SupersededRequest();
}
