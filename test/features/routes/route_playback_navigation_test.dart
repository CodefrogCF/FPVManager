import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/routes/flight_routes_screen.dart';

void main() {
  testWidgets('route list offers replay without changing the saved route', (
    tester,
  ) async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FlightPlanRepository(db);
    final id = await repository.saveRoute(
      name: 'Replay waypoint route',
      waypoints: const [
        RouteWaypointInput(
          position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
        ),
        RouteWaypointInput(
          position: Wgs84Coordinate(latitude: 46.71, longitude: 8.41),
        ),
      ],
    );
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                    builder: (_) => FlightRoutesScreen(repository: repository),
                  ),
                );
              },
              child: const Text('Show routes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show routes'));
    await tester.pumpAndSettle();
    expect(find.text('Replay waypoint route'), findsOneWidget);
    await tester.tap(find.byTooltip('Simulate flight: Replay waypoint route'));
    await tester.pumpAndSettle();
    expect(selected, id);
    expect(find.text('Show routes'), findsOneWidget);
    expect((await repository.getRoute(id))!.waypoints.length, 2);
  });
}
