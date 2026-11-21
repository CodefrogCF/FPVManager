import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_descent_aerodynamics_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('all new effects default off and legacy settings stay compatible', () {
    const settings = SimulationSettings();
    final command = settings.toCommand();
    expect(command['physicsModel'], 'advanced');
    final effects = command['descentAerodynamics'] as Map<String, dynamic>;
    expect(effects['groundEffectEnabled'], isFalse);
    expect(effects['propwashEnabled'], isFalse);
    expect(effects['vortexRingEnabled'], isFalse);
    expect(effects['rotorDiameterMeters'], .1778);
  });

  test('advanced effect switches and intensity persist in command and camera update', () {
    const settings = SimulationSettings(
      physicsModel: SimulationPhysicsModel.advanced,
      flightMode: SimulationFlightMode.acro,
      descentAerodynamics: SimulationDescentAerodynamicsSettings(
        groundEffectEnabled: true,
        propwashEnabled: true,
        vortexRingEnabled: true,
        groundEffectIntensity: .75,
        propwashIntensity: .5,
        vortexRingIntensity: 1.2,
        rotorDiameterMeters: .254,
      ),
    );
    final changed = settings.withCameraTilt(35);
    expect(changed.descentAerodynamics.groundEffectEnabled, isTrue);
    expect(changed.descentAerodynamics.propwashEnabled, isTrue);
    expect(changed.descentAerodynamics.vortexRingEnabled, isTrue);
    final payload = changed.toCommand()['descentAerodynamics'] as Map;
    expect(payload['groundEffectIntensity'], .75);
    expect(payload['propwashIntensity'], .5);
    expect(payload['vortexRingIntensity'], 1.2);
    expect(payload['rotorDiameterMeters'], .254);
  });

  test('configuration rejects invalid intensities and propeller diameter', () {
    for (final invalid in [
      const SimulationDescentAerodynamicsSettings(groundEffectIntensity: -1),
      const SimulationDescentAerodynamicsSettings(propwashIntensity: 3),
      const SimulationDescentAerodynamicsSettings(
        vortexRingIntensity: double.infinity,
      ),
      const SimulationDescentAerodynamicsSettings(
        rotorDiameterMeters: double.nan,
      ),
      const SimulationDescentAerodynamicsSettings(rotorDiameterMeters: .01),
      const SimulationDescentAerodynamicsSettings(rotorDiameterMeters: .9),
    ]) {
      expect(
        () => SimulationSettings(descentAerodynamics: invalid).toCommand(),
        throwsArgumentError,
      );
    }
  });
}
