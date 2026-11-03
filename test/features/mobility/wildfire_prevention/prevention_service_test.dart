import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_models.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_service.dart';

class MemoryPreventionCache implements PreventionCache {
  final Map<String, PreventionSnapshot> values = {};
  @override
  Future<PreventionSnapshot?> read(String key) async => values[key]?.cached();
  @override
  Future<void> write(String key, PreventionSnapshot snapshot) async {
    values[key] = snapshot;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  const lat = 47.37;
  const lon = 8.54;
  final response = jsonEncode({
    'results': [
      {
        'layerBodId': preventionLayerId,
        'featureId': 1,
        'properties': {
          'title_de': 'Mahnung zu sorgfältigem Umgang mit Feuer im Wald und in Waldesnähe/im Freien',
          'description_de': 'Feuern möglichst unterlassen',
          'canton': 'ZH',
          'name_de': 'Kanton Zürich',
          'valid_from': '19.10.2026',
        },
      },
    ],
  });

  test(
    'bounded point request, legend, de-duplication and cached reread',
    () async {
      final uri = preventionIdentifyUrl(lat, lon);
      expect(uri.scheme, 'https');
      expect(uri.queryParameters['geometryType'], 'esriGeometryPoint');
      expect(uri.queryParameters['tolerance'], '0');
      expect(uri.queryParameters['layers'], 'all:$preventionLayerId');
      expect(uri.queryParameters['limit'], '50');
      expect(uri.queryParameters['geometry'], '8.540000,47.370000');
      var requests = 0;
      final mock = MockClient((request) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (request.url.path.endsWith('/legend')) {
          return http.Response('Datenstand: 02.11.2026 12:00', 200);
        }
        return http.Response.bytes(
          utf8.encode(response),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final httpTransport = MobilityHttp(client: mock);
      final service = PreventionService(
        cache: MemoryPreventionCache(),
        transport: httpTransport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        httpTransport.dispose();
        mock.close();
      });
      final results = await Future.wait([
        service.search(lat, lon),
        service.search(lat, lon),
      ]);
      expect(requests, 2); // identify and one publication metadata request
      expect(results.first.measures.single.canton, 'ZH');
      expect(results.first.publicationRaw, '02.11.2026 12:00');
      expect((await service.search(lat, lon)).fromCache, isTrue);
      expect(requests, 2);
    },
  );

  test(
    'failed refresh retains dated measures without declaring all-clear',
    () async {
      final cache = MemoryPreventionCache();
      final saved = parsePreventionIdentify(
        response,
        latitude: lat,
        longitude: lon,
        fetchedUtc: now.subtract(const Duration(days: 1)),
        publicationRaw: '02.11.2026 12:00',
      );
      cache.values['47.3700:8.5400'] = saved;
      final transport = MobilityHttp(
        client: MockClient((_) async => http.Response('offline', 503)),
      );
      final service = PreventionService(
        cache: cache,
        transport: transport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
      });
      final result = await service.search(lat, lon, refresh: true);
      expect(result.fromCache, isTrue);
      expect(result.refreshFailed, isTrue);
      expect(result.isOutdated(now), isTrue);
      expect(result.measures.single.category, PreventionCategory.caution);
      expect(result.fetchedUtc, saved.fetchedUtc);
    },
  );

  test(
    'failed legend does not erase official measures; unknown freshness',
    () async {
      final transport = MobilityHttp(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/legend')) {
            return http.Response('', 503);
          }
          return http.Response.bytes(
            utf8.encode(response),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final service = PreventionService(
        cache: MemoryPreventionCache(),
        transport: transport,
        now: () => now,
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
      });
      final result = await service.search(lat, lon);
      expect(result.measures, hasLength(1));
      expect(result.publicationRaw, isNull);
      expect(result.isOutdated(now), isTrue);
    },
  );

  test('timeout without cache reports unknown, not zero measures', () async {
    final transport = MobilityHttp(
      client: MockClient(
        (_) async => throw TimeoutException('connection failed'),
      ),
    );
    final service = PreventionService(
      cache: MemoryPreventionCache(),
      transport: transport,
      now: () => now,
    );
    addTearDown(() async {
      await service.dispose();
      transport.dispose();
    });
    await expectLater(service.search(lat, lon), throwsFormatException);
  });

  test('budget prevents accidental polling', () {
    var clock = now;
    final budget = PreventionRequestBudget(clock: () => clock);
    budget.reserve();
    expect(() => budget.reserve(), throwsFormatException);
    for (var i = 1; i < 12; i++) {
      clock = clock.add(const Duration(seconds: 11));
      budget.reserve();
    }
    clock = clock.add(const Duration(seconds: 11));
    expect(() => budget.reserve(), throwsFormatException);
  });

  test('invalid coordinates never trigger a network request', () {
    expect(() => preventionIdentifyUrl(48.9, 8.6), throwsFormatException);
    expect(() => preventionIdentifyUrl(47.2, 20), throwsFormatException);
  });
}
