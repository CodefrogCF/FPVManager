@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_models.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_service.dart';

class _MemoryCache implements EvChargingCache {
  EvChargingSnapshot? saved;
  @override
  Future<EvChargingSnapshot?> read(EvChargingArea area) async =>
      saved?.cached();
  @override
  Future<void> write(EvChargingSnapshot snapshot) async {
    saved = snapshot;
  }
}

void main() {
  test(
    'browser-compatible fetch is HTTPS, bounded and independent of an auth key',
    () async {
      var calls = 0;
      final browserClient = MockClient((request) async {
        calls++;
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api3.geo.admin.ch');
        expect(request.url.queryParameters['limit'], '200');
        expect(
          request.headers.keys.any((h) => h.toLowerCase() == 'authorization'),
          isFalse,
        );
        expect(request.method, 'GET');
        return http.Response(jsonEncode({'results': []}), 200);
      });
      final httpTransport = MobilityHttp(client: browserClient);
      final service = EvChargingService(
        transport: httpTransport,
        cache: _MemoryCache(),
        now: () => DateTime.utc(2026, 11, 3),
      );
      addTearDown(() async {
        await service.dispose();
        httpTransport.dispose();
        browserClient.close();
      });
      final area = EvChargingArea(
        latitude: 47.4,
        longitude: 8.5,
        radiusMeters: 500,
      );
      final snapshot = await service.search(area);
      expect(snapshot.stations, isEmpty);
      expect(calls, 1);
      final cached = await service.search(area);
      expect(cached.fromCache, isTrue);
      expect(calls, 1);
    },
  );
  test(
    'browser failed refresh uses an explicitly dated cache snapshot',
    () async {
      final area = EvChargingArea(
        latitude: 47.4,
        longitude: 8.5,
        radiusMeters: 500,
      );
      final cache = _MemoryCache();
      cache.saved = EvChargingSnapshot(
        area: area,
        fetchedUtc: DateTime.utc(2026, 11, 3, 12),
        stations: const [],
        statuses: const {},
      );
      final mock = MockClient((_) async => http.Response('Unavailable', 503));
      final transport = MobilityHttp(client: mock);
      final service = EvChargingService(
        transport: transport,
        cache: cache,
        now: () => DateTime.utc(2026, 11, 3, 18),
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        mock.close();
      });
      final old = await service.search(area);
      expect(old.refreshFailed, isTrue);
      expect(old.fromCache, isTrue);
      expect(old.isOld(DateTime.utc(2026, 11, 3, 18)), isTrue);
    },
  );
}
