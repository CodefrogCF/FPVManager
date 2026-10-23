import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_screen.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'route equipment menu assigns existing drone and individual packs',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FlightPlanRepository(db);
      final drone = await DroneRepository(db).createDrone(name: 'Cinewhoop');
      final pack = await BatteryRepository(db)
          .createBattery(name: 'Pack 01', cellCount: 6, capacityMah: 1300);
      final id = await repo.createFlightPlan(name: 'Equipment plan');
      final globe = GlobeController();
      addTearDown(globe.dispose);
      FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteEditorScreen(
            repository: repo,
            routeId: id,
            globeController: globe,
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Route options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Route equipment'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinewhoop').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pack 01'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply equipment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final route = (await repo.getRoute(id))!;
      expect(route.plan.droneId, drone);
      expect(route.batteryIds, {pack});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'compact editor configures all points and shows analysis tabs on a narrow display',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FlightPlanRepository(db);
      final id = await repo.createFlightPlan(
        name: 'New plan',
        waypoints: [
          for (final lon in [8.0, 8.001])
            RouteWaypointInput(
              position: Wgs84Coordinate(latitude: 47, longitude: lon),
            ),
        ],
      );
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final renderer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      renderer.onCommand = (c) {
        if (c['type'] == 'query-route-terrain') {
          renderer.acknowledge(
            c,
            result: {
              'heightReference': 'wgs84Ellipsoid',
              'samplingMethod': 'most-detailed',
              'heights': List.filled((c['positions'] as List).length, 100),
            },
          );
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          home: RouteEditorScreen(
            repository: repo,
            routeId: id,
            globeController: globe,
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = renderer.commands.lastWhere(
        (c) => c['type'] == 'set-route-editor',
      );
      renderer.emit({
        'type': 'route-map-action',
        'editorId': state['editorId'],
        'revision': state['revision'],
        'action': 'select',
        'id': 1,
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Waypoint actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Height & speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Above terrain (AGL)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height (m)'),
        '50',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Outgoing airspeed (m/s)'),
        '10',
      );
      await tester.ensureVisible(
        find.text('Apply height and speed to all waypoints'),
      );
      await tester.tap(find.text('Apply height and speed to all waypoints'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply waypoint settings'));
      await tester.tap(find.text('Apply waypoint settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final route = (await repo.getRoute(id))!;
      expect(
        route.waypoints.every(
          (p) => p.height!.meters == 50 && p.speedMetersPerSecond == 10,
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Route analysis'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum sampled terrain clearance'), findsOneWidget);
      expect(find.text('50.0 m'), findsOneWidget);
      await tester.tap(find.text('Flight'));
      await tester.pumpAndSettle();
      expect(find.text('Estimated flight duration'), findsOneWidget);
      await tester.tap(find.text('Energy'));
      await tester.pumpAndSettle();
      expect(find.text('Estimated outbound energy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test('planning assumptions persist with the route rather than becoming global defaults', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FlightPlanRepository(db);
    const settings = RoutePlanningSettings(
      useWind: true,
      windSpeed: 4,
      windFromDegrees: 90,
      reservePercent: 35,
      referenceMassGrams: 700,
      flightMassGrams: 800,
      powerCurve: [PowerCurvePoint(0, 150), PowerCurvePoint(20, 300)],
      curveSource: 'Measured level flight at 700 g',
    );
    final id = await repo.saveRoute(
      name: 'Configured',
      planning: settings,
      waypoints: [],
    );
    await repo.saveRoute(id: id, name: 'Renamed', waypoints: []);
    final stored = RoutePlanningSettings.decode(
      (await repo.getRoute(id))!.plan.planningJson,
    );
    expect(stored.windSpeed, 4);
    expect(stored.reservePercent, 35);
    expect(stored.powerCurve.last.watts, 300);
    final other = await repo.saveRoute(name: 'Other', waypoints: []);
    expect(
      RoutePlanningSettings.decode(
        (await repo.getRoute(other))!.plan.planningJson,
      ).useWind,
      isFalse,
    );
  });
}
