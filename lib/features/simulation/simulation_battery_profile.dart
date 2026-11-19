import '../../core/database/fpv_database.dart';
import '../../core/models/battery_chemistry.dart';

/// Snapshot for a local, simulated battery estimate. Never real telemetry.
/// Unknown power is kept unknown so the HUD does not invent voltage readings.
class SimulationBatteryProfile {
  const SimulationBatteryProfile({
    required this.batteryId,
    required this.cellCount,
    required this.capacityMah,
    required this.chemistry,
    required this.chargePercent,
    this.nominalVoltageVolts,
    this.energyWh,
    this.continuousDischargeC,
    this.burstDischargeC,
    this.burstDurationSeconds,
    this.internalResistanceMilliOhmsPerCell,
    this.hoverPowerWatts,
    this.cruisePowerWatts,
    this.cruiseSpeedMetersPerSecond,
    this.maxPowerWatts,
    this.motorCount,
    this.escContinuousCurrentAmpsPerChannel,
    this.motorContinuousCurrentAmpsPerMotor,
    this.maxSpeedMetersPerSecond,
    this.takeoffWeightGrams,
  });

  final int batteryId, cellCount, capacityMah;
  final String chemistry;
  BatteryChemistryDefinition? get chemistryModel =>
      BatteryChemistryDefinition.lookup(chemistry);
  final double chargePercent;
  final double? nominalVoltageVolts, energyWh;
  final double? continuousDischargeC, burstDischargeC, burstDurationSeconds;
  final double? internalResistanceMilliOhmsPerCell;
  final double? hoverPowerWatts, cruisePowerWatts, cruiseSpeedMetersPerSecond;
  final double? maxPowerWatts, maxSpeedMetersPerSecond, takeoffWeightGrams;
  final int? motorCount;
  final double? escContinuousCurrentAmpsPerChannel,
      motorContinuousCurrentAmpsPerMotor;

  factory SimulationBatteryProfile.fromProfiles({
    required Battery battery,
    Drone? drone,
    required double chargePercent,
  }) => SimulationBatteryProfile(
    batteryId: battery.id,
    cellCount: battery.cellCount,
    capacityMah: battery.capacityMah,
    chemistry: battery.chemistry,
    chargePercent: chargePercent,
    nominalVoltageVolts: battery.nominalVoltageVolts,
    energyWh: battery.energyWh,
    continuousDischargeC: battery.continuousDischargeC,
    burstDischargeC: battery.burstDischargeC,
    burstDurationSeconds: battery.burstDurationSeconds,
    internalResistanceMilliOhmsPerCell:
        battery.internalResistanceMilliOhmsPerCell,
    hoverPowerWatts: drone?.hoverPowerWatts,
    cruisePowerWatts: drone?.cruisePowerWatts,
    cruiseSpeedMetersPerSecond: drone?.cruiseSpeedMetersPerSecond,
    maxPowerWatts: drone?.maxPowerWatts,
    motorCount: drone?.motorCount,
    escContinuousCurrentAmpsPerChannel:
        drone?.escContinuousCurrentAmpsPerChannel,
    motorContinuousCurrentAmpsPerMotor:
        drone?.motorContinuousCurrentAmpsPerMotor,
    maxSpeedMetersPerSecond: drone?.maxSpeedMetersPerSecond,
    takeoffWeightGrams: drone?.takeoffWeightGrams,
  );

  void validate() {
    if (batteryId <= 0 ||
        cellCount < 1 ||
        capacityMah < 1 ||
        !chargePercent.isFinite ||
        chargePercent < 0 ||
        chargePercent > 100) {
      throw ArgumentError('Invalid simulated battery specification');
    }
    if (motorCount != null && (motorCount! < 1 || motorCount! > 32)) {
      throw ArgumentError('Invalid number of motors');
    }
    for (final value in [
      nominalVoltageVolts,
      energyWh,
      continuousDischargeC,
      burstDischargeC,
      burstDurationSeconds,
      hoverPowerWatts,
      cruisePowerWatts,
      cruiseSpeedMetersPerSecond,
      maxPowerWatts,
      escContinuousCurrentAmpsPerChannel,
      motorContinuousCurrentAmpsPerMotor,
      maxSpeedMetersPerSecond,
      takeoffWeightGrams,
    ]) {
      if (value != null && (!value.isFinite || value <= 0)) {
        throw ArgumentError('Invalid simulated battery or drone parameter');
      }
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'batteryId': batteryId,
      'cellCount': cellCount,
      'capacityMah': capacityMah,
      'chemistry': chemistry,
      'chargePercent': chargePercent,
      'nominalVoltageVolts': nominalVoltageVolts,
      'energyWh': energyWh,
      'continuousDischargeC': continuousDischargeC,
      'burstDischargeC': burstDischargeC,
      'burstDurationSeconds': burstDurationSeconds,
      'resistanceOhmsPerCell': internalResistanceMilliOhmsPerCell == null
          ? null
          : internalResistanceMilliOhmsPerCell! / 1000,
      'hoverPowerWatts': hoverPowerWatts,
      'cruisePowerWatts': cruisePowerWatts,
      'cruiseSpeedMetersPerSecond': cruiseSpeedMetersPerSecond,
      'maxPowerWatts': maxPowerWatts,
      'motorCount': motorCount,
      'escContinuousCurrentAmpsPerChannel': escContinuousCurrentAmpsPerChannel,
      'motorContinuousCurrentAmpsPerMotor': motorContinuousCurrentAmpsPerMotor,
      'maxSpeedMetersPerSecond': maxSpeedMetersPerSecond,
      'takeoffWeightGrams': takeoffWeightGrams,
    };
  }
}
