import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('render scale is optional and persists independently of profile', () {
    expect(SimulationSettings.fromJson({}).renderScale, isNull);
    const settings = SimulationSettings(renderScale: .55);
    final restored = SimulationSettings.fromJson(settings.toJson());
    expect(restored.renderScale, .55);
    expect(restored.toCommand()['renderScale'], .55);
    expect(
      restored
          .withCameraTilt(
            10,
            graphicsProfile: SimulationGraphicsProfile.quality,
          )
          .renderScale,
      .55,
    );
    for (final invalid in [.39, 1.01, double.nan, double.infinity]) {
      expect(
        () => SimulationSettings(renderScale: invalid).validate(),
        throwsArgumentError,
      );
    }
  });
}
