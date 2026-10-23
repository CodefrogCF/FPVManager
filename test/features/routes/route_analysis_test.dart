import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/routes/analysis/route_energy.dart';

List<RouteWaypointInput> points({double height = 50, bool unknown = false}) => [
  const RouteWaypointInput(
    position: Wgs84Coordinate(latitude: 0, longitude: 0),
    height: AglWaypointHeight(AboveGroundHeight(50)),
    speedMetersPerSecond: 10,
  ),
  RouteWaypointInput(
    position: const Wgs84Coordinate(latitude: 0, longitude: .001),
    height: unknown ? null : AglWaypointHeight(AboveGroundHeight(height)),
  ),
];
RouteAnalysis calculate(
  List<RouteWaypointInput> p, {
  RoutePlanningSettings settings = const RoutePlanningSettings(),
  List<double>? terrain,
}) {
  final plan = RouteSamplingPlan.create(p);
  return RouteAnalysis.calculate(
    p,
    plan,
    terrain ?? List.filled(plan.samples.length, 100),
    settings,
  );
}

const model = RoutePlanningSettings(
  referenceMassGrams: 1000,
  flightMassGrams: 1000,
  powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 200)],
);
void main() {
  test('profile samples the interior of legs and detects terrain above the planned line', () {
    final p = points();
    final plan = RouteSamplingPlan.create(p);
    expect(plan.samples.length, greaterThan(2));
    final ground = List.filled(plan.samples.length, 100.0);
    ground[1] = 200;
    final route = RouteAnalysis.calculate(
      p,
      plan,
      ground,
      const RoutePlanningSettings(),
    );
    expect(route.minimumClearance, -50);
    expect(route.profile[1].altitude, 150);
    expect(route.segments.single.minimumClearance, -50);
    expect(plan.samples.last.position.longitude, .001);
    expect(plan.samples.every((s) => s.distance.isFinite), isTrue);
  });
  test('distance, climbs, descent and duration use the configured outgoing airspeed', () {
    final route = calculate(points(height: 150));
    final horizontal = route.horizontalDistance;
    expect(horizontal, closeTo(111.195, .01));
    expect(
      route.spatialDistance,
      closeTo(math.sqrt(horizontal * horizontal + 10000), 1e-8),
    );
    expect(route.climb, 100);
    expect(route.descent, 0);
    expect(route.seconds, closeTo(route.spatialDistance! / 10, 1e-8));
  });
  test(
    'headwind, tailwind and impossible crosswind remain directionally correct',
    () {
      final head = calculate(
        points(),
        settings: const RoutePlanningSettings(
          useWind: true,
          windSpeed: 5,
          windFromDegrees: 90,
        ),
      );
      expect(head.seconds, closeTo(head.horizontalDistance / 5, 1e-8));
      expect(
        head.segments.single.returnSeconds,
        closeTo(head.horizontalDistance / 15, 1e-8),
      );
      final cross = calculate(
        points(),
        settings: const RoutePlanningSettings(
          useWind: true,
          windSpeed: 11,
          windFromDegrees: 0,
        ),
      );
      expect(cross.seconds, isNull);
      final blocked = calculate(
        points(),
        settings: const RoutePlanningSettings(
          useWind: true,
          windSpeed: 10,
          windFromDegrees: 90,
        ),
      );
      expect(blocked.seconds, isNull);
    },
  );
  test('unknown heights and incompatible datums cannot become positive clearance or energy estimates', () {
    final r = calculate(points(unknown: true));
    expect(r.minimumClearance, isNull);
    expect(r.spatialDistance, isNull);
    expect(r.seconds, isNull);
    expect(r.profile.first.altitude, 150);
    expect(RouteEnergyEstimate.calculate(r, model).available, isFalse);
    final p = [
      for (final point in points())
        RouteWaypointInput(
          position: point.position,
          height: const AbsoluteWaypointHeight(
            ReferencedElevation(meters: 500, reference: VerticalReference.ln02),
          ),
        ),
    ];
    expect(calculate(p).minimumClearance, isNull);
    final plan = RouteSamplingPlan.create(points());
    final noTerrain = RouteAnalysis.calculate(points(), plan, null, model);
    expect(noTerrain.terrainAvailable, isFalse);
    expect(noTerrain.minimumClearance, isNull);
  });
  test('energy interpolates level-flight power, includes climb work and preserves nominal voltage semantics', () {
    final route = calculate(points(height: 150));
    final energy = RouteEnergyEstimate.calculate(route, model);
    expect(
      energy.totalWh,
      closeTo(150 * route.seconds! / 3600 + 9.80665 * 100 / .65 / 3600, 1e-8),
    );
    expect(energy.returnWh.single, closeTo(150 * route.seconds! / 3600, 1e-8));
    expect(energy.approximateMah(null), isNull);
    expect(energy.approximateMah(10), closeTo(energy.totalWh! * 100, 1e-8));
    const shortCurve = RoutePlanningSettings(
      referenceMassGrams: 1000,
      flightMassGrams: 1000,
      powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(5, 120)],
    );
    expect(RouteEnergyEstimate.calculate(route, shortCurve).available, isFalse);
  });
  test(
    'sampling bounds, antimeridian interpolation and settings round-trip',
    () {
      final p = [
        for (final lon in [179.999, -179.999])
          RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 0, longitude: lon),
          ),
      ];
      final plan = RouteSamplingPlan.create(p);
      expect(
        plan.samples.every((s) => s.position.longitude.abs() > 179.9),
        isTrue,
      );
      expect(
        () => RouteSamplingPlan.create([
          points().first,
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 0, longitude: 10),
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        RoutePlanningSettings.decode(model.encode()).powerCurve.last.watts,
        200,
      );
      expect(
        () => RoutePlanningSettings.decode('{"version":99}'),
        throwsFormatException,
      );
    },
  );
}
