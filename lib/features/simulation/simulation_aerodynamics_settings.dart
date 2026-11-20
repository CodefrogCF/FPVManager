/// Estimated orientation-dependent drag for the optional advanced simulator.
/// Ratios scale g / terminalVelocity²; they are not measured CdA coefficients.
enum SimulationAerodynamicsPreset {
  conservative,
  streamlined,
  highDrag,
  custom,
}

class SimulationAerodynamicsSettings {
  const SimulationAerodynamicsSettings({
    this.preset = SimulationAerodynamicsPreset.conservative,
    this.forward = .35,
    this.backward = .55,
    this.lateral = .7,
    this.vertical = 1,
    this.propeller = .12,
    this.propellerDragEnabled = true,
  });

  final SimulationAerodynamicsPreset preset;
  final double forward, backward, lateral, vertical, propeller;
  final bool propellerDragEnabled;

  /// Estimated forward drag for the chosen preset; only custom uses the
  /// supplied directional ratios instead of the published conservative set.
  double get effectiveForwardDragRatio => switch (preset) {
    SimulationAerodynamicsPreset.conservative => .35,
    SimulationAerodynamicsPreset.streamlined => .2,
    SimulationAerodynamicsPreset.highDrag => .6,
    SimulationAerodynamicsPreset.custom => forward,
  };

  void validate() {
    for (final (value, minimum) in [
      (forward, 0.0),
      (backward, 0.0),
      (lateral, 0.0),
      (vertical, .1),
      (propeller, 0.0),
    ]) {
      if (!value.isFinite || value < minimum || value > 5) {
        throw ArgumentError('Invalid aerodynamic drag ratio');
      }
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'preset': preset.name,
      'forward': forward,
      'backward': backward,
      'lateral': lateral,
      'vertical': vertical,
      'propeller': propeller,
      'propellerDragEnabled': propellerDragEnabled,
    };
  }
}
