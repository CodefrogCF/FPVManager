/// Diagnostic comparison only: pack DC current divided equally by motor count.
/// ESC phase and motor winding currents cannot be inferred from this alone.
/// No power or motor output clipping is applied based on this approximation.
class PropulsionCurrentLimits {
  const PropulsionCurrentLimits({
    this.motorCount,
    this.escContinuousCurrentAmpsPerChannel,
    this.motorContinuousCurrentAmpsPerMotor,
  });

  final int? motorCount;
  final double? escContinuousCurrentAmpsPerChannel;
  final double? motorContinuousCurrentAmpsPerMotor;

  PropulsionLoadAssessment assess(double? packCurrentAmps) {
    final count = motorCount;
    if (count == null ||
        count <= 0 ||
        packCurrentAmps == null ||
        !packCurrentAmps.isFinite ||
        packCurrentAmps < 0) {
      return const PropulsionLoadAssessment(estimatedPerUnitInputAmps: null);
    }
    final estimate = packCurrentAmps / count;
    bool? exceeds(double? limit) =>
        limit != null && limit.isFinite && limit > 0 ? estimate > limit : null;
    return PropulsionLoadAssessment(
      estimatedPerUnitInputAmps: estimate,
      escPossiblyOverloaded: exceeds(escContinuousCurrentAmpsPerChannel),
      motorPossiblyOverloaded: exceeds(motorContinuousCurrentAmpsPerMotor),
    );
  }
}

class PropulsionLoadAssessment {
  const PropulsionLoadAssessment({
    required this.estimatedPerUnitInputAmps,
    this.escPossiblyOverloaded,
    this.motorPossiblyOverloaded,
  });

  /// Equal-share DC proxy, never measured ESC phase or motor winding current.
  final double? estimatedPerUnitInputAmps;
  final bool? escPossiblyOverloaded;
  final bool? motorPossiblyOverloaded;
}
