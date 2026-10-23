import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_controller.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late GlobeController globe;
  late FakeGlobeRenderer renderer;
  late RouteEditorController editor;
  late RouteAnalysisController analysis;
  setUp(() async {
    db = FpvDatabase(NativeDatabase.memory());
    final repo = FlightPlanRepository(db);
    final id = await repo.createFlightPlan(
      name: 'Test route',
      waypoints: [
        for (final lon in [8.0, 8.001])
          RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 47, longitude: lon),
            height: const AglWaypointHeight(AboveGroundHeight(50)),
            speedMetersPerSecond: 10,
          ),
      ],
    );
    globe = GlobeController();
    renderer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    editor = RouteEditorController(repository: repo, globe: globe, routeId: id);
    await editor.load();
    analysis = RouteAnalysisController(editor);
  });
  tearDown(() async {
    analysis.dispose();
    editor.dispose();
    globe.dispose();
    await db.close();
  });
  Future<Map<String, dynamic>> nextQuery(Future<void> Function() start) async {
    final command = Completer<Map<String, dynamic>>();
    renderer.onCommand = (c) {
      if (c['type'] == 'query-route-terrain' && !command.isCompleted) {
        command.complete(c);
      }
    };
    unawaited(start());
    return command.future.timeout(const Duration(seconds: 15));
  }

  Map<String, dynamic> heights(Map<String, dynamic> command) => {
    'heightReference': 'wgs84Ellipsoid',
    'samplingMethod': 'most-detailed',
    'heights': List.filled((command['positions'] as List).length, 100),
  };
  test(
    'profile results invalidate on edits and late replies cannot restore them',
    () async {
      Future<void>? pending;
      final command = await nextQuery(() => pending = analysis.calculate());
      editor.configurePoint(
        editor.points.first.key,
        height: const AglWaypointHeight(AboveGroundHeight(80)),
        speedMetersPerSecond: 10,
      );
      expect(analysis.loading, isFalse);
      renderer.acknowledge(command, result: heights(command));
      await pending;
      expect(analysis.result, isNull);
      final retry = await nextQuery(() => pending = analysis.calculate());
      renderer.acknowledge(retry, result: heights(retry));
      await pending;
      expect(analysis.result!.minimumClearance, 50);
      expect(
        analysis.result!.climb,
        0,
      ); // First waypoint is now higher: the route descends.
      expect(analysis.result!.descent, 30);
    },
  );
  test(
    'terrain failures retain horizontal analysis without fabricating clearance',
    () async {
      Future<void>? pending;
      final command = await nextQuery(() => pending = analysis.calculate());
      renderer.acknowledge(command, error: 'Terrain network failure');
      await pending;
      expect(analysis.result!.horizontalDistance, greaterThan(0));
      expect(analysis.result!.minimumClearance, isNull);
      expect(analysis.result!.terrainAvailable, isFalse);
      expect(analysis.terrainError, isNotNull);
      expect(analysis.energy!.available, isFalse);
    },
  );
  test('renderer replacement and explicit cancellation invalidate in-flight sampling', () async {
    Future<void>? pending;
    final command = await nextQuery(() => pending = analysis.calculate());
    analysis.cancel();
    renderer.acknowledge(command, result: heights(command));
    await pending;
    expect(analysis.result, isNull);
    final retry = await nextQuery(() => pending = analysis.calculate());
    renderer.acknowledge(retry, result: heights(retry));
    await pending;
    expect(analysis.result, isNotNull);
    renderer.sessionId = 'replacement';
    renderer.attach();
    renderer.ready();
    expect(analysis.result, isNull);
  });
  test(
    'wrong terrain references and incomplete batches are rejected',
    () async {
      final command = Completer<Map<String, dynamic>>();
      renderer.onCommand = (c) {
        if (c['type'] == 'query-route-terrain') command.complete(c);
      };
      final request = globe.queryRouteTerrain([editor.points.first.position]);
      final c = await command.future;
      renderer.acknowledge(
        c,
        result: {
          'heightReference': 'ln02',
          'samplingMethod': 'most-detailed',
          'heights': [100],
        },
      );
      await expectLater(request, throwsFormatException);
    },
  );
}
