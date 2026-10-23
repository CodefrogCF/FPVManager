import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late FlightPlanRepository repository;
  late GlobeController globe;
  late FakeGlobeRenderer peer;
  RouteEditorController? editor;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repository = FlightPlanRepository(db);
    globe = GlobeController();
    peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
  });
  tearDown(() async {
    editor?.dispose();
    editor = null;
    globe.dispose();
    await db.close();
  });
  Future<void> action(
    String action, {
    int? id,
    double lat = 46.7,
    double lon = 8.4,
    Map<String, dynamic>? envelope,
  }) async {
    final state =
        envelope ??
        peer.commands.lastWhere((c) => c['type'] == 'set-route-editor');
    peer.emit({
      'type': 'route-map-action',
      'editorId': state['editorId'],
      'revision': state['revision'],
      'action': action,
      'id': ?id,
      'latitude': lat,
      'longitude': lon,
    });
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'map edits, undo and two independent locally saved routes round trip',
    () async {
      final draft = editor = RouteEditorController(
        repository: repository,
        globe: globe,
      );
      await draft.load();
      draft.rename('Ridge route');
      await action('add');
      final first = draft.points.single.key;
      await action('add', lat: 46.71);
      final second = draft.points.last.key;
      await action('move', id: first, lat: 46.72, lon: 8.41);
      expect(draft.points.first.position.latitude, 46.72);
      await action('delete', id: second);
      expect(draft.points.length, 1);
      draft.undo();
      expect(draft.points.length, 2);
      expect(await draft.save(), isTrue);
      final firstId = draft.routeId!;
      expect(draft.dirty, isFalse);
      draft.dispose();
      editor = null;
      final other = editor = RouteEditorController(
        repository: repository,
        globe: globe,
      );
      await other.load();
      other.rename('Valley route');
      await action('add', lat: 46.6);
      expect(await other.save(), isTrue);
      expect((await repository.getAllFlightPlans()).map((p) => p.name), [
        'Valley route',
        'Ridge route',
      ]);
      expect((await repository.getRoute(firstId))!.waypoints.length, 2);
      expect(
        (await repository.getRoute(firstId))!.waypoints.first.position.latitude,
        46.72,
      );
      await action('delete', id: other.points.single.key);
      expect(other.canSave, isTrue);
      expect(await other.save(), isTrue);
      expect((await repository.getRoute(other.routeId!))!.waypoints, isEmpty);
    },
  );

  test(
    'moving preserves stored height semantics, metadata and plan identity',
    () async {
      final drone = await DroneRepository(db).createDrone(name: 'Drone');
      final id = await repository.createFlightPlan(
        name: 'Existing',
        droneId: drone,
        notes: 'Keep this',
        waypoints: [
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
            height: AglWaypointHeight(AboveGroundHeight(35)),
          ),
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.71, longitude: 8.41),
            height: AbsoluteWaypointHeight(
              ReferencedElevation(
                meters: 1700,
                reference: VerticalReference.ln02,
              ),
            ),
          ),
        ],
      );
      final draft = editor = RouteEditorController(
        repository: repository,
        globe: globe,
        routeId: id,
      );
      await draft.load();
      await action('move', id: draft.points.first.key, lat: 46.73);
      draft.rename('Changed');
      expect(await draft.save(), isTrue);
      final stored = (await repository.getRoute(id))!;
      expect(stored.plan.name, 'Changed');
      expect(stored.plan.droneId, drone);
      expect(stored.plan.notes, 'Keep this');
      expect(stored.waypoints.first.height, isA<AglWaypointHeight>());
      expect(stored.waypoints.first.height!.meters, 35);
      expect(
        (stored.waypoints.last.height as AbsoluteWaypointHeight)
            .elevation
            .reference,
        VerticalReference.ln02,
      );
    },
  );

  test('failed save rolls back name and all waypoints and retains the editable draft for retry', () async {
    final id = await repository.createFlightPlan(
      name: 'Original',
      waypoints: [
        const RouteWaypointInput(
          position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
        ),
      ],
    );
    final draft = editor = RouteEditorController(
      repository: repository,
      globe: globe,
      routeId: id,
    );
    await draft.load();
    draft.rename('Modified');
    await action('add', lat: 46.8);
    await db.customStatement(
      "CREATE TRIGGER fail_route BEFORE INSERT ON flight_waypoints BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    expect(await draft.save(), isFalse);
    expect(draft.points.length, 2);
    expect(draft.dirty, isTrue);
    final original = (await repository.getRoute(id))!;
    expect(original.plan.name, 'Original');
    expect(original.waypoints.length, 1);
    await db.customStatement('DROP TRIGGER fail_route');
    expect(await draft.save(), isTrue);
    expect((await repository.getRoute(id))!.waypoints.length, 2);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('stale or invalid map events are ignored and renderer reload restores the unsaved draft', () async {
    final draft = editor = RouteEditorController(
      repository: repository,
      globe: globe,
    );
    await draft.load();
    final old = peer.commands.last;
    await action('add');
    await action('add', envelope: old);
    await action('move', id: 999);
    await action('add', lat: 91);
    expect(draft.points.length, 1);
    globe.rendererLoading();
    peer.sessionId = 'renderer-2';
    peer.ready();
    await Future<void>.delayed(Duration.zero);
    expect(
      (peer.commands.lastWhere(
                (c) => c['type'] == 'set-route-editor',
              )['waypoints']
              as List)
          .length,
      1,
    );
    expect(draft.dirty, isTrue);
    await action('add', lat: 46.8);
    expect(draft.points.length, 2);
  });
}
