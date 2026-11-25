import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/signal/live_radio_controller.dart';
import 'package:fpvmanager/features/signal/live_sampling_policy.dart';
import 'package:fpvmanager/features/signal/live_terrain_sampler.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';

const station = Wgs84Coordinate(latitude: 47, longitude: 8);
const signal = SignalSettings(pilot: station, antennaHeight: 2);

Map<String, dynamic> pose({double offset = 0, double height = 550}) => {
  'active': true,
  'paused': false,
  'flightId': 1,
  'latitude': station.latitude + offset / 111195,
  'longitude': station.longitude,
  'height': height,
  'homeLatitude': station.latitude,
  'homeLongitude': station.longitude,
};

RadioPathResult path(double altitude, {SignalSettings settings = signal}) =>
    calculateRadioLink(
      settings: settings,
      target: station,
      altitude: altitude,
      pilotHeight: 502,
      positions: [station, station],
      heights: [500, 500],
    );

void main() {
  test(
    'vertical clearance uses the finite segment at equator and high latitudes',
    () {
      for (final latitude in [0.0, -47.0, 80.0, 90.0]) {
        final point = Wgs84Coordinate(latitude: latitude, longitude: 8);
        final result = calculateRadioLink(
          settings: SignalSettings(pilot: point, antennaHeight: 2),
          target: point,
          altitude: 1050,
          pilotHeight: 1002,
          positions: [point, point],
          heights: [1000, 1000],
        );
        expect(result.state, RadioPathState.noSampledObstruction);
        expect(result.minimumClearance, closeTo(2, 1e-7));
      }
    },
  );

  test('vertical and near-vertical terrain paths remain clear across the old 1 m boundary', () {
    for (final offset in [0.0, .25, .99, 1.01, 5.01, 25.0]) {
      final target = Wgs84Coordinate(
        latitude: station.latitude + offset / 111195,
        longitude: station.longitude,
      );
      final plan = RouteSamplingPlan.create([
        const RouteWaypointInput(position: station),
        RouteWaypointInput(position: target),
      ], spacing: 5);
      final result = calculateRadioLink(
        settings: signal,
        target: target,
        altitude: 550,
        pilotHeight: 502,
        positions: plan.samples.map((s) => s.position).toList(),
        heights: List.filled(plan.samples.length, 500),
      );
      expect(
        result.state,
        RadioPathState.noSampledObstruction,
        reason: '$offset m horizontal',
      );
      expect(result.minimumClearance, greaterThan(0));
      expect(result.profile.first.lineHeight, closeTo(502, 1e-7));
      expect(result.profile.last.lineHeight, closeTo(550, 1e-7));
      expect(
        result.profile.every((s) => s.clearance.isFinite && s.radius.isFinite),
        true,
      );
    }
    expect(path(550).minimumClearance, closeTo(2, 1e-7));
    expect(
      path(500.5).state,
      RadioPathState.noSampledObstruction,
      reason: 'A receiver below the antenna can still be above ground',
    );
    expect(path(500.5).minimumClearance, closeTo(.5, 1e-7));
  });

  test('vertical terrain intersections and explicit surfaces are not declared clear', () {
    expect(path(499).state, RadioPathState.obstructed);
    final blocked = path(
      550,
      settings: const SignalSettings(
        pilot: station,
        antennaHeight: 2,
        useSurfaces: true,
        surfaces: [
          SurfaceObservation(
            position: station,
            height: 20,
            radius: 5,
            kind: 'building',
            source: 'test fixture',
          ),
        ],
      ),
    );
    expect(blocked.state, RadioPathState.obstructed);
    expect(blocked.minimumClearance, lessThanOrEqualTo(0));
  });

  test(
    'coincident and sub-metre spatial endpoints remain explicitly unknown',
    () {
      for (final height in [502.0, 502.25, 501.75]) {
        expect(path(height).state, RadioPathState.unknown);
        expect(path(height).profile, isEmpty);
      }
    },
  );

  test('route radio batch also evaluates a valid target above the station', () {
    final batch = RadioAnalysisBatch.forRoute([
      const RouteProfilePoint(RouteSample(station, 0, 0, 0), 500, 550),
    ], signal).single;
    final result = batch
        .calculate(signal, 500, [], includeProfiles: true)
        .single;
    expect(result.state, RadioPathState.noSampledObstruction);
    expect(result.profile, hasLength(2));
    final missing = RadioAnalysisBatch.forRoute([
      const RouteProfilePoint(RouteSample(station, 0, 0, 0), null, 550),
    ], signal).single;
    expect(
      missing.calculate(signal, 500, []).single.state,
      RadioPathState.unknown,
    );
  });

  test(
    'zero horizontal distance uses the normal bounded terrain sampler',
    () async {
      expect(
        LiveSamplingPolicy.maximumStaleness(70, 0),
        24,
        reason: 'A vertical ray keeps the strict near-field freshness bound',
      );
      expect(
        LiveSamplingPolicy.maximumStaleness(70),
        42,
        reason: 'An unspecified distance retains the existing fallback policy',
      );
      var calls = 0;
      final sampled = await LiveTerrainSampler.calculate(
        signal: signal,
        target: station,
        targetHeight: 550,
        distanceMeters: 0,
        tier: LiveSamplingPolicy.forDistance(0),
        valid: () => true,
        sample: (positions) async {
          calls++;
          expect(positions, [station, station]);
          return [500, 500];
        },
      );
      expect(calls, 1);
      expect(sampled.sampleCount, 2);
      expect(sampled.maximumGapMeters, 0);
      expect(sampled.coverageLimited, false);
      expect(sampled.path.state, RadioPathState.noSampledObstruction);
    },
  );

  test(
    'live observations remain valid while crossing directly over home',
    () async {
      var time = Duration.zero;
      final messages = <Map<String, dynamic>>[];
      final controller = LiveRadioController(
        now: () => DateTime.utc(2026).add(time),
        elapsed: () => time,
        send: (message) async {
          messages.add(message);
        },
        sample: (positions) async => List.filled(positions.length, 500),
      );
      addTearDown(controller.dispose);
      controller.renderer(true);
      await controller.configure(const LiveRadioSettings(signal: signal));
      for (final offset in [2.0, .5, 0.0, -.5, -2.0, 0.0]) {
        time += const Duration(seconds: 1);
        controller.telemetry(pose(offset: offset));
        await controller.settled;
        expect(controller.current, true, reason: '$offset m horizontal');
        expect(controller.result!.state, RadioPathState.noSampledObstruction);
        expect(controller.diagnostics['quality'], 'valid');
        final result = messages.lastWhere(
          (m) => m['type'] == 'set-live-radio-result',
        );
        expect(result['state'], 'noSampledObstruction');
        expect((result['observation'] as Map)['quality'], 'valid');
        if (offset == 0) expect(result['distanceMeters'], closeTo(48, 1e-5));
      }
    },
  );

  for (final failure in ['timeout', 'missing', 'unavailable']) {
    test(
      'vertical $failure remains uncertain and a fresh terrain query recovers',
      () async {
        var time = Duration.zero, fail = true;
        final controller = LiveRadioController(
          now: () => DateTime.utc(2026).add(time),
          elapsed: () => time,
          send: (_) async {},
          sample: (positions) async {
            if (fail) {
              if (failure == 'timeout') throw TimeoutException('test timeout');
              if (failure == 'unavailable') {
                throw StateError('TERRAIN_UNAVAILABLE: test provider');
              }
              return List.filled(positions.length, double.nan);
            }
            return List.filled(positions.length, 500);
          },
        );
        addTearDown(controller.dispose);
        controller.renderer(true);
        await controller.configure(const LiveRadioSettings(signal: signal));
        controller.telemetry(pose());
        await controller.settled;
        expect(controller.current, false);
        expect(controller.diagnostics['quality'], isNot('valid'));
        fail = false;
        time += const Duration(seconds: 1);
        controller.telemetry(pose(height: 551));
        await controller.settled;
        expect(controller.current, true);
        expect(controller.result!.state, RadioPathState.noSampledObstruction);
      },
    );
  }
}
