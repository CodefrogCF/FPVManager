import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/activity_profile.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profile map defaults defer in active modes, preserve selection and never enable data sources', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = UserPreferencesRepository(db);
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final renderer = FakeGlobeRenderer(globe)..attach();
    renderer.ready();
    await globe.initializePreferences(repository);
    await Future<void>.delayed(Duration.zero);
    renderer.emit({
      'type': 'point-selected',
      'latitude': 46.8,
      'longitude': 8.3,
      'heightMeters': 12,
    });
    final selection = globe.selectedPoint;
    const defaults = ActivityMapDefaults(
      style: GlobeMapStyle.relief,
      savedPlaces: false,
      lighting: true,
    );
    for (final mode in ['simulation-state', 'ground-view-state']) {
      renderer.emit({'type': mode, 'active': true, 'pending': false});
      renderer.commands.clear();
      expect(await globe.applyActivityDefaults(defaults), isFalse);
      expect(renderer.commands, isEmpty);
      renderer.emit({'type': mode, 'active': false, 'pending': false});
    }
    await globe.setRenderingPaused(true);
    renderer.commands.clear();
    expect(await globe.applyActivityDefaults(defaults), isFalse);
    expect(renderer.commands, isEmpty);
    await globe.setRenderingPaused(false);
    renderer.commands.clear();
    expect(await globe.applyActivityDefaults(defaults), isTrue);
    expect(globe.selectedPoint, same(selection));
    expect(globe.location.enabled, isFalse);
    expect(renderer.commands.map((c) => c['type']), [
      'set-map-style',
      'set-spots-visible',
      'set-scene-environment',
    ]);
    final settings = await repository.getPreferences();
    expect(settings.mapStyle, GlobeMapStyle.relief);
    expect(settings.savedSpotsVisible, isFalse);
    expect(settings.realisticLighting, isTrue);
    expect(settings.uasZonesVisible, isFalse);
    expect(settings.obstacleVectorsVisible, isFalse);
    renderer.commands.clear();
    await globe.applyActivityDefaults(defaults);
    expect(renderer.commands, isEmpty);
  });
}
