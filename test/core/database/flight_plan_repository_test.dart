import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

const position = Wgs84Coordinate(latitude: 47, longitude: 8);
const positionOnly = RouteWaypointInput(position: position);
const absolute = RouteWaypointInput(
  position: position,
  height: AbsoluteWaypointHeight(
    ReferencedElevation(meters: -5, reference: VerticalReference.ln02),
  ),
);
const agl = RouteWaypointInput(
  position: position,
  height: AglWaypointHeight(AboveGroundHeight(50)),
);

void main() {
  late FpvDatabase database;
  late FlightPlanRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = FlightPlanRepository(database);
  });
  tearDown(() => database.close());

  test(
    'typed route round trip retains references, order and metadata',
    () async {
      final droneId = await DroneRepository(database)
          .createDrone(name: 'Drone');
      final spotId = await SpotRepository(database)
          .createSpot(name: 'Start', latitude: 47, longitude: 8);
      final id = await repository.createFlightPlan(
        name: ' Survey ',
        droneId: droneId,
        startSpotId: spotId,
        notes: 'Plan notes',
        waypoints: [positionOnly, absolute, agl],
      );
      final route = (await repository.getRoute(id))!;
      expect(route.plan.name, 'Survey');
      expect(route.plan.droneId, droneId);
      expect(route.plan.startSpotId, spotId);
      expect(route.plan.notes, 'Plan notes');
      expect(route.waypoints.map((point) => point.sequenceNumber), [0, 1, 2]);
      expect(route.waypoints.every((point) => point.planId == id), isTrue);
      expect(route.waypoints.first.position.latitude, 47);
      expect(route.waypoints.first.position.longitude, 8);
      expect(route.waypoints.first.height, isNull);
      final height = route.waypoints[1].height as AbsoluteWaypointHeight;
      expect(height.elevation.reference, VerticalReference.ln02);
      expect(height.meters, -5);
      expect((route.waypoints[2].height as AglWaypointHeight).meters, 50);
      final stored = await database.select(database.flightWaypoints).get();
      expect(stored[2].heightReference, 'unverified');
      expect(stored[2].altitudeMode, 'aboveGroundLevel');
      expect(() => route.waypoints.clear(), throwsUnsupportedError);
      final newer = await repository.createFlightPlan(name: 'Empty');
      expect((await repository.getRoute(newer))!.waypoints, isEmpty);
      expect((await repository.getAllFlightPlans()).map((plan) => plan.id), [
        newer,
        id,
      ]);
    },
  );

  test(
    'full metadata update clears optional fields and preserves the route',
    () async {
      final droneId = await DroneRepository(database)
          .createDrone(name: 'Drone');
      final id = await repository.createFlightPlan(
        name: 'Original',
        droneId: droneId,
        notes: 'Notes',
        waypoints: [agl],
      );
      final createdAt = (await repository.getFlightPlan(id))!.createdAt;
      expect(
        await repository.updateFlightPlan(id: id, name: ' Updated '),
        isTrue,
      );
      final route = (await repository.getRoute(id))!;
      expect(route.plan.name, 'Updated');
      expect(route.plan.droneId, isNull);
      expect(route.plan.notes, isNull);
      expect(route.plan.createdAt, createdAt);
      expect(route.waypoints.single.height!.meters, 50);
      expect(
        await repository.updateFlightPlan(id: 999, name: 'Missing'),
        isFalse,
      );
      expect(await repository.getFlightPlan(999), isNull);
      expect(await repository.getRoute(999), isNull);
      expect(
        await repository.replaceWaypoints(planId: 999, waypoints: [agl]),
        isFalse,
      );
      expect(await repository.deleteFlightPlan(999), 0);
    },
  );

  test(
    'legacy unverified absolute heights are never promoted to a datum',
    () async {
      final id = await repository.createFlightPlan(name: 'Legacy');
      await database
          .into(database.flightWaypoints)
          .insert(
            FlightWaypointsCompanion.insert(
              planId: id,
              sequenceNumber: 0,
              latitude: 47,
              longitude: 8,
              heightMeters: const Value(800),
            ),
          );
      final height =
          (await repository.getRoute(id))!.waypoints.single.height
              as AbsoluteWaypointHeight;
      expect(height.elevation.reference, VerticalReference.unverified);
      expect(height.meters, 800);
      await repository.replaceWaypoints(
        planId: id,
        waypoints: [RouteWaypointInput(position: position, height: height)],
      );
      expect(
        (await database.select(database.flightWaypoints).get())
            .single
            .heightReference,
        'unverified',
      );
    },
  );

  test('invalid input leaves existing waypoints unchanged', () async {
    final id = await repository.createFlightPlan(
      name: 'Original',
      waypoints: [agl],
    );
    final invalidPoints = [
      const RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 91, longitude: 8),
      ),
      const RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 47, longitude: double.nan),
      ),
      const RouteWaypointInput(
        position: position,
        height: AglWaypointHeight(AboveGroundHeight(-1)),
      ),
      const RouteWaypointInput(
        position: position,
        height: AbsoluteWaypointHeight(
          ReferencedElevation(
            meters: double.infinity,
            reference: VerticalReference.wgs84Ellipsoid,
          ),
        ),
      ),
    ];
    for (final point in invalidPoints) {
      await expectLater(
        () => repository.replaceWaypoints(
          planId: id,
          waypoints: [positionOnly, point],
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => repository.createFlightPlan(name: 'Invalid', waypoints: [point]),
        throwsArgumentError,
      );
      expect(
        (await repository.getRoute(id))!.waypoints.single.height!.meters,
        50,
      );
    }
    for (final operation in <Future<Object?> Function()>[
      () => repository.createFlightPlan(name: ' '),
      () => repository.createFlightPlan(name: 'Plan', droneId: 0),
      () => repository.updateFlightPlan(id: id, name: 'Plan', startSpotId: -1),
      () => repository.getRoute(0),
      () => repository.deleteFlightPlan(0),
    ]) {
      await expectLater(operation, throwsArgumentError);
    }
    expect(await repository.getAllFlightPlans(), hasLength(1));
  });

  test(
    'database failure rolls back parent creation and waypoint replacement',
    () async {
      final id = await repository.createFlightPlan(
        name: 'Original',
        waypoints: [agl],
      );
      await database.customStatement('''
      CREATE TRIGGER reject_test_waypoint BEFORE INSERT ON flight_waypoints
      WHEN NEW.longitude = 9 BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
      const rejected = RouteWaypointInput(
        position: Wgs84Coordinate(latitude: 47, longitude: 9),
      );
      await expectLater(
        () => repository.createFlightPlan(
          name: 'Must roll back',
          waypoints: [positionOnly, rejected],
        ),
        throwsException,
      );
      expect(await repository.getAllFlightPlans(), hasLength(1));
      await expectLater(
        () => repository.replaceWaypoints(
          planId: id,
          waypoints: [positionOnly, rejected],
        ),
        throwsException,
      );
      expect(
        (await repository.getRoute(id))!.waypoints.single.height!.meters,
        50,
      );
      expect(
        await database.select(database.flightWaypoints).get(),
        hasLength(1),
      );
    },
  );

  test('invalid foreign keys cannot create or change a plan', () async {
    await expectLater(
      () => repository.createFlightPlan(
        name: 'Missing drone',
        droneId: 999,
        waypoints: [agl],
      ),
      throwsException,
    );
    expect(await repository.getAllFlightPlans(), isEmpty);
    final id = await repository.createFlightPlan(name: 'Original');
    await expectLater(
      () => repository.updateFlightPlan(
        id: id,
        name: 'Changed',
        startSpotId: 999,
      ),
      throwsException,
    );
    expect((await repository.getFlightPlan(id))!.name, 'Original');
  });

  test(
    'deleting linked drone and spot preserves plan; deleting plan cascades',
    () async {
      final drones = DroneRepository(database);
      final spots = SpotRepository(database);
      final droneId = await drones.createDrone(name: 'Drone');
      final spotId = await spots.createSpot(
        name: 'Start',
        latitude: 47,
        longitude: 8,
      );
      final id = await repository.createFlightPlan(
        name: 'Plan',
        droneId: droneId,
        startSpotId: spotId,
        waypoints: [agl],
      );
      await drones.deleteDrone(droneId);
      await spots.deleteSpot(spotId);
      final route = (await repository.getRoute(id))!;
      expect(route.plan.droneId, isNull);
      expect(route.plan.startSpotId, isNull);
      expect(route.waypoints, hasLength(1));
      expect(await repository.deleteFlightPlan(id), 1);
      expect(await repository.getRoute(id), isNull);
      expect(await database.select(database.flightWaypoints).get(), isEmpty);
    },
  );

  test(
    'route stream observes complete child replacements and parent deletion',
    () async {
      final id = await repository.createFlightPlan(
        name: 'Route',
        waypoints: [agl],
      );
      final queue = StreamIterator(repository.watchRoute(id));
      addTearDown(queue.cancel);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current!.waypoints, hasLength(1));
      await repository.replaceWaypoints(
        planId: id,
        waypoints: [positionOnly, absolute, agl],
      );
      expect(await queue.moveNext(), isTrue);
      expect(queue.current!.waypoints, hasLength(3));
      await repository.replaceWaypoints(planId: id, waypoints: []);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current!.waypoints, isEmpty);
      await repository.deleteFlightPlan(id);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, isNull);
    },
  );

  test('plan stream observes metadata changes', () async {
    final queue = StreamIterator(repository.watchFlightPlans());
    addTearDown(queue.cancel);
    expect(await queue.moveNext(), isTrue);
    expect(queue.current, isEmpty);
    final id = await repository.createFlightPlan(name: 'Created');
    expect(await queue.moveNext(), isTrue);
    expect(queue.current.single.id, id);
    await repository.updateFlightPlan(id: id, name: 'Updated');
    expect(await queue.moveNext(), isTrue);
    expect(queue.current.single.name, 'Updated');
  });

  test('malformed stored height metadata fails instead of guessing', () async {
    final id = await repository.createFlightPlan(
      name: 'Route',
      waypoints: [agl],
    );
    for (final companion in [
      const FlightWaypointsCompanion(
        heightMeters: Value(50),
        altitudeMode: Value('unknown'),
        heightReference: Value('unverified'),
      ),
      const FlightWaypointsCompanion(
        heightMeters: Value(50),
        altitudeMode: Value('absolute'),
        heightReference: Value('unknown'),
      ),
      const FlightWaypointsCompanion(
        heightMeters: Value(50),
        altitudeMode: Value('aboveGroundLevel'),
        heightReference: Value('ln02'),
      ),
      const FlightWaypointsCompanion(
        heightMeters: Value(-1),
        altitudeMode: Value('aboveGroundLevel'),
        heightReference: Value('unverified'),
      ),
      const FlightWaypointsCompanion(
        heightMeters: Value(null),
        altitudeMode: Value('absolute'),
        heightReference: Value('ln02'),
      ),
    ]) {
      await database.update(database.flightWaypoints).write(companion);
      await expectLater(() => repository.getRoute(id), throwsFormatException);
    }
  });
}
