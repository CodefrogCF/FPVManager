import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/simulation/simulation_propulsion_profile.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test(
    'motor and propeller specifications are serialized separately from battery',
    () {
      final drone = Drone(
        id: 11,
        name: '7-inch reference',
        type: 'quadcopter',
        createdAt: DateTime.utc(2026, 11, 20),
        motorKv: 1750,
        motorCount: 4,
        propellerCount: 4,
        propellerDiameterInches: 7,
        propellerPitchInches: 3.5,
        propellerDescription: 'HQProp 7x3.5x3V1S',
        takeoffWeightGrams: 1320,
        referenceVoltageVolts: 22.2,
        maxPowerWatts: 2200,
        escContinuousCurrentAmpsPerChannel: 60,
      );
      final settings = SimulationSettings.fromDrone(drone);
      expect(settings.physicsModel, SimulationPhysicsModel.advanced);
      final profile = settings.toCommand()['propulsionProfile'] as Map;
      expect(profile['motorKv'], 1750);
      expect(profile['motorCount'], 4);
      expect(profile['propellerDiameterInches'], 7);
      expect(profile['propellerPitchInches'], 3.5);
      expect(profile['propellerDescription'], 'HQProp 7x3.5x3V1S');
      expect(profile['takeoffWeightGrams'], 1320);
      expect(profile['escContinuousCurrentAmpsPerChannel'], 60);
      expect(settings.toCommand()['batteryProfile'], isNull);
      final changed = settings.withCameraTilt(
        35,
        physicsModel: SimulationPhysicsModel.advanced,
      );
      expect(changed.toCommand()['propulsionProfile'], profile);
    },
  );

  test('missing manufacturer fields remain unknown, not fabricated', () {
    const profile = SimulationPropulsionProfile(motorKv: 1200);
    final command = const SimulationSettings(
      physicsModel: SimulationPhysicsModel.advanced,
      propulsionProfile: profile,
    ).toCommand();
    final serialized = command['propulsionProfile'] as Map;
    expect(serialized['motorKv'], 1200);
    expect(serialized['motorCount'], isNull);
    expect(serialized['propellerPitchInches'], isNull);
    expect(serialized['manufacturerCurve'], isNull);
  });

  test('propeller count is only used as motor-count fallback', () {
    final drone = Drone(
      id: 3,
      name: 'Legacy',
      type: 'quadcopter',
      createdAt: DateTime.utc(2026, 11, 20),
      propellerCount: 4,
    );
    final profile = SimulationPropulsionProfile.fromDrone(drone).toJson();
    expect(profile['motorCount'], 4);
    expect(profile['bladeCount'], isNull);
  });
}
