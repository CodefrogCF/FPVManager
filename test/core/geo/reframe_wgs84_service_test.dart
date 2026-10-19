import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/reframe_wgs84_service.dart';

void main() {
  const coordinate = Wgs84Coordinate(latitude: 46.95108, longitude: 7.43863);

  const elevation = ReferencedElevation(
    meters: 550,
    reference: VerticalReference.wgs84Ellipsoid,
  );

  group('ReframeWgs84Service', () {
    test('converts WGS84 to Bessel and LN02', () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        if (request.url.path == '/reframe/wgs84tolv95') {
          expect(request.url.queryParameters['easting'], '7.43863000');

          expect(request.url.queryParameters['northing'], '46.95108000');

          return http.Response(
            jsonEncode({
              'easting': '2599999.810036594',
              'northing': '1199999.6801912596',
              'altitude': '500.3777916841209',
            }),
            200,
          );
        }

        if (request.url.path == '/reframe/besseltoln02') {
          expect(request.url.queryParameters['altitude'], '500.3778');

          // Simulated response for the second step.
          return http.Response(
            jsonEncode({
              'easting': '2599999.81',
              'northing': '1199999.68',
              'altitude': '501.2345',
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      final service = ReframeWgs84Service(client: client);

      final result = await service.toLn02(
        coordinate: coordinate,
        elevation: elevation,
      );

      expect(requestCount, 2);

      expect(result.position.easting, closeTo(2599999.810036594, 0.00001));

      expect(result.position.northing, closeTo(1199999.6801912596, 0.00001));

      expect(result.besselHeight.meters, closeTo(500.3777916841209, 0.00001));

      expect(result.besselHeight.reference, VerticalReference.besselEllipsoid);

      expect(result.ln02Height.meters, 501.2345);
      expect(result.ln02Height.reference, VerticalReference.ln02);

      service.dispose();
      client.close();
    });

    test('rejects heights with wrong reference', () async {
      final service = ReframeWgs84Service();

      await expectLater(
        service.toLn02(
          coordinate: coordinate,
          elevation: const ReferencedElevation(
            meters: 550,
            reference: VerticalReference.ln02,
          ),
        ),
        throwsArgumentError,
      );

      service.dispose();
    });

    test('rejects invalid coordinates', () async {
      final service = ReframeWgs84Service();

      await expectLater(
        service.toLn02(
          coordinate: const Wgs84Coordinate(latitude: 95, longitude: 8),
          elevation: elevation,
        ),
        throwsArgumentError,
      );

      service.dispose();
    });

    test('rejects invalid API responses', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'easting': 'invalid',
            'northing': '1200000',
            'altitude': '500',
          }),
          200,
        );
      });

      final service = ReframeWgs84Service(client: client);

      await expectLater(
        service.toLn02(coordinate: coordinate, elevation: elevation),
        throwsFormatException,
      );

      service.dispose();
      client.close();
    });
  });
}
