import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/drought/drought_metadata.dart';
import 'package:fpvmanager/features/mobility/drought/drought_metadata_service.dart';

class FakeMetadataCache implements DroughtMetadataCache {
  DroughtVhiMetadata? stored;
  @override
  Future<DroughtVhiMetadata?> read() async => stored?.asCached();
  @override
  Future<void> write(DroughtVhiMetadata metadata) async {
    stored = metadata;
  }
}

const collection = '{"id":"ch.swisstopo.swisseo_vhi_v100"}';
const items =
    '{"features":[{"collection":"ch.swisstopo.swisseo_vhi_v100",'
    '"properties":{"datetime":"2026-11-01T00:00:00Z"}}]}';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  test(
    'metadata refresh is bounded, coalesced and persists source timestamps',
    () async {
      var requests = 0;
      final cache = FakeMetadataCache();
      final httpClient = MockClient((req) async {
        requests++;
        return http.Response(
          req.url.path.endsWith('/items') ? items : collection,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = MobilityHttp(client: httpClient);
      final service = DroughtMetadataService(
        cache: cache,
        transport: transport,
        budget: DroughtRequestBudget(clock: () => now),
        clock: () => now,
      );
      final first = service.check();
      final second = service.check();
      expect(identical(first, second), true);
      final parsed = await first;
      expect(parsed.observedUtc, DateTime.utc(2026, 11, 1));
      expect(requests, 2);
      final reused = await service.check();
      expect(reused.fromCache, true);
      expect(requests, 2);
      await service.dispose();
      transport.dispose();
    },
  );

  test(
    'failed refresh preserves dated cache and never shows fresh status',
    () async {
      final cache = FakeMetadataCache()
        ..stored = DroughtVhiMetadata(
          collection: swissEoVhiCollection,
          fetchedUtc: now.subtract(const Duration(days: 2)),
          observedUtc: now.subtract(const Duration(days: 5)),
        );
      final transport = MobilityHttp(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final service = DroughtMetadataService(
        cache: cache,
        transport: transport,
        clock: () => now,
      );
      final data = await service.check(refresh: true);
      expect(data.refreshFailed, true);
      expect(data.fromCache, true);
      expect(data.observedUtc, cache.stored!.observedUtc);
      await service.dispose();
      transport.dispose();
    },
  );

  test('failed refresh without cache propagates failure', () async {
    final transport = MobilityHttp(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final service = DroughtMetadataService(
      cache: FakeMetadataCache(),
      transport: transport,
      clock: () => now,
    );
    await expectLater(service.check(), throwsFormatException);
    await service.dispose();
    transport.dispose();
  });

  test(
    'rejects oversized metadata and does not replace the cached observation',
    () async {
      final cache = FakeMetadataCache()
        ..stored = DroughtVhiMetadata(
          collection: swissEoVhiCollection,
          fetchedUtc: now.subtract(const Duration(days: 2)),
          observedUtc: now.subtract(const Duration(days: 3)),
        );
      final transport = MobilityHttp(
        client: MockClient(
          (request) async =>
              http.Response(utf8.decode(utf8.encode('x' * 100001)), 200),
        ),
      );
      final service = DroughtMetadataService(
        cache: cache,
        transport: transport,
        clock: () => now,
      );
      final data = await service.check(refresh: true);
      expect(data.refreshFailed, true);
      expect(cache.stored!.observedUtc, now.subtract(const Duration(days: 3)));
      await service.dispose();
      transport.dispose();
    },
  );
}
