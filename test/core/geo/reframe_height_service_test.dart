import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/reframe_height_service.dart';

void main() {
  const position = Lv95Coordinate(easting: 2600000, northing: 1200000);

  group('ReframeHeightService', () {
    test('transforms LN02 to LHN95', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/reframe/ln02tolhn95');

        expect(request.url.queryParameters['easting'], '2600000.000');

        expect(request.url.queryParameters['altitude'], '550.0000');

        return http.Response(
          jsonEncode({
            'easting': '2600000.0',
            'northing': '1200000.0',
            'altitude': '549.9579940080323',
          }),
          200,
        );
      });

      final service = ReframeHeightService(client: client);

      final result = await service.transform(
        position: position,
        elevation: const ReferencedElevation(
          meters: 550,
          reference: VerticalReference.ln02,
        ),
        target: VerticalReference.lhn95,
      );

      expect(result.reference, VerticalReference.lhn95);

      expect(result.meters, closeTo(549.957994, 0.0001));

      service.dispose();
      client.close();
    });

    test('returns same height for same datum', () async {
      final client = MockClient((request) async {
        fail('No HTTP request expected');
      });

      final service = ReframeHeightService(client: client);

      final result = await service.transform(
        position: position,
        elevation: const ReferencedElevation(
          meters: 1500,
          reference: VerticalReference.ln02,
        ),
        target: VerticalReference.ln02,
      );

      expect(result.meters, 1500);

      service.dispose();
      client.close();
    });

    test('rejects unsupported height references', () async {
      final service = ReframeHeightService();

      await expectLater(
        service.transform(
          position: position,
          elevation: const ReferencedElevation(
            meters: 1500,
            reference: VerticalReference.wgs84Ellipsoid,
          ),
          target: VerticalReference.ln02,
        ),
        throwsUnsupportedError,
      );

      service.dispose();
    });

    test('rejects unknown datums before making a request', () async {
      final client = MockClient((_) async => fail('No HTTP request expected'));
      final service = ReframeHeightService(client: client);
      for (final source in [
        VerticalReference.unverified,
        VerticalReference.ln02,
      ]) {
        await expectLater(
          service.transform(
            position: position,
            elevation: ReferencedElevation(meters: 550, reference: source),
            target: VerticalReference.unverified,
          ),
          throwsArgumentError,
        );
      }
      service.dispose();
      client.close();
    });

    test(
      'rejects missing, nonfinite and mismatched response positions',
      () async {
        for (final override in [
          {'easting': null},
          {'northing': 'NaN'},
          {'easting': 2600100},
          {'altitude': 'Infinity'},
        ]) {
          final client = MockClient(
            (_) async => http.Response(
              jsonEncode({
                'easting': 2600000,
                'northing': 1200000,
                'altitude': 549.958,
                ...override,
              }),
              200,
            ),
          );
          final service = ReframeHeightService(client: client);
          await expectLater(
            service.transform(
              position: position,
              elevation: const ReferencedElevation(
                meters: 550,
                reference: VerticalReference.ln02,
              ),
              target: VerticalReference.lhn95,
            ),
            throwsFormatException,
          );
          service.dispose();
          client.close();
        }
      },
    );

    test('handles HTTP errors', () async {
      final client = MockClient((request) async {
        return http.Response('Unavailable', 503);
      });

      final service = ReframeHeightService(client: client);

      await expectLater(
        service.transform(
          position: position,
          elevation: const ReferencedElevation(
            meters: 550,
            reference: VerticalReference.ln02,
          ),
          target: VerticalReference.lhn95,
        ),
        throwsStateError,
      );

      service.dispose();
      client.close();
    });
  });
}
