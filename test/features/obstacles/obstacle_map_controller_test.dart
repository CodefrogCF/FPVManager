import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/obstacles/obstacle_details_panel.dart';
import 'package:fpvmanager/features/obstacles/obstacle_layers_section.dart';
import 'package:fpvmanager/features/obstacles/obstacle_models.dart';
import 'package:fpvmanager/features/obstacles/swiss_obstacle_provider.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/obstacle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OsintCacheDatabase cache;
  late FpvDatabase database;
  late UserPreferencesRepository preferences;
  late MockClient client;
  late SwissObstacleProvider provider;
  late GlobeController globe;
  late FakeGlobeRenderer renderer;
  setUp(() async {
    cache = OsintCacheDatabase(NativeDatabase.memory());
    database = FpvDatabase(NativeDatabase.memory());
    preferences = UserPreferencesRepository(database);
    client = MockClient(
      (r) async => r.url.path.endsWith('/items')
          ? http.Response(jsonEncode(obstacleStac()), 200)
          : http.Response.bytes(obstacleKmz(obstacleKml()), 200),
    );
    provider = SwissObstacleProvider(client: client, cache: cache);
    await provider.fetch(forceRefresh: true);
    globe = GlobeController(obstacleProvider: provider);
    renderer = FakeGlobeRenderer(globe)..attach();
    renderer.ready();
    await globe.initializePreferences(preferences);
  });
  tearDown(() async {
    globe.dispose();
    await globe.preferencesSettled;
    provider.dispose();
    client.close();
    await cache.close();
    await database.close();
  });
  test('small camera changes reuse the nearby batch and do not reload unchanged models or cables', () async {
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.39,
      'south': 46.69,
      'east': 8.41,
      'north': 46.71,
    });
    await globe.obstacles.setVectorsVisible(true);
    await globe.obstacles.setModelsVisible(true);
    final before = renderer.commands
        .where((c) => c['type'] == 'set-obstacle-vectors')
        .length;
    final command = renderer.commands.lastWhere(
      (c) => c['type'] == 'set-obstacle-vectors',
    );
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.391,
      'south': 46.691,
      'east': 8.411,
      'north': 46.711,
    });
    await globe.obstacles.updateViewport();
    expect(
      renderer.commands
          .where((c) => c['type'] == 'set-obstacle-vectors')
          .length,
      before,
    );
    renderer.emit({
      'type': 'obstacle-selected',
      'id': 'source-1',
      'revision': command['revision'],
    });
    expect(globe.obstacles.selected?.id, 'source-1');
    await globe.obstacles.setCategory(ObstacleCategory.powerLines, false);
    expect(
      renderer.commands.lastWhere(
        (c) => c['type'] == 'set-obstacle-vectors',
      )['features'],
      isEmpty,
    );
  });
  test('WMS requested settings persist and restore after renderer reload, with local failure/retry', () async {
    await globe.obstacles.setWmsVisible(true);
    await globe.obstacles.setWmsOpacity(.35);
    await globe.setMapStyle(GlobeMapStyle.relief);
    final stored = await preferences.getPreferences();
    expect(stored.obstacleWmsVisible, isTrue);
    expect(stored.obstacleWmsOpacity, .35);
    renderer.emit({'type': 'obstacle-wms-status', 'state': 'failed'});
    expect(globe.obstacles.wmsError, isNotNull);
    expect(globe.error, isNull);
    expect(globe.terrainAvailable, isTrue);
    await globe.obstacles.restoreWms(retry: true);
    expect(renderer.commands.last['retry'], isTrue);
    renderer.emit({'type': 'renderer-loading'});
    renderer.sessionId = 'renderer-2';
    renderer.sequence = 0;
    renderer.ready();
    await pumpEventQueue(times: 20);
    final command = renderer.commands.lastWhere(
      (c) => c['type'] == 'set-obstacle-wms',
    );
    expect(command['visible'], isTrue);
    expect(command['opacity'], .35);
    expect(globe.error, isNull);
    expect(provider.status.dataset, isNotNull);
  });
  test('support query retains isolated transmission-line points and excludes KML label points', () async {
    final key = provider.status.dataset!.data.key;
    await cache.stageObstacles(key, [
      ObstacleFeature(
        id: 'power-line-support',
        name: 'Published support',
        attributes: {'obstacleType': 'TRANSMISSION_LINE', 'maxHeightAGL': '40'},
        parts: [
          const ObstaclePart('Point', 'absolute', [
            [8.4, 46.7, 600],
          ]),
        ],
      ),
    ]);
    final supports = await cache.queryObstacles(
      key,
      const ObstacleViewport(8.3, 46.6, 8.5, 46.8),
      {ObstacleCategory.powerLines},
      pointsOnly: true,
    );
    expect(supports.map((f) => f.id), ['power-line-support']);
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.3,
      'south': 46.6,
      'east': 8.5,
      'north': 46.8,
    });
    await globe.obstacles.setVectorsVisible(true);
    await globe.obstacles.setModelsVisible(true);
    final command = renderer.commands.lastWhere(
      (c) =>
          c['type'] == 'set-obstacle-vectors' &&
          (c['features'] as List).isNotEmpty,
    );
    final support = (command['features'] as List).cast<Map>().singleWhere(
      (f) => f['id'] == 'power-line-support',
    );
    expect((support['parts'] as List).single['heightAgl'], 40);
    expect(support['sourceType'], 'TRANSMISSION_LINE');
    expect(command['useModels'], isTrue);
    expect((await preferences.getPreferences()).obstacleModelsVisible, isTrue);
    // Reopening the renderer restores preferences without a source refresh.
    final retrieval = provider.status.dataset!.fetchedAtUtc;
    renderer.emit({'type': 'renderer-loading'});
    renderer.sessionId = 'model-reload';
    renderer.sequence = 0;
    renderer.ready();
    await pumpEventQueue(times: 20);
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.3,
      'south': 46.6,
      'east': 8.5,
      'north': 46.8,
    });
    await globe.obstacles.updateViewport();
    expect(
      renderer.commands.lastWhere(
        (c) => c['type'] == 'set-obstacle-vectors',
      )['useModels'],
      isTrue,
    );
    expect(provider.status.dataset!.fetchedAtUtc, retrieval);
    await globe.obstacles.setModelsVisible(false);
    expect(
      renderer.commands.lastWhere(
        (c) => c['type'] == 'set-obstacle-vectors',
      )['useModels'],
      isFalse,
    );
  });
  test('hazard controls persist independently, restore after reload and select source obstacles', () async {
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.3,
      'south': 46.6,
      'east': 8.5,
      'north': 46.8,
    });
    await globe.obstacles.setBufferMeters(75);
    await globe.obstacles.setHazardsVisible(true);
    final stored = await preferences.getPreferences();
    expect(stored.hazardAreasVisible, isTrue);
    expect(stored.obstacleBufferMeters, 75);
    expect(stored.obstacleVectorsVisible, isFalse);
    expect(stored.obstacleWmsVisible, isFalse);
    expect(stored.uasZonesVisible, isFalse);
    var command = renderer.commands.lastWhere(
      (c) =>
          c['type'] == 'set-hazard-areas' && (c['features'] as List).isNotEmpty,
    );
    expect(command['bufferMeters'], 75);
    renderer.emit({
      'type': 'obstacle-selected',
      'id': 'source-1',
      'layer': 'hazard',
      'revision': command['revision'],
    });
    expect(globe.obstacles.selected?.id, 'source-1');
    renderer.emit({'type': 'renderer-loading'});
    renderer.sessionId = 'hazard-reload';
    renderer.sequence = 0;
    renderer.ready();
    await pumpEventQueue(times: 20);
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.3,
      'south': 46.6,
      'east': 8.5,
      'north': 46.8,
    });
    await globe.obstacles.updateViewport();
    command = renderer.commands.lastWhere(
      (c) =>
          c['type'] == 'set-hazard-areas' && (c['features'] as List).isNotEmpty,
    );
    expect(command['bufferMeters'], 75);
    await globe.obstacles.setCategory(ObstacleCategory.powerLines, false);
    expect(
      (renderer.commands.lastWhere(
            (c) => c['type'] == 'set-hazard-areas',
          )['features']
          as List),
      isEmpty,
    );
    expect(globe.obstacles.selected, isNull);
    await globe.obstacles.setHazardsVisible(false);
    expect((await preferences.getPreferences()).hazardAreasVisible, isFalse);
    for (final meters in [-1.0, double.nan, double.infinity, 1001.0]) {
      await expectLater(
        globe.obstacles.setBufferMeters(meters),
        throwsArgumentError,
      );
    }
  });
  test('viewport queries, known height conversion, category filtering and selection use current revisions', () async {
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 8.3,
      'south': 46.6,
      'east': 8.5,
      'north': 46.8,
    });
    await globe.obstacles.setVectorsVisible(true);
    final command = renderer.commands.lastWhere(
      (c) =>
          c['type'] == 'set-obstacle-vectors' &&
          (c['features'] as List).isNotEmpty,
    );
    final feature = (command['features'] as List).single as Map;
    final part = (feature['parts'] as List).first as Map;
    expect(part['elevated'], isTrue);
    expect(
      ((part['coordinates'] as List).first as List)[2],
      inInclusiveRange(640, 660),
    );
    renderer.emit({
      'type': 'obstacle-selected',
      'id': 'source-1',
      'revision': command['revision'],
    });
    expect(globe.obstacles.selected?.id, 'source-1');
    expect(globe.selectedPoint, isNull);
    globe.obstacles.clearSelection();
    renderer.emit({
      'type': 'obstacle-selected',
      'id': 'source-1',
      'revision': -1,
    });
    expect(globe.obstacles.selected, isNull);
    await globe.obstacles.setCategory(ObstacleCategory.powerLines, false);
    expect((renderer.commands.last['features'] as List), isEmpty);
    expect(
      (await preferences.getPreferences()).obstacleCategories,
      isNot(contains(ObstacleCategory.powerLines)),
    );
    renderer.emit({
      'type': 'obstacle-viewport',
      'west': 3,
      'south': 44,
      'east': 14,
      'north': 49,
    });
    await globe.obstacles.updateViewport();
    expect(globe.obstacles.vectorStatus, contains('Zoom in'));
    expect(globe.error, isNull);
  });
  test('malformed obstacle settings are recoverable without rewriting unrelated settings', () async {
    for (final pair in {
      'map.obstacles.wms.visible': 'yes',
      'map.obstacles.wms.opacity': 'NaN',
      'map.obstacles.vectors.visible': 'yes',
      'map.obstacles.vectors.models': 'yes',
      'map.obstacles.vectors.categories': '["invalid"]',
    }.entries) {
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: pair.key, value: pair.value),
          );
      await expectLater(preferences.getPreferences(), throwsFormatException);
      await preferences.resetPreferences();
    }
    final defaults = await preferences.getPreferences();
    expect(defaults.obstacleWmsVisible, isFalse);
    expect(defaults.obstacleVectorsVisible, isFalse);
    expect(defaults.obstacleCategories.length, 5);
  });
  testWidgets(
    'model option fits a narrow screen, toggles independently and keeps its value',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => globe.obstacles.setVectorsVisible(true));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: globe.obstacles,
                builder: (_, _) => ObstacleLayersSection(
                  controller: globe.obstacles,
                  enabled: true,
                ),
              ),
            ),
          ),
        ),
      );
      final control = find.widgetWithText(SwitchListTile, '3D obstacle models');
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(globe.obstacles.modelsVisible, isTrue);
      expect(globe.obstacles.wmsVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'obstacle controls and source details fit a narrow screen and expose unknown data plainly',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObstacleLayersSection(
                controller: globe.obstacles,
                enabled: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Published obstacles · WMS'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Published obstacles · WMS'),
      );
      await tester.pumpAndSettle();
      expect(globe.obstacles.wmsVisible, isTrue);
      expect(tester.takeException(), isNull);
      final f = ObstacleFeature(
        id: 'unknown',
        name: 'Unknown fixture',
        attributes: const {'obstacleType': 'FUTURE_TYPE'},
        parts: const [
          ObstaclePart('LineString', 'futureMode', [
            [8.4, 46.7],
            [8.401, 46.701],
          ]),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ObstacleDetailsPanel(
              feature: f,
              snapshot: provider.status.dataset!.data,
              onClose: () {},
            ),
          ),
        ),
      );
      expect(
        find.textContaining(
          'ground marker at first vertex; elevated geometry unavailable',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Approximate geometry:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
