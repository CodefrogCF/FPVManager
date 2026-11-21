import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_collision_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('legacy and advanced settings use compatible conservative defaults', () {
    const settings = SimulationSettings();
    final payload = settings.toCommand();
    expect(payload['physicsModel'], 'advanced');
    final collision = payload['collisionResponse'] as Map;
    expect(collision['mode'], 'slide');
    expect(collision['friction'], .28);
    expect(collision['restitution'], .12);
    expect(collision['hardStopNormalSpeedMs'], 22);
  });

  test('impact controls round trip through command and camera updates', () {
    const settings = SimulationSettings(
      physicsModel: SimulationPhysicsModel.advanced,
      collisionResponse: SimulationCollisionSettings(
        mode: SimulationCollisionMode.rebound,
        restitution: .23,
        friction: .4,
        hardStopNormalSpeedMs: 30,
        minimumReboundSpeedMs: 1.4,
        terrainProbeMeters: .8,
      ),
    );
    final changed = settings.withCameraTilt(22);
    expect(changed.collisionResponse.mode, SimulationCollisionMode.rebound);
    final payload = changed.toCommand()['collisionResponse'] as Map;
    expect(payload['mode'], 'rebound');
    expect(payload['restitution'], .23);
    expect(payload['friction'], .4);
    expect(payload['hardStopNormalSpeedMs'], 30);
    expect(payload['minimumReboundSpeedMs'], 1.4);
    expect(payload['terrainProbeMeters'], .8);
  });

  test('hard stop mode has compatible wire representation', () {
    expect(
      const SimulationCollisionSettings(mode: SimulationCollisionMode.hardStop)
          .toJson()['mode'],
      'hard-stop',
    );
  });

  test('invalid collision settings cannot reach simulation bridge', () {
    for (final invalid in [
      const SimulationCollisionSettings(restitution: -.1),
      const SimulationCollisionSettings(restitution: double.infinity),
      const SimulationCollisionSettings(friction: 1.1),
      const SimulationCollisionSettings(friction: double.nan),
      const SimulationCollisionSettings(hardStopNormalSpeedMs: 0),
      const SimulationCollisionSettings(hardStopNormalSpeedMs: 151),
      const SimulationCollisionSettings(minimumReboundSpeedMs: -1),
      const SimulationCollisionSettings(terrainProbeMeters: .1),
    ]) {
      expect(
        () => SimulationSettings(collisionResponse: invalid).toCommand(),
        throwsArgumentError,
      );
    }
  });
}
