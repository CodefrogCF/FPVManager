import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/simulation/simulation_battery_profile.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  final battery = Battery(
    id: 7,
    name: '6S LiPo',
    chemistry: 'LiPo',
    cellCount: 6,
    capacityMah: 4500,
    isType: false,
    availability: 'available',
    nominalVoltageVolts: 22.2,
    chargePercent: 90,
  );
  final drone = Drone(
    id: 4,
    name: '7-inch quad',
    type: 'quadcopter',
    createdAt: DateTime.utc(2026),
    takeoffWeightGrams: 1320,
    hoverPowerWatts: 180,
    cruisePowerWatts: 290,
    maxPowerWatts: 1100,
    cruiseSpeedMetersPerSecond: 17,
    maxSpeedMetersPerSecond: 45,
  );

  test('battery and drone profiles serialize as an estimated snapshot', () {
    final profile = SimulationBatteryProfile.fromProfiles(
      battery: battery,
      drone: drone,
      chargePercent: 85,
    );
    final settings = SimulationSettings(
      batteryProfile: profile,
      showBatteryVoltage: true,
      showBatteryCellVoltage: true,
      lowBatteryCellVoltage: 3.55,
      criticalBatteryCellVoltage: 3.3,
      batterySagResistanceOhmsPerCell: .02,
    );
    final command = settings.toCommand();
    final json = command['batteryProfile'] as Map<String, Object?>;
    expect(json['batteryId'], 7);
    expect(json['cellCount'], 6);
    expect(json['capacityMah'], 4500);
    expect(json['chargePercent'], 85);
    expect(json['hoverPowerWatts'], 180);
    expect(json['cruisePowerWatts'], 290);
    expect(json['cruiseSpeedMetersPerSecond'], 17);
    expect(json['takeoffWeightGrams'], 1320);
    expect(command['showBatteryVoltage'], true);
    expect(command['showBatteryCellVoltage'], true);
    expect(command['criticalBatteryCellVoltage'], 3.3);
    final updated = settings.withCameraTilt(
      10,
      showBatteryVoltage: false,
      lowBatteryCellVoltage: 3.6,
    );
    expect(updated.batteryProfile, same(profile));
    expect(updated.showBatteryVoltage, false);
    expect(updated.lowBatteryCellVoltage, 3.6);
    expect(updated.criticalBatteryCellVoltage, 3.3);
  });

  test('invalid thresholds and battery inputs are rejected', () {
    for (final settings in [
      const SimulationSettings(
        lowBatteryCellVoltage: 3.1,
        criticalBatteryCellVoltage: 3.3,
      ),
      const SimulationSettings(lowBatteryCellVoltage: double.nan),
      const SimulationSettings(batterySagResistanceOhmsPerCell: -.1),
      const SimulationSettings(batterySagResistanceOhmsPerCell: .11),
    ]) {
      expect(settings.validate, throwsArgumentError);
    }
    for (final charge in [-1.0, 101.0, double.infinity]) {
      final profile = SimulationBatteryProfile.fromProfiles(
        battery: battery,
        drone: drone,
        chargePercent: charge,
      );
      expect(profile.validate, throwsArgumentError);
    }
  });

  test('unknown drone parameters remain unknown and HUD is off by default', () {
    final profile = SimulationBatteryProfile.fromProfiles(
      battery: battery,
      chargePercent: 100,
    );
    expect(profile.toJson()['hoverPowerWatts'], isNull);
    expect(profile.toJson()['cruisePowerWatts'], isNull);
    expect(const SimulationSettings().toCommand()['batteryProfile'], isNull);
    expect(const SimulationSettings().toCommand()['showBatteryVoltage'], false);
    expect(
      const SimulationSettings().toCommand()['showBatteryCellVoltage'],
      false,
    );
  });
}
