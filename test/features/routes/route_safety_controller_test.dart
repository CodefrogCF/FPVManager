import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/obstacles/obstacle_models.dart';
import 'package:fpvmanager/features/obstacles/swiss_obstacle_provider.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/routes/analysis/route_safety_controller.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis_controller.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis_sheet.dart';
import 'package:fpvmanager/features/routes/analysis/route_safety_tab.dart';
import 'package:fpvmanager/features/routes/analysis/route_energy.dart';
import 'package:fpvmanager/features/routes/route_editor_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/obstacle_fixture.dart';
import '../../helpers/uas_zone_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FpvDatabase db;
  late OsintCacheDatabase cache;
  late SwissUasProvider uas;
  late SwissObstacleProvider obstacles;
  late MockClient uasClient, obstacleClient;
  late GlobeController globe;
  late RouteEditorController editor;
  late RouteSafetyController safety;
  Completer<void>? waitForUas;
  final positions = [
    for (final lon in [8.399, 8.402])
      RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 46.7, longitude: lon),
        height: const AglWaypointHeight(AboveGroundHeight(30)),
      ),
  ];
  setUp(() async {
    waitForUas = null;
    db = FpvDatabase(NativeDatabase.memory());
    cache = OsintCacheDatabase(NativeDatabase.memory());
    final feature = uasFixtureFeature();
    feature['geometry'] = {
      'type': 'Polygon',
      'coordinates': [
        [
          [8.3995, 46.699],
          [8.401, 46.699],
          [8.401, 46.701],
          [8.3995, 46.701],
          [8.3995, 46.699],
        ],
      ],
    };
    uasClient = MockClient((_) async {
      await waitForUas?.future;
      return http.Response(jsonEncode(uasFixtureCollection([feature])), 200);
    });
    uas = SwissUasProvider(client: uasClient);
    obstacleClient = MockClient(
      (r) async => r.url.path.endsWith('/items')
          ? http.Response(jsonEncode(obstacleStac()), 200)
          : http.Response.bytes(obstacleKmz(obstacleKml()), 200),
    );
    obstacles = SwissObstacleProvider(client: obstacleClient, cache: cache);
    await obstacles.fetch();
    globe = GlobeController(uasProvider: uas, obstacleProvider: obstacles);
    FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await globe.initializePreferences(UserPreferencesRepository(db));
    final repo = FlightPlanRepository(db),
        id = await repo.saveRoute(name: 'Route', waypoints: positions);
    editor = RouteEditorController(repository: repo, globe: globe, routeId: id);
    await editor.load();
    safety = RouteSafetyController(editor);
  });
  tearDown(() async {
    safety.dispose();
    editor.dispose();
    globe.dispose();
    await globe.preferencesSettled;
    uas.dispose();
    obstacles.dispose();
    await obstacles.settled;
    uasClient.close();
    obstacleClient.close();
    await cache.close();
    await db.close();
  });
  RouteAnalysis analysis() {
    final p = editor.points.map((p) => p.input).toList(),
        plan = RouteSamplingPlan.create(p);
    return RouteAnalysis.calculate(
      p,
      plan,
      List.filled(plan.samples.length, 600),
      editor.planning,
    );
  }

  test(
    'full segment checks link source records while preserving layer visibility',
    () async {
      await safety.calculate(analysis());
      expect(safety.airspace!.intersections.single.geometry.segmentIndices, {
        0,
      });
      expect(safety.proximity!.hits.single.obstacle.id, 'source-1');
      expect(safety.highlighted, {0});
      expect(globe.uasZonesVisible, isFalse);
      expect(globe.obstacles.vectorsVisible, isFalse);
      expect(globe.obstacles.hazardsVisible, isFalse);
      await globe.obstacles.setCategory(ObstacleCategory.powerLines, false);
      expect(safety.hasResult, isFalse);
      await safety.calculate(analysis());
      expect(safety.proximity!.hits, isEmpty);
      await globe.obstacles.setBufferMeters(100);
      expect(safety.hasResult, isFalse);
      await safety.calculate(analysis());
      expect(safety.hasResult, isTrue);
      await obstacles.fetch(forceRefresh: true);
      expect(safety.hasResult, isFalse);
    },
  );
  testWidgets(
    'checks and constraint controls fit a narrow display and invalidate results on apply',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = RouteAnalysisController(editor);
      addTearDown(c.dispose);
      c.result = analysis();
      c.energy = RouteEnergyEstimate.calculate(c.result!, editor.planning);
      await tester.runAsync(() => c.safety.calculate(c.result!));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRouteAnalysis(context, c),
                child: const Text('Open analysis'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open analysis'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Checks'));
      await tester.tap(find.text('Checks'));
      await tester.pumpAndSettle();
      final reviewScroll = find.descendant(
        of: find.byType(RouteSafetyTab),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Horizontal obstacle proximity'),
        200,
        scrollable: reviewScroll,
      );
      await tester.scrollUntilVisible(
        find.text('Manual verification required'),
        200,
        scrollable: reviewScroll,
      );
      expect(find.text('Manual verification required'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Configure constraints'),
        -300,
        scrollable: reviewScroll,
      );
      await tester.tap(find.text('Configure constraints'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Operational ceiling (m AGL)'),
        '90',
      );
      await tester.ensureVisible(find.text('Apply route constraints'));
      await tester.tap(find.text('Apply route constraints'));
      await tester.pumpAndSettle();
      expect(editor.planning.constraints.operationalCeilingAgl, 90);
      expect(c.safety.hasResult, isFalse);
      expect(c.result, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  test('infrastructure checks are optional and changing drone size invalidates results', () async {
    expect(safety.infrastructureEnabled, isFalse);
    await safety.calculate(analysis());
    expect(safety.infrastructure, isNull);
    safety.setInfrastructureEnabled(true);
    expect(safety.infrastructureEnabled, isTrue);
    expect(safety.hasResult, isFalse);
    safety.setDroneRadiusMeters(.5);
    expect(safety.droneRadiusMeters, .5);
    expect(() => safety.setDroneRadiusMeters(0), throwsArgumentError);
    safety.setInfrastructureEnabled(false);
    expect(safety.infrastructure, isNull);
  });

  test('dense saved route retains late cable findings and the full profile for local 3D checks', () async {
    safety.dispose();
    editor.dispose();
    final repo = FlightPlanRepository(db);
    final route = [
      for (var i = 0; i < 1000; i++)
        RouteWaypointInput(
          position: Wgs84Coordinate(
            latitude: 46.7,
            longitude: 8.38801 + .000012 * i,
          ),
          height: const AglWaypointHeight(AboveGroundHeight(30)),
        ),
    ];
    final id = await repo.saveRoute(
      name: 'Cable at the end of the route',
      waypoints: route,
    );
    editor = RouteEditorController(repository: repo, globe: globe, routeId: id);
    await editor.load();
    final peer = FakeGlobeRenderer(globe)
      ..sessionId = 'long-route-renderer'
      ..attach()
      ..ready();
    peer.autoAcknowledge = false;
    peer.onCommand = (c) => peer.acknowledge(
      c,
      result: c['type'] == 'query-infrastructure-clearance'
          ? {
              'findings': [],
              'checkedSamples': 999,
              'unknownHeightSamples': 0,
              'modelCount': 1,
              'incomplete': true,
              'processingLimited': false,
              'coverage': 'local-models-only',
              'message': 'Local model fixture',
            }
          : {},
    );
    safety = RouteSafetyController(editor)..setInfrastructureEnabled(true);
    await safety.calculate(analysis());
    expect(safety.proximity!.hits.last.segment, 998);
    final query = peer.commands.singleWhere(
      (c) => c['type'] == 'query-infrastructure-clearance',
    );
    final profile = query['samples'] as List;
    expect(profile.length, 1000);
    expect((profile.last as Map)['segment'], 998);
    expect((profile.last as Map)['longitude'], route.last.position.longitude);
    expect(safety.infrastructure!.processingLimited, isFalse);
  });

  testWidgets('checks tab exposes infrastructure opt-in and model disclaimer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = RouteAnalysisController(editor);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RouteSafetyTab(controller: c)),
      ),
    );
    final scroll = find.descendant(
      of: find.byType(RouteSafetyTab),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('3D Infrastructure Clearance (advisory)'),
      200,
      scrollable: scroll,
    );
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Assess modeled bridges, supports and tunnel walls',
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(c.safety.infrastructureEnabled, isTrue);
    expect(
      find.textContaining('3D Tiles alone do not prove clearance.'),
      findsWidgets,
    );
  });

  test('route edits and cancellation reject late source replies', () async {
    waitForUas = Completer<void>();
    final pending = safety.calculate(analysis());
    await pumpEventQueue(times: 10);
    expect(safety.loading, isTrue);
    editor.configurePoint(
      editor.points.first.key,
      height: const AglWaypointHeight(AboveGroundHeight(80)),
    );
    expect(safety.loading, isFalse);
    waitForUas!.complete();
    await pending;
    expect(safety.hasResult, isFalse);
    expect(safety.highlighted, isEmpty);
    await safety.calculate(analysis());
    expect(safety.hasResult, isTrue);
    safety.cancel();
    expect(safety.airspace, isNull);
    expect(safety.proximity, isNull);
  });
}
