import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test(
    'capture mode bridge requires an active flight and can always restore',
    () async {
      final controller = GlobeController();
      addTearDown(controller.dispose);
      final commands = <Map<String, dynamic>>[];
      final renderer = FakeGlobeRenderer(controller, commands: commands)
        ..attach()
        ..ready();
      await expectLater(controller.setCaptureMode(true), throwsStateError);
      renderer.emit({
        'type': 'simulation-state',
        'active': true,
        'pending': false,
      });
      await controller.setCaptureMode(true);
      expect(commands.last['type'], 'set-capture-mode');
      expect(commands.last['enabled'], isTrue);
      await controller.setCaptureMode(false);
      expect(commands.last['enabled'], isFalse);
      renderer.emit({
        'type': 'simulation-state',
        'active': false,
        'pending': false,
      });
      await expectLater(controller.setCaptureMode(true), throwsStateError);
    },
  );
}
