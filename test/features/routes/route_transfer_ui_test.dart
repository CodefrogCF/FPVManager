import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_transfer.dart';
import 'package:fpvmanager/features/routes/flight_routes_screen.dart';
import 'package:fpvmanager/features/routes/transfer/route_file_service.dart';

final _route = ImportedRoute('Imported ridge', [
  for (final lon in [8.0, 8.001])
    RouteWaypointInput(position: Wgs84Coordinate(latitude: 47, longitude: lon)),
]);

class _Files implements RouteFileService {
  int exports = 0;
  @override
  Future<RouteImportPreview?> pickRoutes() async =>
      RouteImportPreview([_route], ['Unknown flight heights']);
  @override
  Future<bool> exportRoute(ImportedRoute route, RouteFileFormat format) async {
    exports++;
    return true;
  }
}

void main() {
  testWidgets(
    'import requires preview confirmation and export requires an explicit action',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FlightPlanRepository(db), files = _Files();
      await tester.pumpWidget(
        MaterialApp(
          home: FlightRoutesScreen(repository: repo, routeFiles: files),
        ),
      );
      await tester.pumpAndSettle();
      expect(files.exports, 0);
      await tester.tap(find.byTooltip('Import routes'));
      await tester.pumpAndSettle();
      expect(find.text('Unknown flight heights'), findsOneWidget);
      expect(await repo.getAllFlightPlans(), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.getAllFlightPlans(), isEmpty);
      await tester.tap(find.byTooltip('Import routes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import locally'));
      await tester.pumpAndSettle();
      expect((await repo.getAllFlightPlans()).single.name, 'Imported ridge');
      expect(files.exports, 0);
      await tester.tap(find.byTooltip('Export Imported ridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export GPX'));
      await tester.pumpAndSettle();
      expect(files.exports, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  test('Android export uses the user-selected document channel and preserves cancellation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.codefrog.fpvmanager/route_files'),
          (call) async {
            expect(call.method, 'saveRoute');
            expect(call.arguments['mimeType'], 'application/gpx+xml');
            expect(call.arguments['name'], 'Imported_ridge.gpx');
            expect(call.arguments['bytes'], isNotEmpty);
            return false;
          },
        );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.codefrog.fpvmanager/route_files'),
            null,
          );
    });
    expect(
      await const RouteFileService().exportRoute(_route, RouteFileFormat.gpx),
      isFalse,
    );
  });
}
