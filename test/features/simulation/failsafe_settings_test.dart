import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/failsafe_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';

void main() {
  test('Simulated failsafe is off by default', () {
    const defaults = FailsafeSettings();
    expect(defaults.enabled, false);
    expect(defaults.mode, 'hold');
    expect(
      const SimulationSettings().toCommand()['failsafe'],
      defaults.toJson(),
    );
  });

  test('GPS Rescue settings round trip without losing existing flight configuration', () {
    const selected = FailsafeSettings(
      enabled: true,
      mode: 'gpsRescue',
      lossThreshold: .1,
      recoveryThreshold: .4,
      activationDelaySeconds: 2,
      recoveryDelaySeconds: 3,
      rescueAltitudeMeters: 80,
      returnSpeedMetersPerSecond: 9,
      climbSpeedMetersPerSecond: 2.5,
      autoRecover: false,
    );
    final decoded = FailsafeSettings.fromJson(selected.toJson());
    expect(decoded.toJson(), selected.toJson());
    final flight = SimulationSettings(failsafe: decoded);
    expect(flight.withCameraTilt(15).failsafe.toJson(), selected.toJson());
    expect(flight.toCommand()['failsafe'], selected.toJson());
    expect(
      const UserPreferences().copyWith(failsafe: selected).failsafe.toJson(),
      selected.toJson(),
    );
  });

  test('Invalid settings fail closed before they reach the renderer', () {
    expect(() => FailsafeSettings.fromJson(null), throwsFormatException);
    expect(
      () => FailsafeSettings.fromJson({'enabled': 1}),
      throwsFormatException,
    );
    expect(
      () => FailsafeSettings.fromJson({'lossThreshold': double.nan}),
      throwsFormatException,
    );
    expect(
      () => FailsafeSettings.fromJson({'mode': 'flyAway'}),
      throwsArgumentError,
    );
    for (final invalid in [
      const FailsafeSettings(mode: 'teleport'),
      const FailsafeSettings(lossThreshold: .4, recoveryThreshold: .42),
      const FailsafeSettings(rescueAltitudeMeters: -1),
      const FailsafeSettings(returnSpeedMetersPerSecond: 90),
      const FailsafeSettings(activationDelaySeconds: double.infinity),
    ]) {
      expect(invalid.validate, throwsArgumentError);
    }
  });
}
