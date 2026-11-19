import 'dart:math' as math;

import '../../../core/database/fpv_database.dart' show Battery, Drone;
import '../../../core/models/propulsion_current_limits.dart';
import '../../../core/models/route_planning_settings.dart';
import '../../../core/models/battery_chemistry.dart';
import 'route_analysis.dart';

class RouteEnergyEstimate {
  RouteEnergyEstimate._(
    this.outboundWh,
    this.returnWh,
    this.problem, {
    this.estimatedWh = 0,
    this.estimatedSegments = 0,
    this.recordedDurationSegments = 0,
    this.powerCurveSource,
  });
  final List<double> outboundWh;
  final List<double?> returnWh;
  final String? problem;

  /// Outbound Wh from segments that depend on at least one estimated input.
  /// This is a contribution, not an uncertainty interval.
  final double estimatedWh;
  final int estimatedSegments, recordedDurationSegments;
  final String? powerCurveSource;
  double? get estimatedFraction =>
      totalWh == null || totalWh == 0 ? null : estimatedWh / totalWh!;
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
    double? droneCruiseSpeedMetersPerSecond,
    double? droneHoverPowerWatts,
    double? droneCruisePowerWatts,
  }) {
    settings.validate();
    final mass = settings.flightMassGrams ?? droneMassGrams;
    final reference =
        settings.referenceMassGrams ??
        (settings.estimateMissingTelemetry ? droneMassGrams : null);
    final canUseDroneCurve =
        settings.estimateMissingTelemetry &&
        droneCruiseSpeedMetersPerSecond != null &&
        droneCruiseSpeedMetersPerSecond.isFinite &&
        droneCruiseSpeedMetersPerSecond > 0 &&
        droneHoverPowerWatts != null &&
        droneHoverPowerWatts.isFinite &&
        droneHoverPowerWatts > 0 &&
        droneCruisePowerWatts != null &&
        droneCruisePowerWatts.isFinite &&
        droneCruisePowerWatts > 0;
    final curve = settings.powerCurve.length >= 2
        ? settings.powerCurve
        : canUseDroneCurve
        ? [
            PowerCurvePoint(0, droneHoverPowerWatts),
            PowerCurvePoint(
              droneCruiseSpeedMetersPerSecond,
              droneCruisePowerWatts,
            ),
          ]
        : const <PowerCurvePoint>[];
    final curveSource = settings.powerCurve.length >= 2
        ? settings.curveSource
        : canUseDroneCurve
        ? 'Drone profile (estimated hover/cruise power)'
        : null;
    RouteEnergyEstimate unavailable(String reason) =>
        RouteEnergyEstimate._(const [], const [], reason);
    if (mass == null || !mass.isFinite || mass <= 0 || reference == null) {
      return unavailable(
        'Enter total takeoff mass and the power curve reference mass. Include the installed battery.',
      );
    }
    if (curve.length < 2) {
      return unavailable(
        'Enter at least two speed/power measurements or estimates for level flight.',
      );
    }
    double? power(double speed) {
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
    var estimatedWh = 0.0, estimatedSegments = 0, recordedDurations = 0;
    for (final segment in route.segments) {
      if (segment.seconds == null ||
          segment.heightChange == null ||
          segment.speed == null) {
        return unavailable(
          'Known heights, outgoing airspeeds and an achievable wind-corrected outbound track are required.',
        );
      }
      final interpolatedWatts = power(segment.speed!);
      if (interpolatedWatts == null) {
        return unavailable(
          'Airspeed in segment ${segment.index + 1} lies outside the power curve. No extrapolation is applied.',
        );
      }
      // Opted-in speed estimates carry an extra power allowance. Compare
      // with the known cruise point (when inside the curve), so choosing a
      // slower conservative speed cannot silently lower the power estimate.
      final assumedCruise =
          droneCruiseSpeedMetersPerSecond ??
          curve.where((p) => p.speed > 0).firstOrNull?.speed;
      final referencePower = assumedCruise == null
          ? null
          : power(assumedCruise);
      final watts = segment.speedOrigin == RouteValueOrigin.estimated
          ? math.max(interpolatedWatts, referencePower ?? interpolatedWatts) *
                1.1
          : interpolatedWatts;
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
      if (segment.usesEstimation ||
          (canUseDroneCurve && settings.powerCurve.length < 2)) {
        estimatedWh += wh;
        estimatedSegments++;
      }
      if (segment.durationOrigin == RouteValueOrigin.simulated) {
        recordedDurations++;
      }
    }
    return RouteEnergyEstimate._(
      List.unmodifiable(outbound),
      List.unmodifiable(returning),
      null,
      estimatedWh: estimatedWh,
      estimatedSegments: estimatedSegments,
      recordedDurationSegments: recordedDurations,
      powerCurveSource: curveSource,
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
    required this.maxEstimatedCurrentAmps,
    required this.estimatedCurrentLimitAmps,
    required this.loadLimitedSegments,
    required this.escLimitedSegments,
    required this.motorLimitedSegments,
    required this.peakEstimatedPerUnitCurrentAmps,
  });
  final Battery battery;
  final double? availableWh, budgetWh, optimisticWh, conservativeWh;
  final Set<int> criticalSegments;
  final String status;

  /// Generic chemistry-based current estimate, NOT a manufacturer specification.
  final double? maxEstimatedCurrentAmps, estimatedCurrentLimitAmps;
  final Set<int> loadLimitedSegments;
  final Set<int> escLimitedSegments, motorLimitedSegments;

  /// DC current divided by the recorded motor count, not winding/ESC phase current.
  final double? peakEstimatedPerUnitCurrentAmps;
  bool get known =>
      budgetWh != null && optimisticWh != null && conservativeWh != null;

  /// Each pack is an alternative. Return follows the already planned path back
  /// to takeoff, using the outgoing speed of each segment in reverse direction.
  factory BatteryRouteAssessment.calculate(
    Battery battery,
    RouteAnalysis route,
    RouteEnergyEstimate energy,
    RoutePlanningSettings settings, {
    Drone? drone,
  }) {
    final propulsion = PropulsionCurrentLimits(
      motorCount: drone?.motorCount,
      escContinuousCurrentAmpsPerChannel:
          drone?.escContinuousCurrentAmpsPerChannel,
      motorContinuousCurrentAmpsPerMotor:
          drone?.motorContinuousCurrentAmpsPerMotor,
    );
    final chemistry = BatteryChemistryDefinition.lookup(battery.chemistry);
    final voltage =
        battery.nominalVoltageVolts ??
        (chemistry == null ? null : chemistry.nominalVolts * battery.cellCount);
    // Chemistry reference voltage can support approximate load diagnostics,
    // but must not turn an undocumented pack into a confirmed energy budget.
    // A usable capacity estimate requires recorded Wh or a user-specified
    // nominal pack voltage alongside capacity.
    final capacity =
        battery.energyWh ??
        (battery.nominalVoltageVolts == null
            ? null
            : battery.nominalVoltageVolts! * battery.capacityMah / 1000);
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
    final loadLimited = <int>{};
    final escLimited = <int>{}, motorLimited = <int>{};
    double? peakPerUnitCurrent;
    var burstTimeUsedSeconds = 0.0;
    double? maxEstimatedCurrent;
    final estimatedLimit = chemistry?.currentLimitAmps(
      battery.capacityMah.toDouble(),
      dischargeC: battery.continuousDischargeC,
    );
    double? optimistic, conservative;
    if (energy.available &&
        (!settings.includeReturn || energy.returnAvailable) &&
        budget != null &&
        route.segments.isNotEmpty) {
      var spent = 0.0, back = 0.0, finalRequired = 0.0;
      for (var i = 0; i < route.segments.length; i++) {
        // The same chemistry registry that drives the flight HUD also supplies
        // route-load estimates. Do not silently cap requested power or assume
        // that a generic C value is a manufacturer's continuous rating.
        if (chemistry != null &&
            voltage != null &&
            voltage.isFinite &&
            charge != null &&
            charge.isFinite &&
            route.segments[i].seconds != null &&
            route.segments[i].seconds! > 0 &&
            energy.outboundWh[i].isFinite) {
          final load = chemistry.estimateLoad(
            cells: battery.cellCount,
            capacityMah: battery.capacityMah.toDouble(),
            soc: charge / 100,
            requestedWatts:
                energy.outboundWh[i] * 3600 / route.segments[i].seconds!,
            dischargeC: battery.continuousDischargeC,
            resistanceOhmsPerCell:
                battery.internalResistanceMilliOhmsPerCell == null
                ? null
                : battery.internalResistanceMilliOhmsPerCell! / 1000,
            burstDischargeC: battery.burstDischargeC,
            burstDurationSeconds: battery.burstDurationSeconds,
            loadDurationSeconds:
                burstTimeUsedSeconds + route.segments[i].seconds!,
          );
          maxEstimatedCurrent = math.max(
            maxEstimatedCurrent ?? 0.0,
            load.currentAmps,
          );
          final drive = propulsion.assess(load.currentAmps);
          if (drive.estimatedPerUnitInputAmps case final share?) {
            peakPerUnitCurrent = math.max(peakPerUnitCurrent ?? 0, share);
          }
          if (drive.escPossiblyOverloaded == true) escLimited.add(i);
          if (drive.motorPossiblyOverloaded == true) motorLimited.add(i);
          if (load.currentAmps > load.currentLimitAmps) {
            burstTimeUsedSeconds += route.segments[i].seconds!;
          }
          if (load.exceedsReferenceCurrent) loadLimited.add(i);
        }
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
    final baseStatus = !energy.available
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
        : loadLimited.isNotEmpty
        ? 'Estimated chemistry reference current exceeded on some segments; verify the pack C rating and voltage sag.'
        : escLimited.isNotEmpty || motorLimited.isNotEmpty
        ? 'Possible ESC/motor current limitation: equal-share pack DC current is a proxy, not actual motor phase current.'
        : 'Within the configured model budget. This is an estimate, not a flight guarantee.';
    final status = battery.nominalVoltageVolts == null && chemistry != null
        ? '$baseStatus Chemistry reference voltage is used only for estimated load diagnostics; it does not confirm available energy.'
        : baseStatus;
    return BatteryRouteAssessment._(
      battery: battery,
      availableWh: available,
      budgetWh: budget,
      optimisticWh: optimistic,
      conservativeWh: conservative,
      criticalSegments: Set.unmodifiable(critical),
      status: status,
      maxEstimatedCurrentAmps: maxEstimatedCurrent,
      estimatedCurrentLimitAmps: estimatedLimit,
      loadLimitedSegments: Set.unmodifiable(loadLimited),
      escLimitedSegments: Set.unmodifiable(escLimited),
      motorLimitedSegments: Set.unmodifiable(motorLimited),
      peakEstimatedPerUnitCurrentAmps: peakPerUnitCurrent,
    );
  }
}
