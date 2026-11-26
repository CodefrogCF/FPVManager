import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/routes/transfer/route_file_codec.dart';

void main() {
  test(
    'reference scenery routes retain absolute ellipsoid height and speed',
    () {
      final bytes = File(
        'test/fixtures/scenery/reference_ruedersdorf_routes.geojson',
      ).readAsBytesSync();
      final preview = decodeRouteFile(bytes);
      expect(preview.routes.length, 9);
      expect(
        preview.routes.fold<int>(0, (n, r) => n + r.points.length - 1),
        21,
      );
      for (final route in preview.routes) {
        expect(route.name, contains('(simulation)'));
        for (final point in route.points) {
          final height = point.height as AbsoluteWaypointHeight;
          expect(height.elevation.reference, VerticalReference.wgs84Ellipsoid);
          expect(height.meters.isFinite, isTrue);
          expect(point.speedMetersPerSecond, greaterThan(0));
        }
      }
      final fast = preview.routes.singleWhere((r) => r.name.contains('Fast'));
      expect(fast.points.first.speedMetersPerSecond, 35);
    },
  );
}
