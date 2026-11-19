import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/routes/analysis/route_energy.dart';

const _model = RoutePlanningSettings(
  referenceMassGrams: 1000,
  flightMassGrams: 1000,
  powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 100)],
);
RouteAnalysis _route({
  bool closed = false,
  RoutePlanningSettings settings = _model,
}) {
  final points = [
    for (final lon in [0.0, .001, if (closed) 0.0])
      RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 0, longitude: lon),
        height: const AglWaypointHeight(AboveGroundHeight(50)),
        speedMetersPerSecond: 10,
      ),
  ];
  final plan = RouteSamplingPlan.create(points);
  return RouteAnalysis.calculate(
    points,
    plan,
    List.filled(plan.samples.length, 100),
    settings,
  );
}

Battery _battery({
  double? charge = 100,
  double? wh = .8,
  String availability = 'available',
  double? voltage = 10,
}) => Battery(
  id: 1,
  name: 'Pack',
  chemistry: 'LiPo',
  cellCount: 3,
  capacityMah: 80,
  isType: false,
  availability: availability,
  nominalVoltageVolts: voltage,
  energyWh: wh,
  chargePercent: charge,
);

void main() {
  test('an unachievable return does not erase known outbound energy and cannot yield affirmative reserve estimates', () {
    const tailwind = RoutePlanningSettings(
      useWind: true,
      windSpeed: 20,
      windFromDegrees: 270,
      referenceMassGrams: 1000,
      flightMassGrams: 1000,
      powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 100)],
    );
    final route = _route(settings: tailwind),
        energy = RouteEnergyEstimate.calculate(
          _route(settings: tailwind),
          tailwind,
        );
    expect(energy.available, isTrue);
    expect(energy.returnAvailable, isFalse);
    final result = BatteryRouteAssessment.calculate(
      _battery(wh: 20),
      route,
      energy,
      tailwind,
    );
    expect(result.conservativeWh, isNull);
    expect(result.status, contains('Return energy is unknown'));
    const noReturn = RoutePlanningSettings(
      useWind: true,
      windSpeed: 20,
      windFromDegrees: 270,
      includeReturn: false,
      referenceMassGrams: 1000,
      flightMassGrams: 1000,
      powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 100)],
    );
    expect(
      BatteryRouteAssessment.calculate(
        _battery(wh: 20),
        route,
        energy,
        noReturn,
      ).known,
      isTrue,
    );
  });
  test('reserve uses nominal capacity and return energy can make an outbound-feasible segment critical', () {
    final route = _route();
    final energy = RouteEnergyEstimate.calculate(route, _model);
    final assessment = BatteryRouteAssessment.calculate(
      _battery(),
      route,
      energy,
      _model,
    );
    expect(assessment.budgetWh, closeTo(.64, 1e-8));
    expect(
      energy.totalWh! * _model.conservativeFactor,
      lessThan(assessment.budgetWh!),
    );
    expect(assessment.conservativeWh, greaterThan(assessment.budgetWh!));
    expect(assessment.criticalSegments, {0});
    expect(assessment.optimisticWh, lessThan(assessment.conservativeWh!));
  });
  test('closed routes do not add a second full route at takeoff; reverse wind changes return duration', () {
    final route = _route(closed: true);
    final energy = RouteEnergyEstimate.calculate(route, _model);
    final result = BatteryRouteAssessment.calculate(
      _battery(wh: 10),
      route,
      energy,
      _model,
    );
    expect(
      result.conservativeWh,
      closeTo(energy.totalWh! * _model.conservativeFactor, 1e-8),
    );
    const wind = RoutePlanningSettings(
      useWind: true,
      windSpeed: 5,
      windFromDegrees: 90,
      referenceMassGrams: 1000,
      flightMassGrams: 1000,
      powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 100)],
    );
    final windy = _route(settings: wind),
        windyEnergy = RouteEnergyEstimate.calculate(
          _route(settings: wind),
          wind,
        );
    expect(windy.segments.single.returnSeconds, lessThan(windy.seconds!));
    expect(windyEnergy.returnWh.single, lessThan(windyEnergy.totalWh!));
  });
  test('unknown charge, unknown voltage and unavailable packs do not produce affirmative feasibility', () {
    final route = _route();
    final energy = RouteEnergyEstimate.calculate(route, _model);
    expect(
      BatteryRouteAssessment.calculate(
        _battery(charge: null),
        route,
        energy,
        _model,
      ).known,
      isFalse,
    );
    final inferredOnly = BatteryRouteAssessment.calculate(
      _battery(voltage: null, wh: null),
      route,
      energy,
      _model,
    );
    expect(inferredOnly.known, isFalse);
    expect(inferredOnly.budgetWh, isNull);
    expect(inferredOnly.status, contains('Chemistry reference voltage'));
    expect(inferredOnly.status, isNot(contains('Within')));
    // Recorded Wh is sufficient for a budget even without a voltage reading;
    // only load-current diagnostics then use chemistry reference voltage.
    final recordedWh = BatteryRouteAssessment.calculate(
      _battery(voltage: null, wh: 10),
      route,
      energy,
      _model,
    );
    expect(recordedWh.known, isTrue);
    expect(recordedWh.availableWh, 10);
    final unknown = BatteryRouteAssessment.calculate(
      _battery(wh: 20, availability: 'unknown'),
      route,
      energy,
      _model,
    );
    expect(unknown.status, contains('confirm'));
    expect(unknown.status, isNot(contains('Within')));
    final half = BatteryRouteAssessment.calculate(
      _battery(wh: 10, charge: 50),
      route,
      energy,
      _model,
    );
    expect(half.availableWh, 5);
    expect(half.budgetWh, 3);
  });
  test('chemistry reference current influences route warnings without changing flight Wh', () {
    const fast = RoutePlanningSettings(
      referenceMassGrams: 1000,
      flightMassGrams: 1000,
      includeReturn: false,
      powerCurve: [PowerCurvePoint(0, 900), PowerCurvePoint(20, 900)],
    );
    final route = _route(settings: fast);
    final energy = RouteEnergyEstimate.calculate(route, fast);
    Battery pack(String chemistry, double nominal) => Battery(
      id: 19,
      name: chemistry,
      chemistry: chemistry,
      cellCount: 6,
      capacityMah: 4500,
      isType: false,
      availability: 'available',
      nominalVoltageVolts: nominal,
      energyWh: nominal * 4.5,
      chargePercent: 100,
    );
    final lipo = BatteryRouteAssessment.calculate(
      pack('LiPo', 22.2),
      route,
      energy,
      fast,
    );
    final liion = BatteryRouteAssessment.calculate(
      pack('LiIon', 21.6),
      route,
      energy,
      fast,
    );
    expect(lipo.loadLimitedSegments, isEmpty);
    expect(liion.loadLimitedSegments, isNotEmpty);
    expect(
      liion.estimatedCurrentLimitAmps,
      lessThan(lipo.estimatedCurrentLimitAmps!),
    );
    expect(lipo.conservativeWh, liion.conservativeWh);
    expect(
      liion.maxEstimatedCurrentAmps,
      greaterThan(liion.estimatedCurrentLimitAmps!),
    );
  });

  test(
    'ESC and motor limits are assessed independently from battery C rating',
    () {
      const fast = RoutePlanningSettings(
        referenceMassGrams: 1000,
        flightMassGrams: 1000,
        includeReturn: false,
        powerCurve: [PowerCurvePoint(0, 900), PowerCurvePoint(20, 900)],
      );
      final route = _route(settings: fast);
      final energy = RouteEnergyEstimate.calculate(route, fast);
      final pack = Battery(
        id: 45,
        name: 'high C pack',
        chemistry: 'LiPo',
        cellCount: 6,
        capacityMah: 4500,
        continuousDischargeC: 120,
        isType: false,
        availability: 'available',
        nominalVoltageVolts: 22.2,
        energyWh: 99.9,
        chargePercent: 100,
      );
      final drone = Drone(
        id: 2,
        name: 'quad',
        type: 'quadcopter',
        createdAt: DateTime.utc(2026),
        motorCount: 4,
        escContinuousCurrentAmpsPerChannel: 8,
        motorContinuousCurrentAmpsPerMotor: 30,
      );
      final assessed = BatteryRouteAssessment.calculate(
        pack,
        route,
        energy,
        fast,
        drone: drone,
      );
      expect(assessed.loadLimitedSegments, isEmpty);
      expect(assessed.escLimitedSegments, isNotEmpty);
      expect(assessed.motorLimitedSegments, isEmpty);
      expect(assessed.peakEstimatedPerUnitCurrentAmps, isNotNull);
      final unknownCount = BatteryRouteAssessment.calculate(
        pack,
        route,
        energy,
        fast,
        drone: Drone(
          id: 3,
          name: 'unknown motors',
          type: 'quadcopter',
          createdAt: DateTime.utc(2026),
          escContinuousCurrentAmpsPerChannel: 1,
        ),
      );
      expect(unknownCount.escLimitedSegments, isEmpty); // unknown, not safe
      expect(unknownCount.peakEstimatedPerUnitCurrentAmps, isNull);
    },
  );

  test('takeoff mass scales power and climb energy; measurements outside the curve remain unsupported', () {
    final route = _route();
    final baseline = RouteEnergyEstimate.calculate(route, _model);
    const heavy = RoutePlanningSettings(
      referenceMassGrams: 1000,
      flightMassGrams: 4000,
      powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 100)],
    );
    expect(
      RouteEnergyEstimate.calculate(route, heavy).totalWh,
      closeTo(baseline.totalWh! * 8, 1e-8),
    );
  });
}
