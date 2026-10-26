import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/controller_settings.dart';
import 'package:fpvmanager/features/simulation/controller_settings_fields.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

void main() {
  test('controller channels, reversal and zero position round-trip and survive camera/HUD changes', () {
    const controller = ControllerSettings(
      layout: ControllerLayout.radio,
      throttleZero: ControllerThrottleZero.bottom,
      rollAxis: 3,
      yawAxis: 0,
      invertThrottle: true,
    );
    expect(
      ControllerSettings.tryParse(controller.toJson())!.toJson(),
      controller.toJson(),
    );
    final changed = const SimulationSettings(controller: controller)
        .withCameraTilt(30, hudStyle: SimulationHudStyle.betaflight);
    expect(changed.toCommand()['controller'], controller.toJson());
    for (final invalid in [
      <String, dynamic>{...controller.toJson(), 'layout': 'unknown'},
      {...controller.toJson(), 'throttleZero': 'low'},
      {...controller.toJson(), 'pitchAxis': 3},
      {...controller.toJson(), 'rollAxis': 16},
      {...controller.toJson(), 'invertYaw': 1},
      {...controller.toJson(), 'throttleAxis': 2.5},
    ]) {
      expect(ControllerSettings.tryParse(invalid), isNull);
    }
    expect(
      const ControllerSettings(rollAxis: -1).validate,
      throwsArgumentError,
    );
  });

  testWidgets(
    'radio settings default to bottom zero, swap occupied channels and allow independent reversal at 320 pixels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ControllerSettings? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: ControllerSettingsFields(
                  initial: const ControllerSettings(),
                  onChanged: (v) => chosen = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('External controller'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('controller-layout')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USB radio · Tango 2 / custom').last);
      await tester.pumpAndSettle();
      expect(chosen!.throttleZero, ControllerThrottleZero.bottom);
      expect(
        tester
            .widget<DropdownButtonFormField<ControllerThrottleZero>>(
              find.byKey(const ValueKey('controller-throttle-zero')),
            )
            .initialValue,
        ControllerThrottleZero.bottom,
      );
      final roll = find.byKey(const ValueKey('controller-axis-0'));
      await tester.ensureVisible(roll);
      await tester.tap(roll);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Channel 3').last);
      await tester.pumpAndSettle();
      expect(chosen!.rollAxis, 2);
      expect(chosen!.throttleAxis, 0);
      expect(chosen!.validate, returnsNormally);
      await tester.ensureVisible(find.bySemanticsLabel('Reverse roll'));
      await tester.tap(find.bySemanticsLabel('Reverse roll'));
      await tester.pumpAndSettle();
      expect(chosen!.invertRoll, true);
      expect(tester.takeException(), isNull);
    },
  );
}
