import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/signal/live_radio_controller.dart';

const _pilot = Wgs84Coordinate(latitude: 47, longitude: 8);
const _earthRadius = 6371008.8;
const _durationMs = 12000;
const _stepMs = 20;
const _warmupMs = 2000;

Wgs84Coordinate _destination(double distance, double bearing) {
  final latitude = _pilot.latitude * math.pi / 180;
  final longitude = _pilot.longitude * math.pi / 180;
  final angle = distance / _earthRadius;
  final targetLatitude = math.asin(
    math.sin(latitude) * math.cos(angle) +
        math.cos(latitude) * math.sin(angle) * math.cos(bearing),
  );
  final targetLongitude =
      longitude +
      math.atan2(
        math.sin(bearing) * math.sin(angle) * math.cos(latitude),
        math.cos(angle) - math.sin(latitude) * math.sin(targetLatitude),
      );
  return Wgs84Coordinate(
    latitude: targetLatitude * 180 / math.pi,
    longitude: targetLongitude * 180 / math.pi,
  );
}

double? _percentile(List<double> values, double p) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[(sorted.length * p).ceil() - 1];
}

void main() {
  final results = <Map<String, Object?>>[];
  for (final distance in [1000.0, 3000.0, 5000.0, 5990.0]) {
    for (final speedKmh in [100.0, 140.0]) {
      for (final motion in ['radial', 'lateral']) {
        for (final batchLatencyMs in [160, 400]) {
          for (final blocked in [false, true]) {
            final name =
                '${distance.toInt()}m ${speedKmh.toInt()}kmh $motion ${batchLatencyMs}ms ${blocked ? 'blocked' : 'clear'}';
            testWidgets('moving RF controller benchmark: $name', (
              tester,
            ) async {
              final origin = tester.binding.clock.now();
              Duration elapsed() =>
                  tester.binding.clock.now().difference(origin);
              final speed = speedKmh / 3.6;
              final telemetryMs = speed >= 30 ? 200 : 400;
              Wgs84Coordinate positionAt(double seconds) => motion == 'radial'
                  ? _destination(
                      distance + speed * (seconds - _durationMs / 2000),
                      math.pi / 2,
                    )
                  : _destination(
                      distance,
                      math.pi / 2 + speed * seconds / distance,
                    );
              double ground(Wgs84Coordinate p) {
                final radial = routeDistance(_pilot, p);
                final offset = (radial - distance * .55) / 120;
                return 500 + (blocked ? 700 : 85) * math.exp(-offset * offset);
              }

              var terrainBatches = 0,
                  requestedSamples = 0,
                  activeSamples = 0,
                  maximumActiveSamples = 0,
                  publications = 0,
                  falseClear = 0,
                  unknownMs = 0,
                  steadyUnknownMs = 0,
                  currentGapMs = 0,
                  maximumUnknownGapMs = 0;
              var maximumPublishedTelemetryDrift = 0.0;
              var latestTelemetry = positionAt(0);
              final publishedAges = <double>[];
              final c = LiveRadioController(
                elapsed: elapsed,
                now: () => DateTime.utc(2026, 11, 24).add(elapsed()),
                sample: (positions) async {
                  ++terrainBatches;
                  requestedSamples += positions.length;
                  ++activeSamples;
                  maximumActiveSamples = math.max(
                    maximumActiveSamples,
                    activeSamples,
                  );
                  try {
                    await Future<void>.delayed(
                      Duration(milliseconds: batchLatencyMs),
                    );
                    return positions.map(ground).toList(growable: false);
                  } finally {
                    --activeSamples;
                  }
                },
                send: (message) async {
                  if (message['type'] != 'set-live-radio-result' ||
                      message['state'] == 'unknown') {
                    return;
                  }
                  final observation = message['observation'] as Map;
                  if (observation['quality'] != 'valid') return;
                  ++publications;
                  final ray = (message['rays'] as List).single as Map;
                  final published = Wgs84Coordinate(
                    latitude: (ray['latitude'] as num).toDouble(),
                    longitude: (ray['longitude'] as num).toDouble(),
                  );
                  maximumPublishedTelemetryDrift = math.max(
                    maximumPublishedTelemetryDrift,
                    routeDistance(latestTelemetry, published),
                  );
                  publishedAges.add((observation['ageMs'] as num).toDouble());
                  if (blocked && message['state'] == 'noSampledObstruction') {
                    ++falseClear;
                  }
                },
              );
              try {
                c.renderer(true);
                await c.configure(const LiveRadioSettings());
                for (var ms = 0; ms < _durationMs; ms += _stepMs) {
                  if (ms % telemetryMs == 0) {
                    latestTelemetry = positionAt(ms / 1000);
                    c.telemetry({
                      'active': true,
                      'paused': false,
                      'flightId': 1,
                      'latitude': latestTelemetry.latitude,
                      'longitude': latestTelemetry.longitude,
                      'height': 1000.0,
                      'speed': speed,
                      'homeLatitude': _pilot.latitude,
                      'homeLongitude': _pilot.longitude,
                    });
                  }
                  await tester.pump(const Duration(milliseconds: _stepMs));
                  final valid =
                      c.current && c.diagnostics['quality'] == 'valid';
                  if (!valid) {
                    unknownMs += _stepMs;
                    currentGapMs += _stepMs;
                    if (ms >= _warmupMs) steadyUnknownMs += _stepMs;
                    maximumUnknownGapMs = math.max(
                      maximumUnknownGapMs,
                      currentGapMs,
                    );
                  } else {
                    currentGapMs = 0;
                  }
                }
                final diagnostic = c.diagnostics;
                final history = (diagnostic['history'] as List).cast<Map>();
                final durations = history
                    .map((entry) => (entry['durationMs'] as num).toDouble())
                    .toList();
                results.add({
                  'distanceMeters': distance,
                  'speedKmh': speedKmh,
                  'motion': motion,
                  'terrain': blocked
                      ? 'blockedMountainRing'
                      : 'clearMountainRing',
                  'prescribedBatchLatencyMs': batchLatencyMs,
                  'durationMs': _durationMs,
                  'telemetryIntervalMs': telemetryMs,
                  'initialRangeMeters': routeDistance(_pilot, positionAt(0)),
                  'finalRangeMeters': routeDistance(
                    _pilot,
                    positionAt(_durationMs / 1000),
                  ),
                  'attempts': diagnostic['attempts'],
                  'validPublications': publications,
                  'validTimeFraction': 1 - unknownMs / _durationMs,
                  'unknownDurationMs': unknownMs,
                  'steadyUnknownDurationMs': steadyUnknownMs,
                  'steadyValidTimeFraction':
                      1 - steadyUnknownMs / (_durationMs - _warmupMs),
                  'maximumUnknownGapMs': maximumUnknownGapMs,
                  'calculationLatencyMs': {
                    'p50': _percentile(durations, .5),
                    'p95': _percentile(durations, .95),
                  },
                  'publishedObservationAgeMs': {
                    'p50': _percentile(publishedAges, .5),
                    'p95': _percentile(publishedAges, .95),
                  },
                  'terrainBatches': terrainBatches,
                  'requestedSamples': requestedSamples,
                  'maximumActiveTerrainBatches': maximumActiveSamples,
                  'maximumPublishedTelemetryDriftMeters':
                      maximumPublishedTelemetryDrift,
                  'falseClearPublications': falseClear,
                });
                expect(falseClear, 0, reason: name);
                expect(
                  maximumActiveSamples,
                  lessThanOrEqualTo(1),
                  reason: name,
                );
                expect(requestedSamples, greaterThan(0), reason: name);
              } finally {
                c.dispose();
                // The mock's finite I/O is independent of request cancellation.
                await tester.pump(Duration(milliseconds: batchLatencyMs + 1));
              }
            });
          }
        }
      }
    }
  }
  tearDownAll(() {
    final output = Platform.environment['FPV_RF_MOTION_BENCHMARK_OUTPUT'];
    if (output == null || output.isEmpty) return;
    final destination = File(output);
    destination.parent.createSync(recursive: true);
    destination.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'kind': 'synthetic-controller-motion',
        'fixture': {'clock': 'deterministic Flutter test clock', 'controller': 'actual LiveRadioController and adaptive terrain sampler', 'batchLatency': 'prescribed per request, not measured provider/network latency', 'durationMs': _durationMs, 'tickMs': _stepMs, 'steadyWindowStartsMs': _warmupMs, 'terrain': 'analytic radial mountain ring; exact requested coordinates', 'radialMotion': 'straight outward motion, centered on nominal range', 'lateralMotion': 'constant-radius circle at stated speed', 'near6kmRadiusMeters': 5990},
        'unmeasured': ['real device/network/GPU performance', 'recorded flight unknown durations'],
        'scenarios': results,
      })}\n',
    );
  });
}
