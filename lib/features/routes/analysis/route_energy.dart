import 'dart:math' as math;

import '../../../core/database/fpv_database.dart' show Battery;
import '../../../core/models/route_planning_settings.dart';
import 'route_analysis.dart';

class RouteEnergyEstimate {
  RouteEnergyEstimate._(this.outboundWh, this.returnWh, this.problem);
  final List<double> outboundWh;
  final List<double?> returnWh;
  final String? problem;
  bool get available => problem == null;
  bool get returnAvailable => available && returnWh.every((v) => v != null);
  double? get totalWh =>
      !available ? null : outboundWh.fold<double>(0, (n, v) => n + v);
  double? approximateMah(double? voltage) {
    if (!available || voltage == null || !voltage.isFinite || voltage <= 0) {
      return null;
    }
    final value = totalWh! / voltage * 1000;
    return value.isFinite ? value : null;
  }

  factory RouteEnergyEstimate.calculate(
    RouteAnalysis route,
    RoutePlanningSettings settings, {
    double? droneMassGrams,
  }) {
    settings.validate();
    final mass = settings.flightMassGrams ?? droneMassGrams,
        reference = settings.referenceMassGrams;
    RouteEnergyEstimate unavailable(String reason) =>
        RouteEnergyEstimate._(const [], const [], reason);
    if (mass == null || !mass.isFinite || mass <= 0 || reference == null) {
      return unavailable(
        'Enter total takeoff mass and the power curve reference mass. Include the installed battery.',
      );
    }
    if (settings.powerCurve.length < 2) {
      return unavailable(
        'Enter at least two speed/power measurements or estimates for level flight.',
      );
    }
    double? power(double speed) {
      final curve = settings.powerCurve;
      if (speed < curve.first.speed || speed > curve.last.speed) return null;
      for (var i = 1; i < curve.length; i++) {
        if (speed <= curve[i].speed) {
          final a = curve[i - 1], b = curve[i];
          return (a.watts +
                  (b.watts - a.watts) *
                      (speed - a.speed) /
                      (b.speed - a.speed)) *
              math.pow(mass / reference, 1.5);
        }
      }
      return null;
    }

    final outbound = <double>[], returning = <double?>[];
    for (final segment in route.segments) {
      if (segment.seconds == null ||
          segment.heightChange == null ||
          segment.speed == null) {
        return unavailable(
          'Known heights, outgoing airspeeds and an achievable wind-corrected outbound track are required.',
        );
      }
      final watts = power(segment.speed!);
      if (watts == null) {
        return unavailable(
          'Airspeed in segment ${segment.index + 1} lies outside the power curve. No extrapolation is applied.',
        );
      }
      double energy(double duration, double climb) =>
          watts * duration / 3600 +
          mass /
              1000 *
              9.80665 *
              math.max(0, climb) /
              settings.climbEfficiency /
              3600;
      final wh = energy(segment.seconds!, segment.heightChange!),
          back = segment.returnSeconds == null
              ? null
              : energy(segment.returnSeconds!, -segment.heightChange!);
      if (!wh.isFinite || (back != null && !back.isFinite)) {
        return unavailable(
          'The model exceeds its numeric range. Check inputs.',
        );
      }
      outbound.add(wh);
      returning.add(back);
    }
    return RouteEnergyEstimate._(
      List.unmodifiable(outbound),
      List.unmodifiable(returning),
      null,
    );
  }
}

class BatteryRouteAssessment {
  BatteryRouteAssessment._({
    required this.battery,
    required this.availableWh,
    required this.budgetWh,
    required this.optimisticWh,
    required this.conservativeWh,
    required this.criticalSegments,
    required this.status,
  });
  final Battery battery;
  final double? availableWh, budgetWh, optimisticWh, conservativeWh;
  final Set<int> criticalSegments;
  final String status;
  bool get known =>
      budgetWh != null && optimisticWh != null && conservativeWh != null;

  /// Each pack is an alternative. Return follows the already planned path back
  /// to takeoff, using the outgoing speed of each segment in reverse direction.
  factory BatteryRouteAssessment.calculate(
    Battery battery,
    RouteAnalysis route,
    RouteEnergyEstimate energy,
    RoutePlanningSettings settings,
  ) {
    final voltage = battery.nominalVoltageVolts;
    final capacity =
        battery.energyWh ??
        (voltage == null ? null : voltage * battery.capacityMah / 1000);
    final charge = battery.chargePercent;
    final available =
        capacity != null &&
            capacity.isFinite &&
            capacity > 0 &&
            charge != null &&
            charge.isFinite &&
            charge >= 0 &&
            charge <= 100
        ? capacity * (charge / 100)
        : null;
    final budget = available == null
        ? null
        : available - capacity! * (settings.reservePercent / 100);
    final critical = <int>{};
    double? optimistic, conservative;
    if (energy.available &&
        (!settings.includeReturn || energy.returnAvailable) &&
        budget != null &&
        route.segments.isNotEmpty) {
      var spent = 0.0, back = 0.0, finalRequired = 0.0;
      for (var i = 0; i < route.segments.length; i++) {
        spent += energy.outboundWh[i];
        back += energy.returnWh[i] ?? 0;
        final endpoint = route.profile
            .where((p) => p.sample.segment == i && p.sample.fraction == 1)
            .last;
        final first = route.profile.first;
        final atHome =
            routeDistance(endpoint.sample.position, first.sample.position) <
                1 &&
            endpoint.altitude != null &&
            first.altitude != null &&
            (endpoint.altitude! - first.altitude!).abs() < 1;
        // At takeoff no return leg is needed. Otherwise use the entire retrace;
        // no unverified shortcut across terrain is invented.
        finalRequired = spent + (settings.includeReturn && !atHome ? back : 0);
        if (finalRequired * settings.conservativeFactor > budget) {
          critical.add(i);
        }
      }
      optimistic = finalRequired * settings.optimisticFactor;
      conservative = finalRequired * settings.conservativeFactor;
    }
    final status = !energy.available
        ? energy.problem!
        : settings.includeReturn && !energy.returnAvailable
        ? 'Return energy is unknown because the wind-corrected return track cannot be achieved.'
        : budget == null
        ? 'Capacity, nominal voltage or current charge is unknown.'
        : battery.availability != 'available'
        ? 'Pack availability is ${battery.availability}; confirm its condition before flight.'
        : conservative == null
        ? 'No assessable route segments.'
        : critical.isNotEmpty
        ? 'Conservative reserve is exceeded on the highlighted segments.'
        : 'Within the configured model budget. This is an estimate, not a flight guarantee.';
    return BatteryRouteAssessment._(
      battery: battery,
      availableWh: available,
      budgetWh: budget,
      optimisticWh: optimistic,
      conservativeWh: conservative,
      criticalSegments: Set.unmodifiable(critical),
      status: status,
    );
  }
}
