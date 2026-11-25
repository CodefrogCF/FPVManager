import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../support/scenery_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('persistent scenery survives the real bridge envelopes and renderer reconnect', () async {
    final db = FpvDatabase(NativeDatabase.memory()), globe = GlobeController();
    final bundled = jsonDecode(
      File('web/assets/scenery/catalog.json').readAsStringSync(),
    );
    final renderer = FakeGlobeRenderer(globe)..autoAcknowledge = false;
    renderer.onCommand = (command) => renderer.acknowledge(
      command,
      result: command['type'] == 'scenery-catalog' ? {'catalog': bundled} : {},
    );
    try {
      await globe.initializePreferences(UserPreferencesRepository(db));
      renderer.attach();
      renderer.ready();
      await globe.preferencesSettled;
      var definitions = await globe.sceneryDefinitions();
      expect(definitions.length, 1);
      final id = definitions.single.id;
      final restore = renderer.commands.lastWhere(
        (c) => c['type'] == 'replace-scenery-catalog',
      );
      expect(((restore['catalog'] as Map)['sceneries'] as List).length, 1);
      await globe.setSceneryEnabled(id, false);
      expect((await globe.sceneryDefinitions()).single.enabled, false);
      await globe.saveSceneryDefinition(sceneryFixture(), create: true);
      await globe.removeSceneryDefinition(id);
      renderer.sessionId = 'renderer-2';
      renderer.sequence = 0;
      renderer.ready();
      await globe.preferencesSettled;
      definitions = await globe.sceneryDefinitions();
      expect(definitions.single.id, 'synthetic-site');
      final replay = renderer.commands.lastWhere(
        (c) => c['type'] == 'replace-scenery-catalog',
      );
      expect(
        (((replay['catalog'] as Map)['sceneries'] as List).single as Map)['id'],
        'synthetic-site',
      );
    } finally {
      globe.dispose();
      await globe.preferencesSettled;
      await db.close();
    }
  });
}
