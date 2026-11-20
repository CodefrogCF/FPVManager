import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_rotation_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('legacy model and existing Acro rates stay unchanged by default', () {
    const settings = SimulationSettings();
    final command = settings.toCommand();
    expect(command['physicsModel'], 'legacy');
    expect(command['acroRollRate'], 180);
    expect(command['acroPitchRate'], 180);
    expect(command['acroYawRate'], 180);
    expect(command['acroRateExpo'], 0);
    expect(command['rotation']['rateProfile'], 'betaflight');
    expect(command['rotation']['rollInertiaKgM2'], .018);
    expect(command['rotation']['yawTorqueNm'], .45);
    expect(command['rotation']['airModeEnabled'], isTrue);
    expect(command['rotation']['airModeIdleCommand'], .14);
  });

  test(
    'advanced rotational profile is retained when camera settings change',
    () {
      const selected = SimulationSettings(
        flightMode: SimulationFlightMode.acro,
        physicsModel: SimulationPhysicsModel.advanced,
        acroRollRate: 1000,
        acroRateExpo: .35,
        rotation: SimulationRotationSettings(
          rateProfile: SimulationRateProfile.legacyExpo,
          rollInertiaKgM2: .09,
          pitchTorqueNm: .6,
          yawAccelerationLimitDegs2: 1500,
          controllerGainPerSecond: 20,
          motorResponseTimeConstantSeconds: .08,
          airModeEnabled: false,
          airModeIdleCommand: .09,
        ),
      );
      final modified = selected.withCameraTilt(30, cameraFovDegrees: 120);
      expect(modified.rotation.rateProfile, SimulationRateProfile.legacyExpo);
      expect(modified.rotation.rollInertiaKgM2, .09);
      expect(modified.rotation.pitchTorqueNm, .6);
      expect(modified.acroRollRate, 1000);
      expect(modified.acroRateExpo, .35);
      expect(
        modified.toCommand()['rotation']['yawAccelerationLimitDegs2'],
        1500,
      );
      expect(
        modified.toCommand()['rotation']['motorResponseTimeConstantSeconds'],
        .08,
      );
      expect(modified.toCommand()['rotation']['airModeEnabled'], isFalse);
      expect(modified.toCommand()['rotation']['airModeIdleCommand'], .09);
    },
  );

  test(
    'all rotational parameters validate before sending JavaScript payload',
    () {
      for (final invalid in [
        const SimulationRotationSettings(rollInertiaKgM2: 0),
        const SimulationRotationSettings(pitchInertiaKgM2: double.nan),
        const SimulationRotationSettings(yawInertiaKgM2: -1),
        const SimulationRotationSettings(rollTorqueNm: double.infinity),
        const SimulationRotationSettings(pitchTorqueNm: -1),
        const SimulationRotationSettings(yawTorqueNm: 21),
        const SimulationRotationSettings(rollAccelerationLimitDegs2: 0),
        const SimulationRotationSettings(pitchAccelerationLimitDegs2: 20001),
        const SimulationRotationSettings(yawAccelerationLimitDegs2: -5),
        const SimulationRotationSettings(controllerGainPerSecond: 0),
        const SimulationRotationSettings(motorResponseTimeConstantSeconds: .6),
        const SimulationRotationSettings(passiveDampingPerSecond: -1),
        const SimulationRotationSettings(superRate: 1),
        const SimulationRotationSettings(airModeIdleCommand: .01),
        const SimulationRotationSettings(airModeIdleCommand: .31),
      ]) {
        expect(
          () => SimulationSettings(rotation: invalid).toCommand(),
          throwsArgumentError,
        );
      }
    },
  );
}
