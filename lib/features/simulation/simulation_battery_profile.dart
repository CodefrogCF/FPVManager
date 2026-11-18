import '../../core/database/fpv_database.dart';

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
    this.hoverPowerWatts,
    this.cruisePowerWatts,
    this.cruiseSpeedMetersPerSecond,
    this.maxPowerWatts,
    this.maxSpeedMetersPerSecond,
    this.takeoffWeightGrams,
  });

  final int batteryId, cellCount, capacityMah;
  final String chemistry;
  final double chargePercent;
  final double? nominalVoltageVolts, energyWh;
  final double? hoverPowerWatts, cruisePowerWatts, cruiseSpeedMetersPerSecond;
  final double? maxPowerWatts, maxSpeedMetersPerSecond, takeoffWeightGrams;

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
    hoverPowerWatts: drone?.hoverPowerWatts,
    cruisePowerWatts: drone?.cruisePowerWatts,
    cruiseSpeedMetersPerSecond: drone?.cruiseSpeedMetersPerSecond,
    maxPowerWatts: drone?.maxPowerWatts,
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
    for (final value in [
      nominalVoltageVolts,
      energyWh,
      hoverPowerWatts,
      cruisePowerWatts,
      cruiseSpeedMetersPerSecond,
      maxPowerWatts,
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
      'hoverPowerWatts': hoverPowerWatts,
      'cruisePowerWatts': cruisePowerWatts,
      'cruiseSpeedMetersPerSecond': cruiseSpeedMetersPerSecond,
      'maxPowerWatts': maxPowerWatts,
      'maxSpeedMetersPerSecond': maxSpeedMetersPerSecond,
      'takeoffWeightGrams': takeoffWeightGrams,
    };
  }
}
