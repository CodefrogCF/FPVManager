import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_models.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_service.dart';

class _MemoryCache implements SharedMobilityCache {
  final Map<String, SharedMobilitySnapshot> data = {};
  @override
  Future<SharedMobilitySnapshot?> read(SharedMobilityArea area) async =>
      data[area.identity]?.cached();
  @override
  Future<void> write(SharedMobilitySnapshot snapshot) async {
    data[snapshot.area.identity] = snapshot;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 3, 18);
  final area = SharedMobilityArea(latitude: 47.50024, longitude: 8.72334);
  String response(List<String> ids) => jsonEncode([
    for (final id in ids)
      {
        'id': id,
        'featureId': id,
        'geometry': {
          'x': 8.72334,
          'y': 47.50024,
          'spatialReference': {'wkid': 4326},
        },
        'attributes': {
          'id': id,
          'provider_id': 'bikes',
          'provider_name': 'Bike operator',
          'available': true,
          'pickup_type': 'free_floating',
          'vehicle_status_reserved': false,
          'vehicle_status_disabled': false,
          'vehicle_type': ['Bike'],
        },
      },
  ]);

  test(
    'server filters geographically; two identical requests use one call',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api.sharedmobility.ch');
        expect(
          request.url.queryParameters['Tolerance'],
          '${area.radiusMeters}',
        );
        expect(request.url.queryParameters['Geometry'], '8.723340,47.500240');
        expect(request.url.queryParameters['offset'], '0');
        expect(request.method, 'GET');
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 15));
        return http.Response(response(['a']), 200);
      });
      final transport = MobilityHttp(client: client);
      final service = SharedMobilityService(
        cache: _MemoryCache(),
        transport: transport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      final snapshots = await Future.wait([
        service.search(area),
        service.search(area),
      ]);
      expect(requests, 1);
      expect(snapshots.first.offers.single.id, 'a');
      final saved = await service.search(area);
      expect(saved.fromCache, isTrue);
      expect(requests, 1);
    },
  );

  test(
    'successful refresh replaces disappeared vehicles; does not merge old ones',
    () async {
      var version = 0;
      var clock = now;
      final client = MockClient(
        (_) async => http.Response(
          response(version++ == 0 ? ['old', 'stays'] : ['stays']),
          200,
        ),
      );
      final transport = MobilityHttp(client: client);
      final cache = _MemoryCache();
      final service = SharedMobilityService(
        cache: cache,
        transport: transport,
        now: () => clock,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      expect((await service.search(area)).offers, hasLength(2));
      clock = clock.add(const Duration(seconds: 15));
      final refreshed = await service.search(area, refresh: true);
      expect(refreshed.offers.map((offer) => offer.id), ['stays']);
      expect((await cache.read(area))!.offers.map((offer) => offer.id), [
        'stays',
      ]);
    },
  );

  test(
    'reserved -> released -> disabled status changes replace previous records',
    () async {
      var state = 0;
      var clock = now;
      final client = MockClient((_) async {
        final index = state++;
        return http.Response(
          jsonEncode([
            {
              'id': 'vehicle-7',
              'geometry': {'x': area.longitude, 'y': area.latitude},
              'attributes': {
                'id': 'vehicle-7',
                'provider_id': 'operator',
                'pickup_type': 'free_floating',
                'available': true,
                'vehicle_status_reserved': index == 0,
                'vehicle_status_disabled': index == 2,
              },
            },
          ]),
          200,
        );
      });
      final transport = MobilityHttp(client: client);
      final service = SharedMobilityService(
        cache: _MemoryCache(),
        transport: transport,
        now: () => clock,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      final reserved = await service.search(area);
      expect(
        reserved.offers.single.reportedStatus,
        SharedMobilityStatus.reserved,
      );
      clock = clock.add(const Duration(seconds: 11));
      final released = await service.search(area, refresh: true);
      expect(
        released.offers.single.reportedStatus,
        SharedMobilityStatus.available,
      );
      clock = clock.add(const Duration(seconds: 11));
      final disabled = await service.search(area, refresh: true);
      expect(
        disabled.offers.single.reportedStatus,
        SharedMobilityStatus.disabled,
      );
      expect(
        disabled.status(disabled.offers.single, clock),
        SharedMobilityStatus.unknown,
        reason: 'REST offers no source TTL',
      );
    },
  );

  test(
    'failed refresh retains dated positions but never live availability',
    () async {
      final cache = _MemoryCache();
      cache.data[area.identity] = SharedMobilitySnapshot(
        area: area,
        fetchedUtc: now.subtract(const Duration(hours: 1)),
        offers: [
          SharedMobilityOffer(
            id: 'a',
            providerId: 'one',
            providerName: 'One',
            latitude: area.latitude,
            longitude: area.longitude,
            pickup: SharedMobilityPickup.freeFloating,
            vehicleTypes: const ['Bike'],
            reserved: false,
            disabled: false,
            reportedAvailable: true,
          ),
        ],
        truncated: false,
        feedUpdatedUtc: now,
        maxAge: const Duration(minutes: 2),
      );
      final client = MockClient((_) async => http.Response('unavailable', 503));
      final transport = MobilityHttp(client: client);
      final service = SharedMobilityService(
        cache: cache,
        transport: transport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });
      final stale = await service.search(area);
      expect(stale.refreshFailed, isTrue);
      expect(stale.fromCache, isTrue);
      expect(stale.fetchedUtc, now.subtract(const Duration(hours: 1)));
      expect(
        stale.status(stale.offers.single, now),
        SharedMobilityStatus.unknown,
      );
    },
  );

  test('HTTP 429 and timeouts without cache are surfaced', () async {
    final limited = MobilityHttp(
      client: MockClient((_) async => http.Response('Busy', 429)),
    );
    final limitedService = SharedMobilityService(
      cache: _MemoryCache(),
      transport: limited,
      now: () => now,
    );
    await expectLater(
      limitedService.search(area),
      throwsA(isA<FormatException>()),
    );
    await limitedService.dispose();
    limited.dispose();

    final timedOut = MobilityHttp(
      client: MockClient((_) async => throw TimeoutException('timeout')),
    );
    final timeoutService = SharedMobilityService(
      cache: _MemoryCache(),
      transport: timedOut,
      now: () => now,
    );
    await expectLater(
      timeoutService.search(area),
      throwsA(isA<FormatException>()),
    );
    await timeoutService.dispose();
    timedOut.dispose();
  });

  test('request budget prevents bursts and unbounded polling', () {
    var current = now;
    final budget = SharedMobilityRequestBudget(clock: () => current);
    budget.reserve();
    expect(() => budget.reserve(), throwsFormatException);
    for (var i = 1; i < 15; i++) {
      current = current.add(const Duration(seconds: 10));
      budget.reserve();
    }
    current = current.add(const Duration(seconds: 10));
    expect(() => budget.reserve(), throwsFormatException);
  });

  test('search bounds enforce national scope and maximum radius', () {
    expect(
      () => SharedMobilityArea(
        latitude: 47.0,
        longitude: 8.0,
        radiusMeters: 2001,
      ),
      throwsFormatException,
    );
    expect(
      () => SharedMobilityArea(latitude: 50, longitude: 8),
      throwsFormatException,
    );
    expect(area.contains(47.50024, 8.72334), isTrue);
    expect(area.contains(47.6, 8.8), isFalse);
  });
}
