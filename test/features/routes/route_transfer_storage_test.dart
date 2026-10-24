import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_transfer.dart';

void main() {
  late FpvDatabase db;
  late FlightPlanRepository repo;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repo = FlightPlanRepository(db);
  });
  tearDown(() => db.close());
  ImportedRoute route(String name, {double latitude = 47}) =>
      ImportedRoute(name, [
        for (final lon in [8.0, 8.001])
          RouteWaypointInput(
            position: Wgs84Coordinate(latitude: latitude, longitude: lon),
          ),
      ]);
  test(
    'import creates distinct local copies without replacing existing routes',
    () async {
      final existing = await repo.saveRoute(
        name: 'Same name',
        waypoints: route('Same name').points,
      );
      final ids = await repo.importRoutes([
        route('Same name'),
        route('Second'),
      ]);
      expect(ids.length, 2);
      expect(ids, isNot(contains(existing)));
      expect((await repo.getAllFlightPlans()).length, 3);
      expect((await repo.getRoute(ids.first))!.waypoints.length, 2);
      expect((await repo.getRoute(existing))!.plan.name, 'Same name');
    },
  );
  test('failed multi-route import rolls back every inserted route', () async {
    await expectLater(
      repo.importRoutes([route('Valid'), route('Invalid', latitude: 95)]),
      throwsArgumentError,
    );
    expect(await repo.getAllFlightPlans(), isEmpty);
    await repo.importRoutes([route('Recovery')]);
    expect((await repo.getAllFlightPlans()).single.name, 'Recovery');
  });
}
