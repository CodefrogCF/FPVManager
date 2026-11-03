import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_models.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_service.dart';

class MemoryChargingCache implements EvChargingCache {
  EvChargingSnapshot? value;
  @override
  Future<EvChargingSnapshot?> read(EvChargingArea area) async =>
      value?.area.identity == area.identity ? value!.cached() : null;
  @override
  Future<void> write(EvChargingSnapshot snapshot) async {
    value = snapshot;
  }
}

void main() {
  final area = EvChargingArea(latitude: 47.37, longitude: 8.54);
  final now = DateTime.utc(2026, 11, 3, 17);
  final example = jsonEncode({
    'results': [
      {
        'featureId': 'station-1',
        'geometry': {
          'type': 'Point',
          'coordinates': [8.54, 47.37],
        },
        'properties': {
          'name': 'Laden',
          'Availability': 'AVAILABLE',
          'last_updated': now.toIso8601String(),
        },
      },
    ],
  });

  test(
    'coalesces in-flight requests; cached follow-up requires no HTTP request',
    () async {
      var count = 0;
      final mock = MockClient((request) async {
        count++;
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api3.geo.admin.ch');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(example, 200);
      });
      final transport = MobilityHttp(client: mock);
      final service = EvChargingService(
        cache: MemoryChargingCache(),
        transport: transport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        mock.close();
      });
      final results = await Future.wait([
        service.search(area),
        service.search(area),
      ]);
      expect(count, 1);
      expect(results[0].stations.single.name, 'Laden');
      final cached = await service.search(area);
      expect(cached.fromCache, isTrue);
      expect(count, 1);
    },
  );

  test('failed HTTP refresh returns dated locations but marks current status untrusted', () async {
    final cache = MemoryChargingCache();
    cache.value = EvChargingSnapshot(
      area: area,
      fetchedUtc: now.subtract(const Duration(hours: 1)),
      stations: const [],
      statuses: const {},
    );
    final transport = MobilityHttp(
      client: MockClient((_) async => http.Response('busy', 503)),
    );
    final service = EvChargingService(
      cache: cache,
      transport: transport,
      now: () => now,
    );
    addTearDown(() async {
      await service.dispose();
      transport.dispose();
    });
    final snap = await service.search(area);
    expect(snap.fromCache, isTrue);
    expect(snap.refreshFailed, isTrue);
    expect(snap.isOld(now), isTrue);
  });

  test('timeout with cached location returns marked fallback; without one reports error', () async {
    final cache = MemoryChargingCache();
    cache.value = EvChargingSnapshot(
      area: area,
      fetchedUtc: now.subtract(const Duration(hours: 1)),
      stations: const [],
      statuses: const {},
    );
    final transport = MobilityHttp(
      client: MockClient((_) async => throw TimeoutException('unreachable')),
    );
    final service = EvChargingService(
      cache: cache,
      transport: transport,
      now: () => now,
    );
    addTearDown(() async {
      await service.dispose();
      transport.dispose();
    });
    expect((await service.search(area)).refreshFailed, isTrue);
    cache.value = null;
    await expectLater(
      service.search(area, refresh: true),
      throwsA(isA<FormatException>()),
    );
  });

  test('local request budget prevents accidental polling', () {
    var nowAt = now;
    final budget = EvChargingBudget(clock: () => nowAt);
    budget.reserve();
    expect(() => budget.reserve(), throwsFormatException);
    for (var i = 1; i < 20; i++) {
      nowAt = nowAt.add(const Duration(seconds: 11));
      budget.reserve();
    }
    nowAt = nowAt.add(const Duration(seconds: 11));
    expect(() => budget.reserve(), throwsFormatException);
  });
}
