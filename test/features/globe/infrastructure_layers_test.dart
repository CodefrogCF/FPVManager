import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/scene_layers_section.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test('infrastructure preferences are independent and survive existing SQLite settings', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = UserPreferencesRepository(db);
    final defaults = await repository.getPreferences();
    expect(defaults.structures3dVisible, false);
    expect(defaults.sceneModelCollisionsEnabled, false);
    expect(defaults.tunnelRoutesVisible, false);
    expect(defaults.tunnelExplorationEnabled, false);
    await repository.savePreferences(
      const UserPreferences(
        buildings3dVisible: false,
        vegetation3dVisible: true,
        structures3dVisible: true,
        sceneModelCollisionsEnabled: true,
        tunnelRoutesVisible: true,
        tunnelExplorationEnabled: true,
        structuresOpacity: .6,
        tunnelRoutesOpacity: .7,
      ),
    );
    final recovered = await repository.getPreferences();
    expect(recovered.buildings3dVisible, false);
    expect(recovered.vegetation3dVisible, true);
    expect(recovered.structures3dVisible, true);
    expect(recovered.sceneModelCollisionsEnabled, true);
    expect(recovered.tunnelRoutesVisible, true);
    expect(recovered.tunnelExplorationEnabled, true);
    expect(recovered.structuresOpacity, .6);
    expect(recovered.tunnelRoutesOpacity, .7);
    expect(
      recovered.copyWith(structures3dVisible: false).tunnelRoutesVisible,
      true,
    );
  });

  testWidgets(
    'opt-in infrastructure controls and manual tunnel scan preserve source status',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.autoAcknowledge = false;
      peer.onCommand = (command) {
        if (command['type'] == 'scan-tunnel-infrastructure') {
          peer.acknowledge(
            command,
            result: {
              'incomplete': true,
              'routes': [
                {
                  'id': 'road:abc:0',
                  'name': 'Demo corridor',
                  'kind': 'tunnel',
                  'transport': 'road',
                  'source': 'ch.swisstopo.swisstlm3d-strassen',
                  'sourceId': 'abc',
                  'endpointsVerified': false,
                  'heightReference': 'unavailable',
                },
              ],
            },
          );
        } else {
          peer.acknowledge(command);
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: globe,
                builder: (context, _) => SceneLayersSection(controller: globe),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('3D-Umgebung und Himmelslicht'));
      await tester.pumpAndSettle();
      final structures = find.widgetWithText(
        SwitchListTile,
        'Brücken, 3D-Bauwerke und Tunnelachsen',
      );
      await tester.ensureVisible(structures);
      await tester.tap(structures);
      await tester.pumpAndSettle();
      expect(globe.structures3dVisible, true);
      expect(peer.commands.last['structures'], true);
      final collisions = find.widgetWithText(
        SwitchListTile,
        '3D-Modellkollisionen (experimentell)',
      );
      await tester.ensureVisible(collisions);
      await tester.tap(collisions);
      await tester.pumpAndSettle();
      expect(globe.sceneModelCollisionsEnabled, true);
      expect(peer.commands.last['modelCollisions'], true);
      final tunnels = find.widgetWithText(
        SwitchListTile,
        'Tunnelverläufe und Unterführungen',
      );
      await tester.ensureVisible(tunnels);
      await tester.tap(tunnels);
      await tester.pumpAndSettle();
      expect(globe.tunnelRoutesVisible, true);
      expect(peer.commands.last['type'], 'set-tunnel-infrastructure');
      final scan = find.text('Tunnelachsen um Kartenmitte suchen (600 m)');
      await tester.ensureVisible(scan);
      await tester.tap(scan);
      await tester.pumpAndSettle();
      expect(globe.tunnelRoutes.length, 1);
      expect(globe.tunnelScanIncomplete, true);
      expect(find.text('Demo corridor'), findsOneWidget);
      peer.emit({'type': 'renderer-loading'});
      await tester.pump();
      expect(globe.tunnelRoutes, isEmpty);
      expect(globe.tunnelExploring, false);
    },
  );
}
