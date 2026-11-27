import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

import '../../core/models/flight_route.dart';
import '../../core/models/scene_time.dart';
import '../globe/globe_controller.dart';
import '../scenery/scenery_asset_provider.dart' show sceneryApplicationVersion;
import '../signal/live_radio_controller.dart';
import '../simulation/route_playback.dart';
import '../simulation/simulation_settings.dart';
import 'developer_performance_recording.dart';

/// A/B comparisons deliberately keep the same renderer and warm cache policy.
/// The infrastructure case toggles the official tileset and its bridge supports,
/// not independent tunnel models or custom scenery.
class BenchmarkCase {
  const BenchmarkCase(
    this.id, {
    this.buildings = true,
    this.structures = true,
    this.vegetation = true,
    this.rf = true,
  });
  final String id;
  final bool buildings, structures, vegetation, rf;
  Map<String, bool> get layers => {
    'buildings': buildings,
    'structures': structures,
    'vegetation': vegetation,
  };
  static const matrix = [
    BenchmarkCase('reference'),
    BenchmarkCase('no-buildings', buildings: false),
    BenchmarkCase('no-structures', structures: false),
    BenchmarkCase('no-vegetation', vegetation: false),
    BenchmarkCase(
      'terrain-reference',
      buildings: false,
      structures: false,
      vegetation: false,
    ),
    BenchmarkCase('no-rf', rf: false),
  ];
  static Iterable<BenchmarkCase> order(int repetition) =>
      repetition.isOdd ? matrix : matrix.reversed;
}

class DeveloperBenchmark extends ChangeNotifier with WidgetsBindingObserver {
  DeveloperBenchmark(this.globe);
  final GlobeController globe;
  final recording = DeveloperPerformanceRecording();
  bool active = false, _cancelled = false, _disposed = false;
  String status = 'idle';
  String? error;
  int runIndex = 0, runCount = 0;
  double progress = 0;
  final runs = <Map<String, Object?>>[];
  (int, int)? _terrainRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancel();
  }

  void cancel() {
    if (!active || _cancelled) return;
    _cancelled = true;
    status = 'cancelling';
    _notify();
    // Also interrupt an in-flight terrain preparation or replay start. The
    // operation's normal acknowledgement/timeout still precedes final cleanup.
    if (globe.isReady) {
      unawaited(globe.controlRoutePlayback('stop').catchError((Object _) {}));
    }
  }

  void check() {
    if (!active || _cancelled || _disposed || !globe.developerMenusEnabled) {
      throw const _BenchmarkCancelled();
    }
    if (!globe.isReady ||
        !globe.terrainAvailable ||
        globe.terrainRevision != _terrainRevision) {
      throw StateError('Terrain or renderer changed during benchmark');
    }
  }

  Future<void> run(
    FlightRoute route,
    SimulationSettings settings, {
    required int repetitions,
    required String platform,
    required Future<void> Function() quiesceProfiler,
  }) async {
    if (active || repetitions < 1 || repetitions > 2) {
      throw StateError('Invalid benchmark request');
    }
    final originalRadio = globe.liveRadio.settings;
    // Preserve the current graphics, FOV, physics and lighting mode. Fix the
    // lighting clock when enabled. Use the same captured settings for all runs.
    final fixed = settings.withCameraTilt(
      settings.cameraTiltDegrees,
      sceneTime: SceneTime(
        enabled: settings.sceneTime.enabled || globe.realisticLighting,
        fixedUtc: settings.sceneTime.fixedUtc ?? DateTime.utc(2026, 6, 21, 12),
      ),
    );
    final command = RoutePlaybackRequest(route, fixed).command;
    final routeHash = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'points': command['points'],
              'recorded': command['recorded'],
              'defaultSpeed': command['defaultSpeedMetersPerSecond'],
              'defaultAgl': command['defaultAglMeters'],
            }),
          ),
        )
        .toString();
    globe.beginBenchmark();
    active = true;
    WidgetsBinding.instance.addObserver(this);
    _cancelled = false;
    _terrainRevision = globe.terrainRevision;
    error = null;
    runIndex = 0;
    runCount = BenchmarkCase.matrix.length * repetitions;
    progress = 0;
    runs.clear();
    recording.clear();
    status = 'preparing';
    _notify();
    final metadata = <String, Object?>{
      'kind': 'route-playback-benchmark',
      'routeSha256': routeHash,
      'cachePolicy': 'resident-warmup-pass-per-case-no-cache-flush',
      'repetitions': repetitions,
      'runs': runs,
      'platform': platform,
      'applicationVersion': sceneryApplicationVersion,
      'graphicsProfile': fixed.graphicsProfile.name,
      'physicsHz': fixed.physicsStepHz,
      'renderScale': fixed.renderScale,
      'cameraFovDegrees': fixed.cameraFovDegrees,
      'sceneTime': fixed.sceneTime.toJson(),
      'rfPolicy': 'same-profile-spawn-station',
      'rfProfileSha256': sha256
          .convert(utf8.encode(jsonEncode(originalRadio.rfProfiles.toJson())))
          .toString(),
      'playbackSpeed': 1.0,
    };
    try {
      await quiesceProfiler();
      check();
      final prepared = await globe.prepareBenchmark(
        route,
        fixed,
        limitSeconds: repetitions == 2 ? 35 : 60,
      );
      check();
      final duration = (prepared['duration'] as num).toDouble();
      // Leave headroom for slower-than-real-time playback and the bounded export.
      if (!duration.isFinite ||
          duration < 10 ||
          duration > (repetitions == 2 ? 35 : 60)) {
        throw StateError(
          'Route must last 10–${repetitions == 2 ? 35 : 60} seconds',
        );
      }
      metadata['routeDurationSeconds'] = duration;
      metadata['sourceRouteDurationSeconds'] = prepared['sourceDuration'];
      metadata['recordedRoute'] = prepared['recorded'] == true;
      recording.start(metadata: metadata);
      for (var repeat = 1; repeat <= repetitions; repeat++) {
        for (final variant in BenchmarkCase.order(repeat)) {
          check();
          runIndex++;
          progress = 0;
          final result = <String, Object?>{
            'case': variant.id,
            'repetition': repeat,
            'status': 'warming',
            'firstSample': recording.count,
            'layers': variant.layers,
            'rfEnabled': variant.rf,
          };
          runs.add(result);
          status = '${variant.id}: warmup';
          _notify();
          await globe.setBenchmarkLayers(variant.layers);
          check();
          await globe.liveRadio.configure(
            LiveRadioSettings(
              enabled: variant.rf,
              useSpawn: true,
              showGroundStationMarker: originalRadio.showGroundStationMarker,
              showSignalPath: originalRadio.showSignalPath,
              signal: originalRadio.signal,
              rfProfiles: originalRadio.rfProfiles,
            ),
          );
          check();
          await globe.startBenchmarkPlayback(route, fixed);
          check();
          await _waitPass(duration);
          check();
          // Reset the rolling window and counters after warmup without flushing
          // the actual resource caches. This isolates each measured pass.
          await globe.scenePerformance(action: 'stop');
          check();
          await globe.scenePerformance(action: 'start');
          check();
          result['status'] = 'measuring';
          status = '${variant.id}: measuring';
          progress = 0;
          _notify();
          await globe.controlRoutePlayback('restart');
          check();
          final clock = Stopwatch()..start();
          var rfValid = 0;
          final fps = <double>[];
          final p95 = <double>[];
          final visibleLayers = <String>{};
          final incompleteLayers = <String>{};
          await _waitPass(
            duration,
            sample: () async {
              final scene = await globe.scenePerformance();
              check();
              final rf = globe.liveRadio.diagnostics;
              if (rf['quality'] == 'valid') rfValid++;
              final frameRate = scene['renderFps'];
              if (frameRate is num && frameRate.isFinite) {
                fps.add(frameRate.toDouble());
              }
              final pacing = scene['framePacingMs'];
              final frameP95 = pacing is Map ? pacing['p95'] : null;
              if (frameP95 is num && frameP95.isFinite) {
                p95.add(frameP95.toDouble());
              }
              final layerStats = scene['layerStats'];
              if (layerStats is Map) {
                for (final layer in variant.layers.entries) {
                  final layerSample = layerStats[layer.key];
                  if (layerSample is! Map) continue;
                  if (layerSample['visible'] == true)
                    visibleLayers.add(layer.key);
                  if ([
                    'failed',
                    'partial',
                    'offline',
                  ].contains(layerSample['state'])) {
                    incompleteLayers.add(layer.key);
                  }
                }
              }
              if (recording.count >= DeveloperPerformanceRecording.maxSamples) {
                throw StateError(
                  'Benchmark sample limit reached; export partial results',
                );
              }
              recording.add(
                {
                  ...scene,
                  'terrainState': globe.terrainState.name,
                  'terrainWarning': globe.terrainResourceWarning,
                  'rf': {
                    for (final key in [
                      'quality',
                      'provider',
                      'ageMs',
                      'durationMs',
                      'validSamples',
                      'samples',
                      'error',
                    ])
                      key: rf[key],
                  },
                },
                {
                  'platform': platform,
                  'applicationVersion': sceneryApplicationVersion,
                  'graphicsProfile': fixed.graphicsProfile.name,
                  'physicsHz': fixed.physicsStepHz,
                  'renderScale': fixed.renderScale,
                  'benchmarkCase': variant.id,
                  'benchmarkRepetition': repeat,
                  'benchmarkRun': runIndex,
                  'benchmarkElapsedMs': clock.elapsedMilliseconds,
                  'benchmarkRouteProgress': globe.playbackProgress,
                  'benchmarkRouteSha256': routeHash,
                  'benchmarkBuildings': variant.buildings,
                  'benchmarkStructures': variant.structures,
                  'benchmarkVegetation': variant.vegetation,
                  'benchmarkRfEnabled': variant.rf,
                },
              );
            },
          );
          result['sampleCount'] =
              recording.count - (result['firstSample'] as int);
          result['wallMs'] = clock.elapsedMilliseconds;
          result['rfValidSnapshots'] = rfValid;
          result['medianFps'] = benchmarkPercentile(fps, .5);
          result['fpsP10'] = benchmarkPercentile(fps, .1);
          result['medianFrameP95Ms'] = benchmarkPercentile(p95, .5);
          result['visibleLayers'] = visibleLayers.toList();
          result['incompleteLayers'] = incompleteLayers.toList();
          result['layerVisibilityVerified'] = variant.layers.entries.every(
            (layer) =>
                layer.value == visibleLayers.contains(layer.key) &&
                !incompleteLayers.contains(layer.key),
          );
          // A run with no valid RF cannot establish an RF-on/off comparison.
          result['status'] = result['layerVisibilityVerified'] != true
              ? 'completed-layers-unverified'
              : variant.rf && rfValid == 0
              ? 'completed-rf-unverified'
              : 'completed';
          await globe.exitSimulation();
          await globe.scenePerformance(action: 'stop');
          check();
        }
      }
      status = 'completed';
    } on _BenchmarkCancelled {
      status = 'cancelled';
    } catch (_) {
      metadata['failureStage'] = status;
      status = _cancelled ? 'cancelled' : 'failed';
      // Raw provider/bridge errors may contain source URLs; never export them.
      error = _cancelled
          ? null
          : 'Benchmark interrupted (${metadata['failureStage']}). Check route, terrain, replay and sample limits.';
    } finally {
      final cleanupErrors = <String>[];
      if (globe.isReady) {
        try {
          await globe.scenePerformance(action: 'stop');
        } catch (_) {
          cleanupErrors.add('profiler');
        }
      }
      // Stop flight, restore RF, then release the renderer's temporary session.
      if (globe.isReady) {
        try {
          await globe.exitSimulation();
        } catch (_) {
          cleanupErrors.add('navigation');
        }
      }
      try {
        await globe.liveRadio.configure(originalRadio);
      } catch (_) {
        cleanupErrors.add('radio');
      }
      try {
        await globe.endBenchmark();
      } catch (_) {
        cleanupErrors.add('renderer');
      }
      if (cleanupErrors.isNotEmpty) {
        status = 'cleanup-failed';
        error =
            'Could not confirm restoration: ${cleanupErrors.join(', ')}. Reload the renderer before continuing.';
      }
      if (runs.isNotEmpty &&
          ['warming', 'measuring'].contains(runs.last['status'])) {
        runs.last['status'] = status;
        runs.last['sampleCount'] =
            recording.count - (runs.last['firstSample'] as int);
      }
      metadata['status'] = status;
      metadata['cleanupErrors'] = cleanupErrors;
      recording.stop();
      // Do not retain developer measurements after developer mode is disabled.
      WidgetsBinding.instance.removeObserver(this);
      if (!globe.developerMenusEnabled || _disposed) {
        recording.clear();
        runs.clear();
        status = 'idle';
        error = null;
      }
      active = false;
      progress = 0;
      _notify();
    }
  }

  Future<void> _waitPass(
    double duration, {
    Future<void> Function()? sample,
  }) async {
    final clock = Stopwatch()..start();
    var nextSampleMs = 1000;
    var seenPlaying = false;
    // Monotonic watchdog: low FPS, hidden window or stalled renderer cannot
    // leave the developer benchmark running indefinitely.
    final limitMs = ((duration * 3 + 15) * 1000).round();
    while (true) {
      check();
      if (clock.elapsedMilliseconds > limitMs) {
        throw StateError('Replay timeout');
      }
      final phase = globe.playbackPhase;
      if (phase == 'playing') seenPlaying = true;
      if (phase == 'finished' && seenPlaying) return;
      if (phase != 'playing') {
        if (!seenPlaying &&
            clock.elapsedMilliseconds < 1500 &&
            ['idle', 'loading', 'finished'].contains(phase)) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          continue;
        }
        throw StateError('Replay interrupted: $phase');
      }
      if (progress != globe.playbackProgress) {
        progress = globe.playbackProgress;
        _notify();
      }
      if (sample != null && clock.elapsedMilliseconds >= nextSampleMs) {
        await sample();
        nextSampleMs = clock.elapsedMilliseconds + 1000;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    cancel();
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    recording.clear();
    super.dispose();
  }
}

double? benchmarkPercentile(List<double> values, double fraction) {
  if (values.isEmpty) return null;
  final sorted = values.toList()..sort();
  final index = (sorted.length - 1) * fraction;
  final low = index.floor();
  final high = index.ceil();
  return sorted[low] + (sorted[high] - sorted[low]) * (index - low);
}

class _BenchmarkCancelled implements Exception {
  const _BenchmarkCancelled();
}
