import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../support/scenery_fixture.dart';
import 'scenery_alignment_test.dart' show edit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'alignment start, confirmation and reconnect use actual bridge envelopes',
    () async {
      final db = FpvDatabase(NativeDatabase.memory()),
          globe = GlobeController();
      final renderer = FakeGlobeRenderer(globe)..autoAcknowledge = false;
      renderer.onCommand = (command) => renderer.acknowledge(
        command,
        result: command['type'] == 'scenery-catalog'
            ? {
                'catalog': {'schemaVersion': 1, 'sceneries': []},
              }
            : {},
      );
      try {
        await globe.initializePreferences(UserPreferencesRepository(db));
        renderer.attach();
        renderer.ready();
        await globe.preferencesSettled;
        await globe.saveSceneryDefinition(sceneryFixture(), create: true);
        await globe.alignScenery(id: 'synthetic-site', german: false);
        final begin = renderer.commands.lastWhere(
          (c) => c['type'] == 'begin-scenery-alignment',
        );
        expect(begin['definitions'][0]['id'], 'synthetic-site');
        renderer.emit({
          'type': 'scenery-alignment-submit',
          'token': begin['token'],
          'id': 'synthetic-site',
          'placement': edit(),
        });
        await globe.preferencesSettled;
        await Future<void>.delayed(Duration.zero);
        expect(
          (await globe.sceneryDefinitions()).single
              .toJson()['anchor']['heightM'],
          120,
        );
        renderer.sessionId = 'aligned-reconnect';
        renderer.sequence = 0;
        renderer.ready();
        await globe.preferencesSettled;
        final item =
            (renderer.commands.lastWhere(
                          (c) => c['type'] == 'replace-scenery-catalog',
                        )['catalog']['sceneries']
                        as List)
                    .single
                as Map;
        expect(item['alignment']['pitchDeg'], 8);
        expect(item['alignment']['opacity'], .5);
        renderer.emit({
          'type': 'scenery-alignment-submit',
          'token': begin['token'],
          'id': 'synthetic-site',
          'placement': edit()..['heightM'] = 500,
        });
        await globe.preferencesSettled;
        expect(
          (await globe.sceneryDefinitions()).single
              .toJson()['anchor']['heightM'],
          120,
        );
      } finally {
        globe.dispose();
        await globe.preferencesSettled;
        await db.close();
      }
    },
  );
}
