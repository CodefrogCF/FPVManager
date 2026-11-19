import 'dart:math' as math;

import 'generated/battery_chemistries.g.dart';

/// Approximate, temperature-neutral RC battery characteristics.
/// Definitions are generated from assets/battery/chemistries.json for Dart and JS.
class BatteryCurvePoint {
  const BatteryCurvePoint(this.soc, this.volts);
  final double soc, volts;
}

class BatteryChemistryDefinition {
  const BatteryChemistryDefinition({
    required this.id,
    required this.label,
    required this.aliases,
    required this.nominalVolts,
    required this.chargeMethod,
    required this.maxChargeVoltsPerCell,
    required this.lowVolts,
    required this.criticalVolts,
    required this.resistanceOhmsAt1Ah,
    required this.referenceContinuousC,
    required this.curve,
  });

  final String id, label;

  /// Lithium: CC/CV with a voltage ceiling. Nickel: delta-peak/temperature;
  /// a voltage-only cutoff is deliberately unavailable.
  final String chargeMethod;
  final double? maxChargeVoltsPerCell;
  bool get requiresPeakChargeDetection =>
      chargeMethod == 'delta_peak_temperature';
  final List<String> aliases;
  final double nominalVolts, lowVolts, criticalVolts;

  /// Illustrative resistance of one series cell at a 1 Ah pack-equivalent.
  /// Parallel cell count, temperature and ageing are not modeled.
  final double resistanceOhmsAt1Ah;

  /// Conservative generic reference; never a manufacturer C rating.
  final double referenceContinuousC;
  final List<BatteryCurvePoint> curve;

  static String _normalize(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static BatteryChemistryDefinition? lookup(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = _normalize(raw);
    for (final definition in batteryChemistryPresets) {
      if (_normalize(definition.id) == key ||
          definition.aliases.any((alias) => _normalize(alias) == key)) {
        return definition;
      }
    }
    return null; // Existing unrecognized database values remain untouched.
  }

  double openCircuitVolts(double soc) {
    final fraction = soc.clamp(0.0, 1.0).toDouble();
    for (var i = 1; i < curve.length; i++) {
      final a = curve[i - 1], b = curve[i];
      if (fraction <= b.soc) {
        return a.volts +
            (b.volts - a.volts) * (fraction - a.soc) / (b.soc - a.soc);
      }
    }
    return curve.last.volts;
  }

  double currentLimitAmps(double capacityMah, {double? dischargeC}) {
    if (!capacityMah.isFinite || capacityMah <= 0) return double.nan;
    final rating = dischargeC != null && dischargeC.isFinite && dischargeC > 0
        ? dischargeC
        : referenceContinuousC;
    return rating * capacityMah / 1000;
  }

  double resistanceOhmsPerCell(double capacityMah, {double? overrideOhms}) {
    if (overrideOhms != null && overrideOhms.isFinite && overrideOhms >= 0) {
      return overrideOhms;
    }
    return resistanceOhmsAt1Ah / math.max(0.001, capacityMah / 1000);
  }

  BatteryLoadEstimate estimateLoad({
    required int cells,
    required double capacityMah,
    required double soc,
    required double requestedWatts,
    double? dischargeC,
    double? resistanceOhmsPerCell,
    double? burstDischargeC,
    double? burstDurationSeconds,
    double? loadDurationSeconds,
  }) {
    if (cells <= 0 ||
        !capacityMah.isFinite ||
        capacityMah <= 0 ||
        !soc.isFinite ||
        !requestedWatts.isFinite ||
        requestedWatts < 0) {
      throw ArgumentError('Invalid battery load parameters');
    }
    final openPack = cells * openCircuitVolts(soc);
    final resistance =
        cells *
        this.resistanceOhmsPerCell(
          capacityMah,
          overrideOhms: resistanceOhmsPerCell,
        );
    final maxCurrent = currentLimitAmps(capacityMah, dischargeC: dischargeC);
    // Solve P = I * (Voc - I * R). If no real solution exists,
    // use the peak of the simplified equivalent circuit and flag overload.
    final discriminant = openPack * openPack - 4 * resistance * requestedWatts;
    final current = requestedWatts == 0
        ? 0.0
        : resistance == 0
        ? requestedWatts / openPack
        : discriminant <= 0
        ? openPack / (2 * resistance)
        : 2 * requestedWatts / (openPack + math.sqrt(discriminant));
    final burstAmps = burstDischargeC == null
        ? null
        : currentLimitAmps(capacityMah, dischargeC: burstDischargeC);
    final withinBurst =
        burstAmps != null &&
        burstDurationSeconds != null &&
        loadDurationSeconds != null &&
        loadDurationSeconds > 0 &&
        burstDurationSeconds > 0 &&
        loadDurationSeconds <= burstDurationSeconds &&
        current <= burstAmps;
    return BatteryLoadEstimate(
      currentAmps: current,
      packVolts: math.max(
        cells * (curve.first.volts - .3),
        openPack - current * resistance,
      ),
      currentLimitAmps: maxCurrent,
      exceedsReferenceCurrent:
          (current > maxCurrent && !withinBurst) || discriminant < 0,
    );
  }
}

class BatteryLoadEstimate {
  const BatteryLoadEstimate({
    required this.currentAmps,
    required this.packVolts,
    required this.currentLimitAmps,
    required this.exceedsReferenceCurrent,
  });
  final double currentAmps, packVolts, currentLimitAmps;
  final bool exceedsReferenceCurrent;
}
