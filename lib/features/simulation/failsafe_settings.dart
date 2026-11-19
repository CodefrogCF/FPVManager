/// Optional, deterministic *simulated* RC loss response, never real telemetry.
/// Ground station coordinates and video-only terrain effects are independent.
final class FailsafeSettings {
  const FailsafeSettings({
    this.enabled = false,
    this.mode = 'hold',
    this.lossThreshold = .20,
    this.recoveryThreshold = .45,
    this.activationDelaySeconds = .6,
    this.recoveryDelaySeconds = .6,
    this.rescueAltitudeMeters = 100,
    this.returnSpeedMetersPerSecond = 8,
    this.climbSpeedMetersPerSecond = 5,
    this.autoRecover = false,
  });

  final bool enabled;
  final String mode;
  final double lossThreshold, recoveryThreshold;
  final double activationDelaySeconds, recoveryDelaySeconds;
  final double rescueAltitudeMeters,
      returnSpeedMetersPerSecond,
      climbSpeedMetersPerSecond;
  final bool autoRecover;

  void validate() {
    if (!['hold', 'descend', 'gpsRescue'].contains(mode)) {
      throw ArgumentError('Unsupported simulated failsafe mode');
    }
    for (final v in [
      (lossThreshold, 0.0, .5),
      (recoveryThreshold, .05, 1.0),
      (activationDelaySeconds, .1, 30.0),
      (recoveryDelaySeconds, .1, 30.0),
      (rescueAltitudeMeters, 5.0, 500.0),
      (returnSpeedMetersPerSecond, .5, 50.0),
      (climbSpeedMetersPerSecond, .2, 15.0),
    ]) {
      if (!v.$1.isFinite || v.$1 < v.$2 || v.$1 > v.$3) {
        throw ArgumentError('Invalid simulated failsafe parameter');
      }
    }
    if (recoveryThreshold <= lossThreshold + .05) {
      throw ArgumentError('Failsafe recovery threshold requires hysteresis');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'enabled': enabled,
      'mode': mode,
      'lossThreshold': lossThreshold,
      'recoveryThreshold': recoveryThreshold,
      'activationDelaySeconds': activationDelaySeconds,
      'recoveryDelaySeconds': recoveryDelaySeconds,
      'rescueAltitudeMeters': rescueAltitudeMeters,
      'returnSpeedMetersPerSecond': returnSpeedMetersPerSecond,
      'climbSpeedMetersPerSecond': climbSpeedMetersPerSecond,
      'autoRecover': autoRecover,
    };
  }

  factory FailsafeSettings.fromJson(Object? source) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Invalid simulated failsafe settings');
    }
    const fallback = FailsafeSettings();
    bool flag(String key, bool defaultValue) {
      final value = source[key];
      if (value == null) return defaultValue;
      if (value is! bool) throw FormatException('Invalid failsafe $key');
      return value;
    }

    double number(String key, double defaultValue) {
      final value = source[key];
      if (value == null) return defaultValue;
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid failsafe $key');
      }
      return value.toDouble();
    }

    final mode = source['mode'];
    if (mode != null && mode is! String) {
      throw const FormatException('Invalid failsafe mode');
    }
    final result = FailsafeSettings(
      enabled: flag('enabled', fallback.enabled),
      mode: mode as String? ?? fallback.mode,
      lossThreshold: number('lossThreshold', fallback.lossThreshold),
      recoveryThreshold: number(
        'recoveryThreshold',
        fallback.recoveryThreshold,
      ),
      activationDelaySeconds: number(
        'activationDelaySeconds',
        fallback.activationDelaySeconds,
      ),
      recoveryDelaySeconds: number(
        'recoveryDelaySeconds',
        fallback.recoveryDelaySeconds,
      ),
      rescueAltitudeMeters: number(
        'rescueAltitudeMeters',
        fallback.rescueAltitudeMeters,
      ),
      returnSpeedMetersPerSecond: number(
        'returnSpeedMetersPerSecond',
        fallback.returnSpeedMetersPerSecond,
      ),
      climbSpeedMetersPerSecond: number(
        'climbSpeedMetersPerSecond',
        fallback.climbSpeedMetersPerSecond,
      ),
      autoRecover: flag('autoRecover', fallback.autoRecover),
    );
    result.validate();
    return result;
  }
}
