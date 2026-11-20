import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_aerodynamics_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('existing flight profiles receive conservative defaults', () {
    const settings = SimulationSettings();
    final payload = settings.toCommand();
    expect(settings.physicsModel, SimulationPhysicsModel.legacy);
    final drag = payload['aerodynamics'] as Map<String, dynamic>;
    expect(drag['preset'], 'conservative');
    expect(drag['forward'], .35);
    expect(drag['backward'], .55);
    expect(drag['lateral'], .7);
    expect(drag['vertical'], 1);
    expect(drag['propellerDragEnabled'], isTrue);
  });

  test('custom body drag ratios survive camera and graphics adjustments', () {
    const selected = SimulationSettings(
      physicsModel: SimulationPhysicsModel.advanced,
      aerodynamics: SimulationAerodynamicsSettings(
        preset: SimulationAerodynamicsPreset.custom,
        forward: .22,
        backward: .44,
        lateral: .66,
        vertical: 1.18,
        propeller: .1,
        propellerDragEnabled: false,
      ),
    );
    final adjusted = selected.withCameraTilt(42);
    expect(adjusted.aerodynamics.preset, SimulationAerodynamicsPreset.custom);
    expect(adjusted.aerodynamics.propellerDragEnabled, isFalse);
    expect(adjusted.toCommand()['aerodynamics']['forward'], .22);
    expect(adjusted.toCommand()['aerodynamics']['vertical'], 1.18);
    expect(
      adjusted.toCommand()['aerodynamics']['propellerDragEnabled'],
      isFalse,
    );
  });

  test(
    'legacy speed estimate is unchanged; advanced uses forward resistance',
    () {
      const legacy = SimulationSettings();
      const advanced = SimulationSettings(
        physicsModel: SimulationPhysicsModel.advanced,
      );
      expect(legacy.acroEstimatedLevelSpeedKmh, greaterThan(0));
      expect(
        advanced.acroEstimatedLevelSpeedKmh,
        closeTo(legacy.acroEstimatedLevelSpeedKmh / math.sqrt(.35), 1e-6),
      );
    },
  );

  test('invalid custom drag ratios fail before constructing JS payload', () {
    for (final settings in [
      const SimulationAerodynamicsSettings(forward: double.nan),
      const SimulationAerodynamicsSettings(backward: -1),
      const SimulationAerodynamicsSettings(lateral: 6),
      const SimulationAerodynamicsSettings(vertical: 0),
      const SimulationAerodynamicsSettings(propeller: double.infinity),
    ]) {
      expect(
        () => SimulationSettings(aerodynamics: settings).validate(),
        throwsArgumentError,
      );
    }
  });
}
