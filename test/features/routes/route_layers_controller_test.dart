import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_layers_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late FlightPlanRepository repository;
  late GlobeController globe;
  late _FailingRenderer peer;
  RouteLayersController? layers;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repository = FlightPlanRepository(db);
    globe = GlobeController();
    peer = _FailingRenderer(globe)
      ..attach()
      ..ready();
  });
  tearDown(() async {
    layers?.dispose();
    await layers?.settled;
    globe.dispose();
    await db.close();
  });
  Future<void> until(bool Function() condition) async {
    final end = DateTime.now().add(const Duration(seconds: 4));
    while (!condition() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue);
  }

  const points = [
    RouteWaypointInput(
      position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
      height: AglWaypointHeight(AboveGroundHeight(80)),
    ),
  ];
  Map<String, dynamic> getState() =>
      peer.commands.lastWhere((c) => c['type'] == 'set-visible-routes');

  test('selected routes stay displayed during ego mode, update live and preserve stored heights', () async {
    final a = await repository.createFlightPlan(
      name: 'Route A',
      waypoints: points,
    );
    final b = await repository.createFlightPlan(
      name: 'Route B',
      waypoints: points,
    );
    final controller = layers = RouteLayersController(
      repository: repository,
      globe: globe,
    );
    controller.select(a, true);
    controller.select(b, true);
    await until(
      () => peer.commands.any(
        (c) =>
            c['type'] == 'set-visible-routes' &&
            (c['routes'] as List).length == 2,
      ),
    );
    await controller.settled;
    expect((getState()['routes'] as List).map((r) => r['id']).toSet(), {a, b});
    expect(
      (getState()['routes'] as List).first['waypoints'][0].containsKey(
        'heightMeters',
      ),
      isFalse,
    );
    peer.emit({'type': 'ground-view-state', 'active': true, 'pending': false});
    final before = peer.commands.length;
    await repository.updateFlightPlan(id: a, name: 'Renamed A');
    await until(
      () => peer.commands
          .skip(before)
          .any(
            (c) =>
                c['type'] == 'set-visible-routes' &&
                (c['routes'] as List).any((r) => r['name'] == 'Renamed A'),
          ),
    );
    expect(globe.groundViewActive, isTrue);
    expect(
      peer.commands.skip(before).any((c) => c['type'] == 'exit-ground-view'),
      isFalse,
    );
    expect((await repository.getRoute(a))!.waypoints.single.height!.meters, 80);
    controller.select(b, false);
    await controller.settled;
    expect((getState()['routes'] as List).single['id'], a);
    await repository.deleteFlightPlan(a);
    await until(() => controller.selectedIds.isEmpty);
    await controller.settled;
    expect(getState()['routes'], isEmpty);
  });

  test('renderer reload restores visible routes and source data remains caller owned', () async {
    final id = await repository.createFlightPlan(
      name: 'Restore',
      waypoints: points,
    );
    final controller = layers = RouteLayersController(
      repository: repository,
      globe: globe,
    );
    controller.select(id, true);
    await until(
      () => peer.commands.any((c) => c['type'] == 'set-visible-routes'),
    );
    await controller.settled;
    peer.emit({'type': 'renderer-loading'});
    peer.sessionId = 'reloaded';
    peer.ready();
    await until(
      () => peer.commands.any(
        (c) =>
            c['sessionId'] == 'reloaded' && c['type'] == 'set-visible-routes',
      ),
    );
    expect((getState()['routes'] as List).single['id'], id);
    controller.dispose();
    await controller.settled;
    layers = null;
    expect((await repository.getRoute(id))!.plan.name, 'Restore');
  });

  test('deselecting does not wait for stalled rendering and a late failure cannot overwrite recovery', () async {
    final id = await repository.createFlightPlan(
      name: 'Pending',
      waypoints: points,
    );
    peer.autoAcknowledge = false;
    final controller = layers = RouteLayersController(
      repository: repository,
      globe: globe,
    );
    controller.select(id, true);
    await until(
      () => peer.commands.any((c) => c['type'] == 'set-visible-routes'),
    );
    final original = getState();
    controller.select(id, false);
    await until(
      () =>
          peer.commands
              .where((c) => c['type'] == 'set-visible-routes')
              .length ==
          2,
    );
    expect(getState()['routes'], isEmpty);
    peer.acknowledge(getState());
    peer.acknowledge(original, error: 'Late superseded error');
    await controller.settled;
    expect(controller.error, isNull);
    expect(controller.selectedIds, isEmpty);
  });

  test(
    'route read and renderer failures retain selection and recover on retry',
    () async {
      final id = await repository.createFlightPlan(
        name: 'Recover',
        waypoints: points,
      );
      final flaky = _ReadFailureRepository(repository);
      final controller = layers = RouteLayersController(
        repository: flaky,
        globe: globe,
      );
      controller.select(id, true);
      await until(() => controller.error != null);
      expect(controller.selectedIds, {id});
      peer.failRoutes = true;
      await controller.retry();
      await until(() => controller.error?.contains('display') == true);
      peer.failRoutes = false;
      await controller.retry();
      await until(
        () =>
            controller.error == null &&
            (getState()['routes'] as List).isNotEmpty,
      );
      await controller.settled;
      expect(controller.selectedIds, {id});
    },
  );
}

class _FailingRenderer extends FakeGlobeRenderer {
  _FailingRenderer(super.controller);
  bool failRoutes = false;
  @override
  void acknowledge(
    Map<String, dynamic> command, {
    Map<String, dynamic> result = const {},
    String? error,
  }) => super.acknowledge(
    command,
    result: result,
    error: failRoutes && command['type'] == 'set-visible-routes'
        ? 'Fixture renderer failure'
        : error,
  );
}

class _ReadFailureRepository implements FlightPlanRepository {
  _ReadFailureRepository(this.delegate);
  final FlightPlanRepository delegate;
  bool fail = true;
  @override
  Stream<FlightRoute?> watchRoute(int id) {
    if (fail) {
      fail = false;
      return Stream.error(StateError('Fixture read failure'));
    }
    return delegate.watchRoute(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
