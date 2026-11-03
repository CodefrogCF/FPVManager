import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_models.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_parser.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_service.dart';

import 'pollen_parser_test.dart' show stationMetadata, hourly;

class MemoryPollenCache implements PollenCache {
  List<PollenStation>? stationList;
  final Map<String, PollenSnapshot> results = {};
  @override
  Future<List<PollenStation>?> readStations() async => stationList;
  @override
  Future<void> writeStations(List<PollenStation> stations) async {
    stationList = stations;
  }

  @override
  Future<PollenSnapshot?> readSnapshot(String id) async =>
      results[id]?.cached();
  @override
  Future<void> writeSnapshot(PollenSnapshot snapshot) async {
    results[snapshot.station.id] = snapshot;
  }
}

final assetUrl = Uri.parse(
  'https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/pzh/ogd-pollen_pzh_h_now.csv',
);

void main() {
  final station = parsePollenStations(stationMetadata).first;
  var now = DateTime.utc(2026, 11, 3, 12, 40);

  test('nearest stations are ordered by true geographic distance', () {
    final service = PollenService(
      cache: MemoryPollenCache(),
      transport: MobilityHttp(
        client: MockClient((_) async => http.Response('', 200)),
      ),
    );
    final stations = parsePollenStations(stationMetadata);
    expect(service.nearest(stations, 47.4, 8.55).first.id, 'PZH');
    expect(service.nearest(stations, 46.52, 6.62).first.id, 'PLS');
    service.dispose();
  });

  test(
    'STAC and CSV requests coalesce, preserve published timestamp and cache',
    () async {
      final memory = MemoryPollenCache();
      var count = 0;
      final client = MockClient((request) async {
        count++;
        if (request.url.path.endsWith('/pzh')) {
          return http.Response(
            jsonEncode({
              'properties': {'updated': '2026-11-03T12:20:00Z'},
              'assets': {
                'h_now': {'href': assetUrl.toString()},
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('_h_now.csv')) {
          return http.Response(hourly, 200);
        }
        throw StateError('Unexpected endpoint: ${request.url}');
      });
      final transport = MobilityHttp(client: client);
      final service = PollenService(
        cache: memory,
        transport: transport,
        now: () => now,
      );
      final snapshots = await Future.wait([
        service.observations(station),
        service.observations(station),
      ]);
      expect(identical(snapshots[0], snapshots[1]), isTrue);
      expect(count, 2);
      expect(snapshots[0].publishedUtc, DateTime.utc(2026, 11, 3, 12, 20));
      expect(snapshots[0].freshnessAt(now), OsintFreshness.fresh);
      final cached = await service.observations(station);
      expect(cached.fromCache, isTrue);
      expect(count, 2);
      await service.dispose();
      transport.dispose();
      client.close();
    },
  );

  test(
    'refresh failure leaves a dated snapshot but never marks it fresh',
    () async {
      final memory = MemoryPollenCache();
      final existing = PollenSnapshot(
        station: station,
        samples: parsePollenHourlyCsv(hourly, station.id).samples,
        assetUrl: assetUrl,
        fetchedUtc: now.subtract(const Duration(hours: 3)),
      );
      memory.results[station.id] = existing;
      final transport = MobilityHttp(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final service = PollenService(
        cache: memory,
        transport: transport,
        now: () => now,
      );
      final returned = await service.observations(station, refresh: true);
      expect(returned.fromCache, isTrue);
      expect(returned.refreshFailed, isTrue);
      expect(returned.fetchedUtc, existing.fetchedUtc);
      expect(returned.freshnessAt(now), OsintFreshness.stale);
      await service.dispose();
      transport.dispose();
    },
  );

  test('HTTP 429 and a timeout without cache fail visibly', () async {
    for (final client in <MockClient>[
      MockClient((_) async => http.Response('busy', 429)),
      MockClient((_) async => throw TimeoutException('timed out')),
    ]) {
      final transport = MobilityHttp(client: client);
      final service = PollenService(
        cache: MemoryPollenCache(),
        transport: transport,
        now: () => now,
      );
      await expectLater(
        service.observations(station),
        throwsA(isA<FormatException>()),
      );
      await service.dispose();
      transport.dispose();
      client.close();
    }
  });

  test(
    'metadata parsing and failed refresh support persisted stations',
    () async {
      final memory = MemoryPollenCache();
      final client = MockClient(
        (_) async => http.Response(
          stationMetadata,
          200,
          headers: {'content-type': 'text/csv'},
        ),
      );
      final transport = MobilityHttp(client: client);
      final service = PollenService(
        cache: memory,
        transport: transport,
        now: () => now,
      );
      final loaded = await service.stations(refresh: true);
      expect(loaded, hasLength(2));
      expect(memory.stationList, isNotNull);
      await service.dispose();
      transport.dispose();
      client.close();

      final offlineTransport = MobilityHttp(
        client: MockClient((_) async => http.Response('offline', 503)),
      );
      final reopened = PollenService(
        cache: memory,
        transport: offlineTransport,
        now: () => now,
      );
      expect(await reopened.stations(refresh: true), hasLength(2));
      expect(reopened.stationMetadataFromCache, isTrue);
      expect(reopened.stationMetadataRefreshFailed, isTrue);
      await reopened.dispose();
      offlineTransport.dispose();
    },
  );

  test(
    'request budget limits bursts and fresh readings age out independently',
    () {
      var clock = now;
      final budget = PollenRequestBudget(clock: () => clock);
      budget.reserve();
      expect(() => budget.reserve(), throwsFormatException);
      clock = clock.add(const Duration(seconds: 15));
      budget.reserve();
      final snapshot = PollenSnapshot(
        station: station,
        samples: parsePollenHourlyCsv(hourly, station.id).samples,
        assetUrl: assetUrl,
        fetchedUtc: now,
      );
      expect(
        snapshot.freshnessAt(now.add(const Duration(hours: 3))),
        OsintFreshness.stale,
      );
    },
  );
}
