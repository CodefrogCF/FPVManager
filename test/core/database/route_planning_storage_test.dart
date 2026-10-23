import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';

void main() {
  const point = RouteWaypointInput(
    position: Wgs84Coordinate(latitude: 47, longitude: 8),
    height: AglWaypointHeight(AboveGroundHeight(80)),
    speedMetersPerSecond: 15,
  );
  test('multiple routes persist across a real SQLite file reopen', () async {
    final directory = await Directory.systemTemp.createTemp('fpv-routes-');
    final file = File('${directory.path}/routes.sqlite');
    FpvDatabase? fileDatabase;
    try {
      final firstDatabase = fileDatabase = FpvDatabase(NativeDatabase(file));
      final first = FlightPlanRepository(firstDatabase);
      final a = await first.saveRoute(
        name: 'A',
        planning: const RoutePlanningSettings(reservePercent: 35),
        waypoints: [
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
            speedMetersPerSecond: 15,
          ),
        ],
      );
      final b = await first.saveRoute(
        name: 'B',
        waypoints: [
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.8, longitude: 8.5),
          ),
        ],
      );
      await firstDatabase.close();
      fileDatabase = null;
      final reopenedDatabase = fileDatabase = FpvDatabase(NativeDatabase(file));
      final reopened = FlightPlanRepository(reopenedDatabase);
      expect((await reopened.getAllFlightPlans()).length, 2);
      final reopenedA = (await reopened.getRoute(a))!;
      expect(reopenedA.waypoints.single.speedMetersPerSecond, 15);
      expect(
        RoutePlanningSettings.decode(reopenedA.plan.planningJson)
            .reservePercent,
        35,
      );
      expect(reopenedA.waypoints.single.position.latitude, 46.7);
      expect(
        (await reopened.getRoute(b))!.waypoints.single.position.latitude,
        46.8,
      );
    } finally {
      await fileDatabase?.close();
      await directory.delete(recursive: true);
    }
  });
  group('route metadata and assignments', () {
    late FpvDatabase db;
    late FlightPlanRepository repo;
    setUp(() {
      db = FpvDatabase(NativeDatabase.memory());
      repo = FlightPlanRepository(db);
    });
    tearDown(() => db.close());
    test('route speed, heights and equipment round-trip; assignments replace only this route', () async {
      final drone = await DroneRepository(db).createDrone(name: 'FPV');
      final pack = await BatteryRepository(db)
          .createBattery(name: 'Pack', cellCount: 6, capacityMah: 1300);
      final other = await repo.saveRoute(
        name: 'Other',
        batteryIds: {pack},
        waypoints: [],
      );
      final id = await repo.saveRoute(
        name: 'Ridge',
        droneId: drone,
        batteryIds: {pack},
        waypoints: [point],
      );
      final route = (await repo.getRoute(id))!;
      expect(route.plan.droneId, drone);
      expect(route.batteryIds, {pack});
      expect(route.waypoints.single.speedMetersPerSecond, 15);
      expect(route.waypoints.single.height!.meters, 80);
      await repo.saveRoute(
        id: id,
        name: 'Changed',
        batteryIds: {},
        waypoints: [point],
      );
      expect((await repo.getRoute(id))!.batteryIds, isEmpty);
      expect((await repo.getRoute(other))!.batteryIds, {pack});
    });
    test('invalid equipment rolls back name, waypoints and previous assignments together', () async {
      final id = await repo.saveRoute(name: 'Original', waypoints: [point]);
      await expectLater(
        repo.saveRoute(
          id: id,
          name: 'Invalid',
          batteryIds: {999},
          waypoints: [],
        ),
        throwsArgumentError,
      );
      final route = (await repo.getRoute(id))!;
      expect(route.plan.name, 'Original');
      expect(route.waypoints, hasLength(1));
      for (final speed in [0.0, -1.0, double.nan, double.infinity, 201.0]) {
        expect(
          () => repo.saveRoute(
            name: 'Invalid speed',
            waypoints: [
              RouteWaypointInput(
                position: point.position,
                speedMetersPerSecond: speed,
              ),
            ],
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
