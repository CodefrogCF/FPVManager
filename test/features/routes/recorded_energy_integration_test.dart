import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/recorded_route_track.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/routes/analysis/route_energy.dart';

const model = RoutePlanningSettings(
  flightMassGrams: 1000,
  referenceMassGrams: 1000,
  includeReturn: false,
  powerCurve: [PowerCurvePoint(0, 200), PowerCurvePoint(20, 200)],
);

List<RouteWaypointInput> routePoints() => [
  for (var i = 0; i < 3; i++)
    RouteWaypointInput(
      position: Wgs84Coordinate(latitude: 46.7 + i * .0001, longitude: 8.4),
      height: AbsoluteWaypointHeight(
        ReferencedElevation(
          meters: 1000 + i * 10,
          reference: VerticalReference.wgs84Ellipsoid,
        ),
      ),
    ),
];

RecordedRouteTrack track(
  List<RouteWaypointInput> points, {
  bool withAirspeed = false,
}) => RecordedRouteTrack(
  id: 'test-telemetry',
  startedAtUtc: DateTime.utc(2026, 11, 18, 12),
  waypointSignature: recordedInputSignature(points),
  interrupted: true,
  samples: [
    for (var i = 0; i < points.length; i++)
      RecordedTrackSample(
        seconds: [0.0, 10.0, 25.0][i],
        absoluteElevationMeters: 1000 + i * 10,
        terrainElevationMeters: i == 1 ? null : 950,
        groundSpeedMetersPerSecond: [4.0, 6.0, 9.0][i],
        airspeedMetersPerSecond: withAirspeed && i == 0 ? 9 : null,
        airspeedSource: withAirspeed && i == 0
            ? RecordedAirspeedSource.simulator
            : null,
      ),
  ],
);

RouteAnalysis analyze(
  List<RouteWaypointInput> points,
  RoutePlanningSettings settings,
  RecordedRouteTrack? recorded, {
  double? cruise,
  double? climb,
}) => RouteAnalysis.calculate(
  points,
  RouteSamplingPlan.create(points),
  null,
  settings,
  recordedTrack: recorded,
  droneCruiseSpeedMetersPerSecond: cruise,
  droneMaxClimbRateMetersPerSecond: climb,
);

void main() {
  test('v1 tracks and old route settings remain readable without inventing airspeed', () {
    final points = routePoints();
    final original = track(points).toJson();
    final legacy = Map<String, dynamic>.from(original)
      ..['version'] = 1
      ..remove('interrupted')
      ..['samples'] = [
        for (final sample in track(points).samples)
          sample.toJson().take(4).toList(),
      ];
    final restored = RecordedRouteTrack.fromJson(legacy);
    expect(restored.interrupted, isFalse);
    expect(restored.durationSeconds, 25);
    expect(restored.samples[1].airspeedMetersPerSecond, isNull);
    expect(restored.samples.first.groundSpeedMetersPerSecond, 4);
    final settings = jsonDecode(model.encode()) as Map<String, dynamic>;
    settings.remove('estimateMissingTelemetry');
    expect(
      RoutePlanningSettings.decode(jsonEncode(settings))
          .estimateMissingTelemetry,
      isFalse,
    );
  });

  test('v2 telemetry retains UTC timing, interruption and airspeed origin', () {
    final points = routePoints();
    final saved = track(points, withAirspeed: true);
    final restored = RecordedRouteTrack.fromJson(saved.toJson());
    expect(restored.interrupted, isTrue);
    expect(restored.durationSeconds, 25);
    expect(
      restored.timestampAt(restored.samples[1]),
      DateTime.utc(2026, 11, 18, 12, 0, 10),
    );
    expect(restored.samples.first.airspeedMetersPerSecond, 9);
    expect(
      restored.samples.first.airspeedSource,
      RecordedAirspeedSource.simulator,
    );
    expect(restored.samples[1].airspeedMetersPerSecond, isNull);
    expect(restored.samples[1].aglMeters, isNull);
    expect(
      () => RecordedTrackSample.fromJson([0, 8, 1000, 900, 10, 'invalid']),
      throwsFormatException,
    );
    expect(
      () => RecordedTrackSample.fromJson([0, 8, 1000, 900, 10, null]),
      throwsFormatException,
    );
  });

  test('recorded times and known absolute heights reach the energy model', () {
    final points = routePoints(), recorded = track(points);
    final analysis = analyze(points, model, recorded);
    expect(analysis.seconds, 25);
    expect(analysis.segments.map((s) => s.seconds), [10, 15]);
    expect(analysis.segments.map((s) => s.heightChange), [10, 10]);
    expect(
      analysis.segments.every(
        (s) => s.durationOrigin == RouteValueOrigin.simulated,
      ),
      isTrue,
    );
    // Simulator ground speed is explicitly not an airspeed measurement.
    expect(analysis.segments.every((s) => s.speed == null), isTrue);
    expect(analysis.segments.first.groundSpeed, 4);
    expect(RouteEnergyEstimate.calculate(analysis, model).available, isFalse);
  });

  test('opt-in estimates fill gaps without replacing recorded durations', () {
    final points = routePoints(), recorded = track(points);
    final optedIn = model.withTelemetryEstimation(true);
    final analysis = analyze(points, optedIn, recorded, cruise: 10, climb: 3);
    expect(analysis.seconds, 25);
    expect(analysis.segments.map((s) => s.speed), [8, 8]);
    expect(
      analysis.segments.every(
        (s) => s.speedOrigin == RouteValueOrigin.estimated,
      ),
      isTrue,
    );
    expect(
      analysis.segments.every(
        (s) => s.durationOrigin == RouteValueOrigin.simulated,
      ),
      isTrue,
    );
    final energy = RouteEnergyEstimate.calculate(analysis, optedIn);
    expect(energy.available, isTrue);
    expect(energy.recordedDurationSegments, 2);
    expect(energy.estimatedSegments, 2);
    expect(energy.estimatedWh, closeTo(energy.totalWh!, 1e-8));
    expect(energy.totalWh!, greaterThan(200 * 25 / 3600));
    expect(track(points).samples.first.airspeedMetersPerSecond, isNull);
  });

  test('explicit airspeed is preferred while remaining gaps are estimated', () {
    final points = routePoints();
    final optedIn = model.withTelemetryEstimation(true);
    final analysis = analyze(
      points,
      optedIn,
      track(points, withAirspeed: true),
      cruise: 10,
    );
    expect(analysis.segments.first.speed, 9);
    expect(analysis.segments.first.speedOrigin, RouteValueOrigin.simulated);
    expect(analysis.segments.last.speed, 8);
    expect(analysis.segments.last.speedOrigin, RouteValueOrigin.estimated);
    final energy = RouteEnergyEstimate.calculate(analysis, optedIn);
    expect(energy.estimatedSegments, 1);
    expect(energy.estimatedFraction, greaterThan(0));
    expect(energy.estimatedFraction, lessThan(1));
  });

  test('drone profile provides fallback power curve only with opt-in', () {
    final points = routePoints(), recorded = track(points);
    const noCurve = RoutePlanningSettings(
      flightMassGrams: 1000,
      includeReturn: false,
    );
    final on = noCurve.withTelemetryEstimation(true);
    final analysis = analyze(points, on, recorded, cruise: 10);
    expect(RouteEnergyEstimate.calculate(analysis, noCurve).available, isFalse);
    final estimate = RouteEnergyEstimate.calculate(
      analysis,
      on,
      droneMassGrams: 1000,
      droneCruiseSpeedMetersPerSecond: 10,
      droneHoverPowerWatts: 150,
      droneCruisePowerWatts: 200,
    );
    expect(estimate.available, isTrue);
    expect(estimate.powerCurveSource, contains('Drone profile'));
    expect(estimate.estimatedSegments, 2);
  });

  test(
    'without sufficient profile data, missing airspeed stays unavailable',
    () {
      final points = routePoints();
      const withoutCurve = RoutePlanningSettings(
        flightMassGrams: 1000,
        referenceMassGrams: 1000,
        estimateMissingTelemetry: true,
      );
      final analysis = analyze(points, withoutCurve, track(points));
      expect(analysis.segments.first.speed, isNull);
      expect(
        RouteEnergyEstimate.calculate(analysis, withoutCurve).available,
        isFalse,
      );
    },
  );

  test('recorded metadata is ignored when the route signature changes', () {
    final points = routePoints();
    final changed = [
      points.first,
      RouteWaypointInput(
        position: const Wgs84Coordinate(latitude: 47, longitude: 8.4),
        height: points[1].height,
      ),
      points.last,
    ];
    final analysis = analyze(changed, model, track(points));
    expect(
      analysis.segments.first.durationOrigin,
      isNot(RouteValueOrigin.simulated),
    );
    expect(analysis.segments.first.seconds, isNull);
  });
}
