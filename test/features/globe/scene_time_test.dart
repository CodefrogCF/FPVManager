import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/scene_time.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/scene_time_control.dart';
import 'package:fpvmanager/features/globe/scene_layers_section.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'shared preview control chooses device-local date/time and can return to now/map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var value = SceneTime(fixedUtc: DateTime.utc(2026, 6, 21, 12, 30));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SceneTimeControl(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(value.enabled, true);
      final chosenDay = value.fixedUtc!.toLocal();
      await tester.tap(find.text('Datum und Uhrzeit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '17');
      await tester.enterText(find.byType(TextField).at(1), '45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        value.fixedUtc,
        DateTime(
          chosenDay.year,
          chosenDay.month,
          chosenDay.day,
          17,
          45,
        ).toUtc(),
      );
      await tester.tap(find.text('Jetzt'));
      await tester.pumpAndSettle();
      expect(value.fixedUtc, isNull);
      expect(value.enabled, true);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(value.enabled, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '3D layer controls preserve the choice after a non-blocking tile failure and offer retry',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
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
      await tester.tap(find.text('3D & Licht'));
      await tester.pumpAndSettle();
      final buildings = find.widgetWithText(SwitchListTile, 'Gebäude');
      await tester.ensureVisible(buildings);
      await tester.tap(buildings);
      await tester.pumpAndSettle();
      expect(globe.buildings3dVisible, true);
      expect(peer.commands.last['type'], 'set-scene-environment');
      peer.emit({
        'type': 'scene-layer-status',
        'layer': 'buildings',
        'state': 'failed',
      });
      await tester.pumpAndSettle();
      final retry = find.text('Erneut laden');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(peer.commands.last['retry'], 'buildings');
      expect(globe.buildings3dVisible, true);
      expect(globe.error, isNull);
    },
  );
  test(
    'scene time retains a UTC instant and rejects ambiguous or invalid dates',
    () {
      final value = SceneTime(
        enabled: true,
        fixedUtc: DateTime.parse('2026-06-21T20:30:00+02:00'),
      );
      expect(value.toJson()['timeUtc'], '2026-06-21T18:30:00.000Z');
      expect(
        SceneTime.fromJson(value.toJson()).fixedUtc,
        DateTime.utc(2026, 6, 21, 18, 30),
      );
      for (final bad in [
        '2026-02-31T12:00:00Z',
        '2026-01-01T12:00:00',
        '1800-01-01T12:00:00Z',
      ]) {
        expect(
          () => SceneTime.fromJson({'enabled': true, 'timeUtc': bad}),
          throwsA(anything),
        );
      }
      expect(SceneTime.fromJson(const SceneTime().toJson()).enabled, isFalse);
    },
  );
  test('route lighting preview survives persistence and legacy settings inherit the map', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FlightPlanRepository(db);
    final time = SceneTime(
      enabled: true,
      fixedUtc: DateTime.utc(2026, 12, 21, 16),
    );
    final planning = const RoutePlanningSettings().withSceneTime(time);
    final id = await repository.saveRoute(
      name: 'Sunset route',
      waypoints: [],
      planning: planning,
    );
    final restored = RoutePlanningSettings.decode(
      (await repository.getRoute(id))!.plan.planningJson,
    );
    expect(restored.sceneTime.toJson(), time.toJson());
    final preferences = UserPreferencesRepository(db);
    await preferences.savePreferences(
      const UserPreferences(
        buildings3dVisible: true,
        vegetation3dVisible: true,
        realisticLighting: true,
      ),
    );
    final backups = BackupRepository(db);
    final snapshot = await backups.create();
    final document = await backups.preview(snapshot);
    await preferences.savePreferences(const UserPreferences());
    await repository.saveRoute(
      id: id,
      name: 'Changed',
      waypoints: [],
      planning: const RoutePlanningSettings(),
    );
    await backups.restore(document);
    final recovered = await preferences.getPreferences();
    expect(recovered.buildings3dVisible, true);
    expect(recovered.vegetation3dVisible, true);
    expect(recovered.realisticLighting, true);
    expect(
      RoutePlanningSettings.decode(
        (await repository.getRoute(id))!.plan.planningJson,
      ).sceneTime.toJson(),
      time.toJson(),
    );
    final legacy = jsonDecode(planning.encode()) as Map<String, dynamic>
      ..remove('sceneTime');
    expect(
      RoutePlanningSettings.decode(jsonEncode(legacy)).sceneTime.enabled,
      isFalse,
    );
    final sim = SimulationSettings(sceneTime: time).withCameraTilt(25);
    expect(sim.toCommand()['sceneTime'], time.toJson());
  });
  test('saved scene options restore after renderer reload and route preview has a scoped clear', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final preferences = UserPreferencesRepository(db);
    await preferences.savePreferences(
      const UserPreferences(
        buildings3dVisible: true,
        vegetation3dVisible: true,
        realisticLighting: true,
      ),
    );
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)..attach();
    await globe.initializePreferences(preferences);
    peer.ready();
    await Future<void>.delayed(Duration.zero);
    expect(
      peer.commands.where((c) => c['type'] == 'set-scene-environment').last,
      containsPair('vegetation', true),
    );
    peer.emit({
      'type': 'scene-layer-status',
      'layer': 'buildings',
      'state': 'partial',
    });
    expect(globe.sceneLayerStatus('buildings'), 'partial');
    expect(globe.error, isNull);
    await globe.setSceneEnvironment(vegetation: false);
    expect((await preferences.getPreferences()).vegetation3dVisible, isFalse);
    final time = SceneTime(
      enabled: true,
      fixedUtc: DateTime.utc(2026, 6, 21, 18),
    );
    await globe.setRouteEditor(editorId: 'sun', points: [], sceneTime: time);
    expect(peer.commands.last['sceneTime'], time.toJson());
    await globe.clearRouteTimePreview();
    expect(peer.commands.last['scope'], 'route');
    expect(peer.commands.last['enabled'], false);
    peer.ready();
    await Future<void>.delayed(Duration.zero);
    expect(
      peer.commands
          .where((c) => c['type'] == 'set-scene-environment')
          .last['vegetation'],
      false,
    );
    peer.emit({'type': 'scene-time-state', ...time.toJson()});
    expect(globe.simulationSceneTime!.fixedUtc, time.fixedUtc);
  });
}
