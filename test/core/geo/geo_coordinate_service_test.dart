import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';

void main() {
  const service = GeoCoordinateService();

  group('GeoCoordinateService', () {
    test('converts official WGS84 reference to LV95', () {
      // swisstopo example:
      // Latitude:  46° 02' 38.87"
      // Longitude:  8° 43' 49.79"
      final coordinate = Wgs84Coordinate(
        latitude: 46 + 2 / 60 + 38.87 / 3600,
        longitude: 8 + 43 / 60 + 49.79 / 3600,
      );

      final result = service.wgs84ToLv95(coordinate);

      expect(result.easting, closeTo(2699999.76, 0.10));

      expect(result.northing, closeTo(1099999.97, 0.10));
    });

    test('converts official LV95 reference to WGS84', () {
      const coordinate = Lv95Coordinate(easting: 2700000, northing: 1100000);

      final result = service.lv95ToWgs84(coordinate);

      final expectedLatitude = 46 + 2 / 60 + 38.86 / 3600;

      final expectedLongitude = 8 + 43 / 60 + 49.80 / 3600;

      expect(result.latitude, closeTo(expectedLatitude, 0.00001));

      expect(result.longitude, closeTo(expectedLongitude, 0.00001));
    });

    test('round-trip conversion remains consistent', () {
      const original = Wgs84Coordinate(latitude: 46.95108, longitude: 7.43863);

      final lv95 = service.wgs84ToLv95(original);
      final restored = service.lv95ToWgs84(lv95);

      // Approximate formulas have limited accuracy.
      expect(restored.latitude, closeTo(original.latitude, 0.00005));

      expect(restored.longitude, closeTo(original.longitude, 0.00005));
    });

    test('rejects unsupported WGS84 locations', () {
      expect(
        () => service.wgs84ToLv95(
          const Wgs84Coordinate(latitude: 40, longitude: 8),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported LV95 coordinates', () {
      expect(
        () => service.lv95ToWgs84(
          const Lv95Coordinate(easting: 100, northing: 100),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite coordinates', () {
      expect(
        () => service.wgs84ToLv95(
          const Wgs84Coordinate(latitude: double.nan, longitude: 8),
        ),
        throwsArgumentError,
      );
    });

    test('preserves explicit height references', () {
      const elevation = ReferencedElevation(
        meters: 1500,
        reference: VerticalReference.ln02,
      );

      expect(elevation.meters, 1500);
      expect(elevation.reference, VerticalReference.ln02);

      expect(elevation.reference, isNot(VerticalReference.wgs84Ellipsoid));
    });
  });
}
