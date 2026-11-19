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

/// Regulatory modes here describe simulations only, not a hardware configuration.
/// 'custom' means that the user supplied independent RF properties.
enum RfScenario { eu, fcc, custom }

/// Reference scenarios for DJI O4 Air Unit Pro and TBS Crossfire.
/// The effective receiver thresholds are NOT hardware sensitivity specifications.
/// O4 thresholds are *illustrative calibrations* against DJI's ideal clear-air
/// 8 km CE / 15 km FCC reference ranges. Crossfire figures are generic assumptions.
abstract final class RfReferencePresets {
  static const videoEu = RfBandProfile(
    frequencyMhz: 5800,
    eirpDbm: 13.9,
    receiverThresholdDbm: -124,
    fadeMarginDb: 12,
  );
  static const videoFcc = RfBandProfile(
    frequencyMhz: 5800,
    eirpDbm: 32.9,
    receiverThresholdDbm: -110.3,
    fadeMarginDb: 12,
  );
  static const controlEu = RfBandProfile(
    frequencyMhz: 868,
    eirpDbm: 14,
    receiverThresholdDbm: -120,
    fadeMarginDb: 10,
  );
  // An illustrative 250 mW Crossfire scenario, NOT a universal FCC max.
  static const controlFcc = RfBandProfile(
    frequencyMhz: 915,
    eirpDbm: 24,
    receiverThresholdDbm: -120,
    fadeMarginDb: 10,
  );

  static RfBandProfile video(RfScenario region) => switch (region) {
    RfScenario.eu => videoEu,
    RfScenario.fcc => videoFcc,
    RfScenario.custom => throw ArgumentError(
      'Custom video settings have no preset',
    ),
  };
  static RfBandProfile control(RfScenario region) => switch (region) {
    RfScenario.eu => controlEu,
    RfScenario.fcc => controlFcc,
    RfScenario.custom => throw ArgumentError(
      'Custom control settings have no preset',
    ),
  };
}

class RfProfileSettings {
  const RfProfileSettings({
    this.enabled = true,
    this.videoScenario = RfScenario.eu,
    this.controlScenario = RfScenario.eu,
    this.video = RfReferencePresets.videoEu,
    this.control = RfReferencePresets.controlEu,
  });
  final bool enabled;
  final RfScenario videoScenario, controlScenario;
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
      'videoScenario': videoScenario.name,
      'controlScenario': controlScenario.name,
    };
  }
}
