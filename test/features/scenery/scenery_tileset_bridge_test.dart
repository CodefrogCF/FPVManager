import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../support/scenery_tileset_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('provider probes use the real bridge envelope and configurations replay on reconnect', () async {
    final db = FpvDatabase(NativeDatabase.memory()), globe = GlobeController();
    final renderer = FakeGlobeRenderer(globe)..autoAcknowledge = false;
    renderer.onCommand = (command) => renderer.acknowledge(
      command,
      result: switch (command['type']) {
        'scenery-catalog' => {
          'catalog': {'schemaVersion': 1, 'sceneries': []},
        },
        'probe-scenery-tileset' => {'tileset': tilesetMetadata()},
        _ => {},
      },
    );
    try {
      await expectLater(
        globe.probeSceneryTileset(
          'https://provider.example/root.json',
          'no-store',
        ),
        throwsStateError,
      );
      await globe.initializePreferences(UserPreferencesRepository(db));
      renderer.attach();
      renderer.ready();
      await globe.preferencesSettled;
      final result = await globe.probeSceneryTileset(
        'https://provider.example/root.json',
        'no-store',
      );
      expect(result, tilesetMetadata());
      final request = renderer.commands.lastWhere(
        (c) => c['type'] == 'probe-scenery-tileset',
      );
      expect(request['url'], 'https://provider.example/root.json');
      expect(request['cachePolicy'], 'no-store');
      await globe.saveSceneryDefinition(sceneryTilesetFixture(), create: true);
      await globe.setSceneryEnabled('synthetic-tileset', false);
      renderer.sessionId = 'remote-reconnect';
      renderer.sequence = 0;
      renderer.ready();
      await globe.preferencesSettled;
      final catalog =
          renderer.commands.lastWhere(
                (c) => c['type'] == 'replace-scenery-catalog',
              )['catalog']
              as Map;
      final item = (catalog['sceneries'] as List).single as Map;
      expect(item['enabled'], false);
      expect(item['assets'][0]['kind'], '3d-tiles');
      expect(item['assets'][0]['options']['cachePolicy'], 'no-store');
    } finally {
      globe.dispose();
      await globe.preferencesSettled;
      await db.close();
    }
  });
}
