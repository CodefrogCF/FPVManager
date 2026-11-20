import '../../core/database/fpv_database.dart';

/// Optional hardware input for the advanced, estimated motor/propeller model.
/// This describes the selected aircraft, not the selected battery.
class SimulationPropulsionProfile {
  const SimulationPropulsionProfile({
    this.motorKv,
    this.motorCount,
    this.propellerDiameterInches,
    this.propellerPitchInches,
    this.propellerDescription,
    this.takeoffWeightGrams,
    this.referenceVoltageVolts,
    this.maxPowerWatts,
    this.escContinuousCurrentAmpsPerChannel,
    this.motorContinuousCurrentAmpsPerMotor,
    this.bladeCount,
    this.rpmEfficiency,
    this.propellerEfficiency,
    this.motorTimeConstantSeconds,
    this.manufacturerCurve,
  });

  factory SimulationPropulsionProfile.fromDrone(Drone drone) =>
      SimulationPropulsionProfile(
        motorKv: drone.motorKv,
        motorCount: drone.motorCount ?? drone.propellerCount,
        propellerDiameterInches: drone.propellerDiameterInches,
        propellerPitchInches: drone.propellerPitchInches,
        propellerDescription: drone.propellerDescription,
        takeoffWeightGrams: drone.takeoffWeightGrams,
        referenceVoltageVolts: drone.referenceVoltageVolts,
        maxPowerWatts: drone.maxPowerWatts,
        escContinuousCurrentAmpsPerChannel:
            drone.escContinuousCurrentAmpsPerChannel,
        motorContinuousCurrentAmpsPerMotor:
            drone.motorContinuousCurrentAmpsPerMotor,
      );

  final double? motorKv,
      propellerDiameterInches,
      propellerPitchInches,
      takeoffWeightGrams,
      referenceVoltageVolts,
      maxPowerWatts,
      escContinuousCurrentAmpsPerChannel,
      motorContinuousCurrentAmpsPerMotor,
      rpmEfficiency,
      propellerEfficiency,
      motorTimeConstantSeconds;
  final int? motorCount, bladeCount;
  final String? propellerDescription;

  /// Optional, independently supplied manufacturer measurements. Not populated
  /// automatically from unverified manufacturer names.
  final List<Map<String, num>>? manufacturerCurve;

  Map<String, Object?> toJson() => {
    'motorKv': motorKv,
    'motorCount': motorCount,
    'propellerDiameterInches': propellerDiameterInches,
    'propellerPitchInches': propellerPitchInches,
    'propellerDescription': propellerDescription,
    'takeoffWeightGrams': takeoffWeightGrams,
    'referenceVoltageVolts': referenceVoltageVolts,
    'maxPowerWatts': maxPowerWatts,
    'escContinuousCurrentAmpsPerChannel': escContinuousCurrentAmpsPerChannel,
    'motorContinuousCurrentAmpsPerMotor': motorContinuousCurrentAmpsPerMotor,
    'bladeCount': bladeCount,
    'rpmEfficiency': rpmEfficiency,
    'propellerEfficiency': propellerEfficiency,
    'motorTimeConstantSeconds': motorTimeConstantSeconds,
    'manufacturerCurve': manufacturerCurve,
  };
}
