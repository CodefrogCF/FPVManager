import 'dart:math' as math;

import '../../core/database/fpv_database.dart';
import 'rf_profile_settings.dart';

/// Copies explicitly recorded transmitter parameters into a SIM RF scenario.
/// Stored maxPowerMw is *maximum conducted output*, not necessarily active
/// output or EIRP. Antenna gain/loss is applied only when supplied.
/// Receiver sensitivity is also optional; no hardware properties are invented.
RfBandProfile rfBandFromEquipment(
  RadioEquipmentData equipment, {
  required RfBandProfile fallback,
}) {
  final mw = equipment.maxPowerMw;
  final powerDbm = mw != null && mw > 0 && mw.isFinite
      ? 10 * math.log(mw) / math.ln10
      : null;
  final result = RfBandProfile(
    frequencyMhz: equipment.frequencyMhz ?? fallback.frequencyMhz,
    eirpDbm: powerDbm == null
        ? fallback.eirpDbm
        : powerDbm + (equipment.txGainDbi ?? 0) - (equipment.txLossDb ?? 0),
    receiverThresholdDbm: equipment.sensitivityDbm == null
        ? fallback.receiverThresholdDbm
        : equipment.sensitivityDbm! -
              (equipment.rxGainDbi ?? 0) +
              (equipment.rxLossDb ?? 0),
    fadeMarginDb: fallback.fadeMarginDb,
  );
  result.validate();
  return result;
}
