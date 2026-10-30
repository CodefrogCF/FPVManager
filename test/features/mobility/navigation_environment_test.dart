import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/navigation_environment_section.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test('navigation preferences survive backup, restart and renderer reload without changing map layers', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    final repository = UserPreferencesRepository(db);
    final globe = GlobeController();
    final peer = FakeGlobeRenderer(globe)..attach();
    addTearDown(() async {
      globe.dispose();
      await globe.preferencesSettled;
      await db.close();
    });
    await globe.initializePreferences(repository);
    await globe.setNavigationEnvironment(
      buildings: NavigationEnvironmentMode.enabled,
      vegetation: NavigationEnvironmentMode.disabled,
    );
    final backup = BackupRepository(db);
    final document = await backup.preview(await backup.create());
    await repository.resetPreferences();
    await backup.restore(document);
    final restarted = GlobeController();
    addTearDown(restarted.dispose);
    await restarted.initializePreferences(UserPreferencesRepository(db));
    expect(restarted.navigationBuildings, NavigationEnvironmentMode.enabled);
    expect(restarted.navigationVegetation, NavigationEnvironmentMode.disabled);
    expect(restarted.buildings3dVisible, false);
    expect(restarted.vegetation3dVisible, false);

    peer.ready();
    await Future<void>.delayed(Duration.zero);
    await globe.setRoadNavigation(
      active: true,
      follow: true,
      latitude: 47,
      longitude: 8,
    );
    for (var reload = 0; reload < 2; reload++) {
      if (reload > 0) {
        peer.emit({'type': 'renderer-loading'});
        peer.sessionId = 'renderer-2';
        peer.sequence = 0;
        peer.ready();
        await Future<void>.delayed(Duration.zero);
      }
      final commands = peer.commands;
      final environment = commands.lastWhere(
        (c) => c['type'] == 'set-navigation-environment',
      );
      expect(environment, containsPair('buildings', true));
      expect(environment, containsPair('vegetation', false));
      expect(
        commands.lastWhere((c) => c['type'] == 'set-road-navigation')['active'],
        true,
      );
    }
    await globe.setRoadNavigation(active: false, follow: false);
    expect(globe.buildings3dVisible, false);
    expect(globe.vegetation3dVisible, false);
    await globe.setNavigationEnvironment(
      buildings: NavigationEnvironmentMode.inherit,
    );
    expect(peer.commands.last, containsPair('buildings', null));
  });

  testWidgets(
    'compact navigation choices are independent and model failures can be retried',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await globe.setSceneEnvironment(buildings: true);
      for (final size in [const Size(360, 800), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.4),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ListenableBuilder(
                    listenable: globe,
                    builder: (_, _) => NavigationEnvironmentSection(
                      settings: globe,
                      renderer: globe,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.tap(find.text('Ein').first);
      await tester.pumpAndSettle();
      expect(globe.navigationBuildings, NavigationEnvironmentMode.enabled);
      expect(globe.navigationVegetation, NavigationEnvironmentMode.inherit);
      expect(globe.buildings3dVisible, true);
      peer.emit({
        'type': 'scene-layer-status',
        'layer': 'buildings',
        'state': 'failed',
      });
      await tester.pumpAndSettle();
      final retry = find.byTooltip('Gebäude erneut laden');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(peer.commands.last['retry'], 'buildings');
      expect(globe.error, isNull);
    },
  );
}
