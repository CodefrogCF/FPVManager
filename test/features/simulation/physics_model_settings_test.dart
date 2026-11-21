import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('advanced is the new default with explicit legacy fallback', () {
    const original = SimulationSettings();
    final payload = original.toCommand();
    expect(original.physicsModel, SimulationPhysicsModel.advanced);
    expect(original.physicsStepHz, 120);
    expect(payload['physicsModel'], 'advanced');
    expect(payload['physicsStepHz'], 120);
    const legacy = SimulationSettings(
      physicsModel: SimulationPhysicsModel.legacy,
    );
    expect(legacy.toCommand()['physicsModel'], 'legacy');
    expect(
      legacy.withCameraTilt(15).physicsModel,
      SimulationPhysicsModel.legacy,
    );
  });

  test('advanced selection and physics frequency survive settings changes', () {
    const advanced = SimulationSettings(
      flightMode: SimulationFlightMode.acro,
      physicsModel: SimulationPhysicsModel.advanced,
      physicsStepHz: 240,
      acroRollRate: 720,
    );
    final adjusted = advanced.withCameraTilt(30);
    expect(adjusted.physicsModel, SimulationPhysicsModel.advanced);
    expect(adjusted.physicsStepHz, 240);
    expect(adjusted.acroRollRate, 720);
    expect(adjusted.toCommand()['physicsModel'], 'advanced');
    expect(adjusted.toCommand()['physicsStepHz'], 240);
    expect(adjusted.toCommand()['flightMode'], 'acro');
  });

  test(
    'invalid physics frequency is rejected without altering flight profiles',
    () {
      for (final invalid in [-1, 0, 30, 100, 1000]) {
        expect(
          () => SimulationSettings(
            physicsModel: SimulationPhysicsModel.advanced,
            physicsStepHz: invalid,
          ).validate(),
          throwsArgumentError,
        );
      }
    },
  );
}
