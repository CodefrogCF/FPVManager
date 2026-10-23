import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_screen.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'a failed initial load blocks edits and explicit retry recovers the stored route',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final globe = GlobeController();
      addTearDown(globe.dispose);
      FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteEditorScreen(
            repository: FlightPlanRepository(db),
            routeId: 999,
            globeController: globe,
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load this route. Please retry.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await db.customStatement(
        "INSERT INTO flight_plans (id, name) VALUES (999, 'Recovered route')",
      );
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Recovered route'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(find.text('Retry loading'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'narrow editor supports selection, move/delete/undo and keeps controls usable with a keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final id = await repository.createFlightPlan(
        name: 'Route',
        waypoints: [
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
          ),
        ],
      );
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteEditorScreen(
            repository: repository,
            routeId: id,
            globeController: globe,
            mapBuilder: (_) => const ColoredBox(color: Colors.blueGrey),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = peer.commands.lastWhere(
        (c) => c['type'] == 'set-route-editor',
      );
      peer.emit({
        'type': 'route-map-action',
        'editorId': state['editorId'],
        'revision': state['revision'],
        'action': 'select',
        'id': 1,
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Waypoint actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move point'));
      await tester.pumpAndSettle();
      expect(find.text('Click the new position on the map.'), findsOneWidget);
      await tester.tap(find.byTooltip('Waypoint actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel move'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Waypoint actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete point'));
      await tester.pumpAndSettle();
      expect(find.text('0 waypoints'), findsOneWidget);
      await tester.tap(find.byTooltip('Undo waypoint change'));
      await tester.pumpAndSettle();
      expect(find.text('1 waypoints'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed route');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await repository.getRoute(id))!.plan.name, 'Renamed route');
      expect(find.text('Route saved locally'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('back protects unsaved draft and keep editing retains points', (
    tester,
  ) async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await tester.pumpWidget(
      MaterialApp(
        home: RouteEditorScreen(
          repository: FlightPlanRepository(db),
          globeController: globe,
          mapBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = peer.commands.lastWhere(
      (c) => c['type'] == 'set-route-editor',
    );
    peer.emit({
      'type': 'route-map-action',
      'editorId': state['editorId'],
      'revision': state['revision'],
      'action': 'add',
      'latitude': 46.7,
      'longitude': 8.4,
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard route changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('1 waypoints'), findsOneWidget);
    expect(find.textContaining('Waypoint 1 ·'), findsOneWidget);
    expect((await FlightPlanRepository(db).getAllFlightPlans()), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
