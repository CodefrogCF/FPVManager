import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_models.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_service.dart';

class MemoryPoiCache implements OsmPoiCache {
  final Map<String, OsmPoiSnapshot> entries = {};
  @override
  Future<OsmPoiSnapshot?> read(OsmPoiSearch search) =>
      Future.value(entries[search.identity]?.cached());
  @override
  Future<void> write(OsmPoiSnapshot snapshot) async {
    entries[snapshot.search.identity] = snapshot;
  }
}

void main() {
  final query = OsmPoiSearch(
    latitude: 47.4,
    longitude: 8.5,
    radiusMeters: 500,
    categories: {OsmPoiCategory.benches},
  );
  final now = DateTime.utc(2026, 11, 3, 15);
  const response =
      '{"elements":[{"type":"node","id":11,"lat":47.4,"lon":8.5,"tags":{"amenity":"bench"}}]}';

  test('one POST for concurrent identical queries; fresh cached query avoids a POST', () async {
    var calls = 0;
    final mock = MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'https://overpass-api.de/api/interpreter');
      expect(request.method, 'POST');
      expect(request.body, contains('data='));
      expect(request.headers['authorization'], isNull);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response(
        response,
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final transport = MobilityHttp(client: mock);
    final cache = MemoryPoiCache();
    final service = OsmPoiService(
      transport: transport,
      cache: cache,
      now: () => now,
    );
    addTearDown(() async {
      await service.dispose();
      transport.dispose();
      mock.close();
    });
    final results = await Future.wait([
      service.search(query),
      service.search(query),
    ]);
    expect(calls, 1);
    expect(results[0].pois.single.reference, 'node/11');
    final offline = await service.search(query);
    expect(offline.fromCache, isTrue);
    expect(calls, 1);
  });

  test(
    'timeout returns dated cached results, never claims they are live',
    () async {
      final transport = MobilityHttp(
        client: MockClient((_) async => throw TimeoutException('timeout')),
      );
      final cache = MemoryPoiCache();
      cache.entries[query.identity] = OsmPoiSnapshot(
        search: query,
        fetchedAtUtc: now.subtract(const Duration(days: 3)),
        pois: const [],
        truncated: false,
      );
      final service = OsmPoiService(
        transport: transport,
        cache: cache,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
      });
      final result = await service.search(query);
      expect(result.fromCache, isTrue);
      expect(result.fallbackToCache, isTrue);
      expect(result.isOutdated(now), isTrue);
      expect(result.fetchedAtUtc, now.subtract(const Duration(days: 3)));
    },
  );

  test('timeouts without a saved result and HTTP 429 are surfaced', () async {
    final timeouts = MobilityHttp(
      client: MockClient((_) async => throw TimeoutException('timeout')),
    );
    final one = OsmPoiService(
      cache: MemoryPoiCache(),
      transport: timeouts,
      now: () => now,
    );
    await expectLater(one.search(query), throwsA(isA<FormatException>()));
    await one.dispose();
    timeouts.dispose();
    final limited = MobilityHttp(
      client: MockClient((_) async => http.Response('rate limited', 429)),
    );
    final two = OsmPoiService(
      cache: MemoryPoiCache(),
      transport: limited,
      now: () => now,
    );
    await expectLater(two.search(query), throwsA(isA<FormatException>()));
    await two.dispose();
    limited.dispose();
  });

  test('local budget limits repeated queries and hourly volume', () {
    var current = now;
    final budget = OsmPoiRequestBudget(now: () => current);
    budget.reserve();
    expect(() => budget.reserve(), throwsFormatException);
    for (var i = 1; i < 12; i++) {
      current = current.add(const Duration(seconds: 15));
      budget.reserve();
    }
    current = current.add(const Duration(seconds: 15));
    expect(() => budget.reserve(), throwsFormatException);
  });

  test('parse JSON test fixture does not imply completeness', () {
    final parsed = parseOverpassPois(jsonEncode({'elements': []}), query);
    expect(parsed.pois, isEmpty);
    expect(parsed.truncated, isFalse);
    // A successful empty search only means zero mapped elements were returned.
  });
}
