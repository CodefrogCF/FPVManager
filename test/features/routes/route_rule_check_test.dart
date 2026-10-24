import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_constraints.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/routes/analysis/route_rule_check.dart';

void main() {
  List<RouteWaypointInput> points(double? agl) => [
    for (final lon in [8.0, 8.003])
      RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 47, longitude: lon),
        height: agl == null ? null : AglWaypointHeight(AboveGroundHeight(agl)),
      ),
  ];
  test('intermediate terrain dips detect ceiling exceedance between legal-height waypoints', () {
    final p = points(30), plan = RouteSamplingPlan.create(p);
    final ground = [
      for (var i = 0; i < plan.samples.length; i++)
        i == 0 || i == plan.samples.length - 1 ? 100.0 : 0.0,
    ];
    final route = RouteAnalysis.calculate(
      p,
      plan,
      ground,
      const RoutePlanningSettings(),
    );
    final check = RouteRuleCheck.calculate(
      route,
      p,
      const RouteConstraints(operationalCeilingAgl: 100),
    );
    expect(check.findings.any((f) => f.message.contains('legal')), isTrue);
    expect(
      check.findings.any((f) => f.message.contains('operational')),
      isTrue,
    );
    expect(check.findings.every((f) => f.segment == 0), isTrue);
  });
  test('unknown heights remain unassessed and AGL endpoint exceedance is retained offline', () {
    final p = points(null), plan = RouteSamplingPlan.create(p);
    final route = RouteAnalysis.calculate(
      p,
      plan,
      null,
      const RoutePlanningSettings(),
    );
    final check = RouteRuleCheck.calculate(route, p, const RouteConstraints());
    expect(check.unknownHeightSamples, plan.samples.length);
    expect(check.findings, isEmpty);
    final high = points(150);
    final offline = RouteAnalysis.calculate(
      high,
      RouteSamplingPlan.create(high),
      null,
      const RoutePlanningSettings(),
    );
    expect(
      RouteRuleCheck.calculate(
        offline,
        high,
        const RouteConstraints(),
      ).findings,
      isNotEmpty,
    );
  });
  test('planning radius is independent of VLOS declaration and settings survive persistence', () {
    final p = points(30), plan = RouteSamplingPlan.create(p);
    final route = RouteAnalysis.calculate(
      p,
      plan,
      List.filled(plan.samples.length, 100),
      const RoutePlanningSettings(),
    );
    const constraints = RouteConstraints(
      legalCeilingAgl: null,
      operationalCeilingAgl: 100,
      planningRadiusMeters: 100,
      visibility: RouteVisibilityMode.bvlos,
    );
    final settings = RoutePlanningSettings.decode(
      const RoutePlanningSettings().withConstraints(constraints).encode(),
    );
    expect(settings.constraints.legalCeilingAgl, isNull);
    expect(settings.constraints.visibility, RouteVisibilityMode.bvlos);
    final check = RouteRuleCheck.calculate(route, p, settings.constraints);
    expect(
      check.findings.any((f) => f.message.contains('VLOS requires manual')),
      isTrue,
    );
    expect(check.findings.any((f) => f.message.contains('ceiling')), isFalse);
  });
}
