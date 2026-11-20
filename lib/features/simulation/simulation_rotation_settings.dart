/// Simplified Acro rate shaping and body-axis attitude response for the
/// optional advanced simulation. Coefficients are illustrative estimates,
/// not identified mass properties or Betaflight firmware coefficients.
enum SimulationRateProfile { betaflight, legacyExpo, linear }

class SimulationRotationSettings {
  const SimulationRotationSettings({
    this.rateProfile = SimulationRateProfile.betaflight,
    this.superRate = .55,
    this.rollInertiaKgM2 = .018,
    this.pitchInertiaKgM2 = .021,
    this.yawInertiaKgM2 = .03,
    this.rollTorqueNm = 1,
    this.pitchTorqueNm = 1,
    this.yawTorqueNm = .45,
    this.rollAccelerationLimitDegs2 = 4000,
    this.pitchAccelerationLimitDegs2 = 4000,
    this.yawAccelerationLimitDegs2 = 2200,
    this.controllerGainPerSecond = 16,
    this.motorResponseTimeConstantSeconds = .035,
    this.passiveDampingPerSecond = .15,
  });

  final SimulationRateProfile rateProfile;
  final double superRate;
  final double rollInertiaKgM2, pitchInertiaKgM2, yawInertiaKgM2;
  final double rollTorqueNm, pitchTorqueNm, yawTorqueNm;
  final double rollAccelerationLimitDegs2;
  final double pitchAccelerationLimitDegs2;
  final double yawAccelerationLimitDegs2;
  final double controllerGainPerSecond, motorResponseTimeConstantSeconds;
  final double passiveDampingPerSecond;

  void validate() {
    for (final (value, min, max) in [
      (superRate, 0.0, .95),
      (rollInertiaKgM2, .0001, 5.0),
      (pitchInertiaKgM2, .0001, 5.0),
      (yawInertiaKgM2, .0001, 5.0),
      (rollTorqueNm, .0001, 20.0),
      (pitchTorqueNm, .0001, 20.0),
      (yawTorqueNm, .0001, 20.0),
      (rollAccelerationLimitDegs2, 10.0, 20000.0),
      (pitchAccelerationLimitDegs2, 10.0, 20000.0),
      (yawAccelerationLimitDegs2, 10.0, 20000.0),
      (controllerGainPerSecond, .1, 100.0),
      (motorResponseTimeConstantSeconds, 0.0, .5),
      (passiveDampingPerSecond, 0.0, 5.0),
    ]) {
      if (!value.isFinite || value < min || value > max) {
        throw ArgumentError('Invalid advanced rotational dynamics parameter');
      }
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'rateProfile': rateProfile.name,
      'superRate': superRate,
      'rollInertiaKgM2': rollInertiaKgM2,
      'pitchInertiaKgM2': pitchInertiaKgM2,
      'yawInertiaKgM2': yawInertiaKgM2,
      'rollTorqueNm': rollTorqueNm,
      'pitchTorqueNm': pitchTorqueNm,
      'yawTorqueNm': yawTorqueNm,
      'rollAccelerationLimitDegs2': rollAccelerationLimitDegs2,
      'pitchAccelerationLimitDegs2': pitchAccelerationLimitDegs2,
      'yawAccelerationLimitDegs2': yawAccelerationLimitDegs2,
      'controllerGainPerSecond': controllerGainPerSecond,
      'motorResponseTimeConstantSeconds': motorResponseTimeConstantSeconds,
      'passiveDampingPerSecond': passiveDampingPerSecond,
    };
  }
}
