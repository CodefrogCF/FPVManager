import 'dart:math' as math;

/// Approximate *simulation* RF reference configurations, not measured link data.
/// CE reference powers are intentionally conservative. Receiver thresholds and
/// fade margins are assumptions (not manufacturer specifications).
class RfBandProfile {
  const RfBandProfile({
    required this.frequencyMhz,
    required this.eirpDbm,
    required this.receiverThresholdDbm,
    required this.fadeMarginDb,
  });
  final double frequencyMhz, eirpDbm, receiverThresholdDbm, fadeMarginDb;

  /// Ideal free-space distance at 0 dB of *assumed* link reserve. It is not
  /// a manufacturer range claim, a radio horizon or a safe flight distance.
  double get theoreticalFreeSpaceRangeMeters {
    validate();
    final allowedLossDb = eirpDbm - receiverThresholdDbm - fadeMarginDb;
    return 1000.0 *
        math
            .pow(
              10,
              (allowedLossDb -
                      32.44 -
                      20 * math.log(frequencyMhz) / math.ln10) /
                  20,
            )
            .toDouble();
  }

  void validate() {
    if (!frequencyMhz.isFinite ||
        frequencyMhz < 100 ||
        frequencyMhz > 8000 ||
        !eirpDbm.isFinite ||
        eirpDbm < -30 ||
        eirpDbm > 50 ||
        !receiverThresholdDbm.isFinite ||
        receiverThresholdDbm < -150 ||
        receiverThresholdDbm > -40 ||
        !fadeMarginDb.isFinite ||
        fadeMarginDb < 0 ||
        fadeMarginDb > 50) {
      throw ArgumentError('Invalid simulated RF reference profile');
    }
  }

  Map<String, double> toJson() {
    validate();
    return {
      'frequencyMhz': frequencyMhz,
      'eirpDbm': eirpDbm,
      'receiverThresholdDbm': receiverThresholdDbm,
      'fadeMarginDb': fadeMarginDb,
    };
  }
}

class RfProfileSettings {
  const RfProfileSettings({
    this.enabled = true,
    this.video = const RfBandProfile(
      frequencyMhz: 5800,
      eirpDbm: 14,
      receiverThresholdDbm: -105,
      fadeMarginDb: 12,
    ),
    this.control = const RfBandProfile(
      frequencyMhz: 868,
      eirpDbm: 14,
      receiverThresholdDbm: -120,
      fadeMarginDb: 10,
    ),
  });
  final bool enabled;
  final RfBandProfile video, control;
  void validate() {
    video.validate();
    control.validate();
  }

  Map<String, Object> toJson() {
    validate();
    return {
      'enabled': enabled,
      'video': video.toJson(),
      'control': control.toJson(),
    };
  }
}
