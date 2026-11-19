import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/signal_hud_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test(
    'Signal HUD defaults are opt-in and serialized to the flight renderer',
    () {
      const defaults = SignalHudSettings();
      expect(defaults.djiWarning, isFalse);
      expect(defaults.betaflightBars, isFalse);
      expect(defaults.analogNoise, isFalse);
      expect(defaults.terrainIllustration, isFalse);
      expect(defaults.toJson()['weakThreshold'], .55);
      expect(
        const SimulationSettings().toCommand()['signalHud'],
        defaults.toJson(),
      );
    },
  );

  test('Settings survive JSON round-trip and simulation copies', () {
    const settings = SignalHudSettings(
      djiWarning: true,
      betaflightBars: true,
      analogNoise: true,
      terrainIllustration: true,
      weakThreshold: .65,
      criticalThreshold: .3,
      lostThreshold: .1,
      analogIntensity: .8,
    );
    final decoded = SignalHudSettings.fromJson(settings.toJson());
    expect(decoded.toJson(), settings.toJson());
    final flight = SimulationSettings(signalHud: decoded);
    expect(flight.withCameraTilt(25).signalHud.toJson(), settings.toJson());
    expect(flight.toCommand()['signalHud'], settings.toJson());
  });

  test('Invalid thresholds and malformed settings fail before bridging', () {
    for (final input in [
      const SignalHudSettings(weakThreshold: .2, criticalThreshold: .3),
      const SignalHudSettings(lostThreshold: .4, criticalThreshold: .3),
      const SignalHudSettings(analogIntensity: double.nan),
      const SignalHudSettings(analogIntensity: 1.1),
    ]) {
      expect(input.validate, throwsArgumentError);
    }
    expect(() => SignalHudSettings.fromJson(null), throwsFormatException);
    expect(
      () => SignalHudSettings.fromJson({'djiWarning': 'on'}),
      throwsFormatException,
    );
    expect(
      () => SignalHudSettings.fromJson({'analogIntensity': double.nan}),
      throwsFormatException,
    );
    expect(
      () => SignalHudSettings.fromJson({'weakThreshold': 0.0}),
      throwsArgumentError,
    );
    expect(
      () => SignalHudSettings.fromJson({'unrecognized': 1}),
      returnsNormally,
    );
  });
}
