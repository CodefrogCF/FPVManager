/// Optional, bounded thrust/airflow heuristics for the Advanced simulator.
/// Values are calibration assumptions, not validated aerodynamic predictions.
class SimulationDescentAerodynamicsSettings {
  const SimulationDescentAerodynamicsSettings({
    this.groundEffectEnabled = false,
    this.propwashEnabled = false,
    this.vortexRingEnabled = false,
    this.groundEffectIntensity = 1,
    this.propwashIntensity = 1,
    this.vortexRingIntensity = 1,
    this.rotorDiameterMeters = .1778,
  });

  final bool groundEffectEnabled, propwashEnabled, vortexRingEnabled;
  final double groundEffectIntensity, propwashIntensity, vortexRingIntensity;

  /// Assumed rotor diameter if no supported hardware profile is configured.
  /// When available, the hardware's real diameter takes precedence in JS.
  final double rotorDiameterMeters;

  void validate() {
    for (final value in [
      groundEffectIntensity,
      propwashIntensity,
      vortexRingIntensity,
    ]) {
      if (!value.isFinite || value < 0 || value > 2) {
        throw ArgumentError('Invalid descent aerodynamic intensity');
      }
    }
    if (!rotorDiameterMeters.isFinite ||
        rotorDiameterMeters < .0254 ||
        rotorDiameterMeters > .762) {
      throw ArgumentError('Invalid rotor diameter');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'groundEffectEnabled': groundEffectEnabled,
      'propwashEnabled': propwashEnabled,
      'vortexRingEnabled': vortexRingEnabled,
      'groundEffectIntensity': groundEffectIntensity,
      'propwashIntensity': propwashIntensity,
      'vortexRingIntensity': vortexRingIntensity,
      'rotorDiameterMeters': rotorDiameterMeters,
    };
  }
}
