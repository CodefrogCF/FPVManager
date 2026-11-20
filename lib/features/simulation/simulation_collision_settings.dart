/// Conservative assumptions for Advanced simulation-only impact resolution.
/// No contact model here certifies a real aircraft or obstacle clearance.
enum SimulationCollisionMode { slide, rebound, hardStop }

class SimulationCollisionSettings {
  const SimulationCollisionSettings({
    this.mode = SimulationCollisionMode.slide,
    this.restitution = .12,
    this.friction = .28,
    this.hardStopNormalSpeedMs = 22,
    this.minimumReboundSpeedMs = 1,
    this.terrainProbeMeters = .6,
  });

  final SimulationCollisionMode mode;
  final double restitution, friction, hardStopNormalSpeedMs;
  final double minimumReboundSpeedMs, terrainProbeMeters;

  void validate() {
    for (final (value, low, high) in [
      (restitution, 0.0, .75),
      (friction, 0.0, 1.0),
      (hardStopNormalSpeedMs, 1.0, 150.0),
      (minimumReboundSpeedMs, 0.0, 10.0),
      (terrainProbeMeters, .2, 3.0),
    ]) {
      if (!value.isFinite || value < low || value > high) {
        throw ArgumentError('Invalid advanced collision response parameter');
      }
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'mode': mode == SimulationCollisionMode.hardStop
          ? 'hard-stop'
          : mode.name,
      'restitution': restitution,
      'friction': friction,
      'hardStopNormalSpeedMs': hardStopNormalSpeedMs,
      'minimumReboundSpeedMs': minimumReboundSpeedMs,
      'terrainProbeMeters': terrainProbeMeters,
    };
  }
}
