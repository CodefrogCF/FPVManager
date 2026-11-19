/// Presentation-only RF/terrain-warning configuration.
/// Never used to determine aircraft behavior or failsafe transitions.
class SignalHudSettings {
  const SignalHudSettings({
    this.djiWarning = true,
    this.betaflightBars = true,
    this.analogNoise = false,
    this.terrainIllustration = false,
    this.weakThreshold = 0.55,
    this.criticalThreshold = 0.25,
    this.lostThreshold = 0.08,
    this.analogIntensity = 0.65,
  });

  final bool djiWarning, betaflightBars, analogNoise, terrainIllustration;
  final double weakThreshold, criticalThreshold, lostThreshold, analogIntensity;

  SignalHudSettings copyWith({
    bool? djiWarning,
    bool? betaflightBars,
    bool? analogNoise,
    bool? terrainIllustration,
    double? weakThreshold,
    double? criticalThreshold,
    double? lostThreshold,
    double? analogIntensity,
  }) => SignalHudSettings(
    djiWarning: djiWarning ?? this.djiWarning,
    betaflightBars: betaflightBars ?? this.betaflightBars,
    analogNoise: analogNoise ?? this.analogNoise,
    terrainIllustration: terrainIllustration ?? this.terrainIllustration,
    weakThreshold: weakThreshold ?? this.weakThreshold,
    criticalThreshold: criticalThreshold ?? this.criticalThreshold,
    lostThreshold: lostThreshold ?? this.lostThreshold,
    analogIntensity: analogIntensity ?? this.analogIntensity,
  );

  void validate() {
    for (final value in [
      weakThreshold,
      criticalThreshold,
      lostThreshold,
      analogIntensity,
    ]) {
      if (!value.isFinite || value < 0 || value > 1) {
        throw ArgumentError('Signal HUD values must be between 0 and 1');
      }
    }
    if (!(lostThreshold < criticalThreshold &&
        criticalThreshold < weakThreshold)) {
      throw ArgumentError('Signal HUD thresholds must be ordered');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'djiWarning': djiWarning,
      'betaflightBars': betaflightBars,
      'analogNoise': analogNoise,
      'terrainIllustration': terrainIllustration,
      'weakThreshold': weakThreshold,
      'criticalThreshold': criticalThreshold,
      'lostThreshold': lostThreshold,
      'analogIntensity': analogIntensity,
    };
  }

  factory SignalHudSettings.fromJson(Object? source) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Invalid signal HUD settings');
    }
    const defaults = SignalHudSettings();
    bool flag(String key, bool fallback) {
      final value = source[key];
      if (value == null) return fallback;
      if (value is! bool) throw FormatException('Invalid signal HUD $key');
      return value;
    }

    double number(String key, double fallback) {
      final value = source[key];
      if (value == null) return fallback;
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid signal HUD $key');
      }
      return value.toDouble();
    }

    final result = SignalHudSettings(
      djiWarning: flag('djiWarning', defaults.djiWarning),
      betaflightBars: flag('betaflightBars', defaults.betaflightBars),
      analogNoise: flag('analogNoise', defaults.analogNoise),
      terrainIllustration: flag(
        'terrainIllustration',
        defaults.terrainIllustration,
      ),
      weakThreshold: number('weakThreshold', defaults.weakThreshold),
      criticalThreshold: number(
        'criticalThreshold',
        defaults.criticalThreshold,
      ),
      lostThreshold: number('lostThreshold', defaults.lostThreshold),
      analogIntensity: number('analogIntensity', defaults.analogIntensity),
    );
    result.validate();
    return result;
  }
}
