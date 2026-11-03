@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_models.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_service.dart';

class _WebCache implements SharedMobilityCache {
  SharedMobilitySnapshot? saved;
  @override
  Future<SharedMobilitySnapshot?> read(SharedMobilityArea area) async =>
      saved?.cached();
  @override
  Future<void> write(SharedMobilitySnapshot snapshot) async {
    saved = snapshot;
  }
}

void main() {
  test(
    'browser GET uses bounded HTTPS REST endpoint without PII or GBFS headers',
    () async {
      var count = 0;
      final client = MockClient((request) async {
        count++;
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api.sharedmobility.ch');
        expect(request.url.queryParameters['Tolerance'], '200');
        expect(
          request.headers.keys.map((name) => name.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          request.url.queryParameters.keys,
          containsAll(['Geometry', 'Tolerance']),
        );
        return http.Response(jsonEncode([]), 200);
      });
      final transport = MobilityHttp(client: client);
      final service = SharedMobilityService(
        transport: transport,
        cache: _WebCache(),
        now: () => DateTime.utc(2026, 11, 3),
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      final area = SharedMobilityArea(
        latitude: 47.5,
        longitude: 8.7,
        radiusMeters: 200,
      );
      final first = await service.search(area);
      expect(first.offers, isEmpty);
      expect((await service.search(area)).fromCache, isTrue);
      expect(count, 1);
    },
  );
  test(
    'browser mock returns stale cache after network error, never as live',
    () async {
      final area = SharedMobilityArea(latitude: 47.5, longitude: 8.7);
      final cache = _WebCache()
        ..saved = SharedMobilitySnapshot(
          area: area,
          fetchedUtc: DateTime.utc(2026, 11, 2),
          offers: const [],
          truncated: false,
        );
      final client = MockClient((_) async => http.Response('bad gateway', 502));
      final transport = MobilityHttp(client: client);
      final service = SharedMobilityService(
        cache: cache,
        transport: transport,
        now: () => DateTime.utc(2026, 11, 3),
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      final result = await service.search(area);
      expect(result.refreshFailed, isTrue);
      expect(result.fromCache, isTrue);
      expect(result.isOld(DateTime.utc(2026, 11, 3)), isTrue);
    },
  );
}
