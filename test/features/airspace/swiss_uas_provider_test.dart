import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';

void main() {
  const validGeoJson = {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [8.5, 47.4],
        },
        'properties': {'name': 'Test Zone'},
      },
    ],
  };

  group('SwissUasProvider', () {
    test('downloads and validates GeoJSON', () async {
      final client = MockClient((request) async {
        expect(request.url, SwissUasProvider.datasetUri);

        return http.Response(jsonEncode(validGeoJson), 200);
      });

      final provider = SwissUasProvider(client: client);

      final dataset = await provider.fetch();

      expect(dataset.data['type'], 'FeatureCollection');

      expect(dataset.providerId, 'ch.bazl.uas-zones');
      expect(dataset.fetchedAtUtc.isUtc, isTrue);

      provider.dispose();
      client.close();
    });

    test('uses cached data within cache duration', () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        return http.Response(jsonEncode(validGeoJson), 200);
      });

      final provider = SwissUasProvider(client: client);

      final first = await provider.fetch();
      final second = await provider.fetch();

      expect(requestCount, 1);
      expect(identical(first, second), isTrue);

      provider.dispose();
      client.close();
    });

    test('forceRefresh fetches new data', () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        return http.Response(jsonEncode(validGeoJson), 200);
      });

      final provider = SwissUasProvider(client: client);

      await provider.fetch();
      await provider.fetch(forceRefresh: true);

      expect(requestCount, 2);

      provider.dispose();
      client.close();
    });

    test('rejects invalid GeoJSON', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'type': 'InvalidDocument', 'features': []}),
          200,
        );
      });

      final provider = SwissUasProvider(client: client);

      await expectLater(provider.fetch(), throwsFormatException);

      provider.dispose();
      client.close();
    });

    test('handles HTTP failures', () async {
      final client = MockClient((request) async {
        return http.Response('Server unavailable', 503);
      });

      final provider = SwissUasProvider(client: client);

      await expectLater(provider.fetch(), throwsStateError);

      provider.dispose();
      client.close();
    });

    test('keeps previous cache after refresh failure', () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        if (requestCount == 1) {
          return http.Response(jsonEncode(validGeoJson), 200);
        }

        return http.Response('Unavailable', 503);
      });

      final provider = SwissUasProvider(client: client);

      final previous = await provider.fetch();

      await expectLater(provider.fetch(forceRefresh: true), throwsStateError);

      expect(identical(provider.cached, previous), isTrue);

      provider.dispose();
      client.close();
    });
  });
}
