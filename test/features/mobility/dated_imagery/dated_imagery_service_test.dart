import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_models.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_service.dart';

class MemoryImageryCache implements DatedImageryCache {
  final stored = <DatedImageryProduct, DatedImagerySnapshot>{};
  @override
  Future<DatedImagerySnapshot?> read(DatedImageryProduct product) async =>
      stored[product]?.saved();
  @override
  Future<void> write(DatedImagerySnapshot snapshot) async {
    stored[snapshot.product] = snapshot;
  }
}

const collection = '{"id":"ch.swisstopo.swisseo_s2-sr_v200"}';
const items =
    '{"features":[{"id":"scene-1",'
    '"collection":"ch.swisstopo.swisseo_s2-sr_v200",'
    '"bbox":[7.1,46.1,8.1,47.4],'
    '"properties":{"datetime":"2026-10-30T10:00:00Z"}}]}';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  test(
    'bounded STAC queries are deliberate, coalesced and persisted as metadata',
    () async {
      final cache = MemoryImageryCache();
      var count = 0;
      final httpClient = MockClient((request) async {
        count++;
        if (request.url.path.endsWith('/items')) {
          expect(request.url.queryParameters['limit'], '16');
          expect(request.url.queryParameters['sortby'], '-properties.datetime');
          expect(request.url.queryParameters['bbox'], isNotEmpty);
          expect(request.url.queryParameters['datetime'], contains('/..'));
        }
        return http.Response(
          request.url.path.endsWith('/items') ? items : collection,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = MobilityHttp(client: httpClient);
      final service = DatedImageryService(
        cache: cache,
        transport: transport,
        budget: DatedImageryRequestBudget(clock: () => now),
        clock: () => now,
      );
      final first = service.search(
        product: DatedImageryProduct.swissEo,
        latitude: 46.9,
        longitude: 7.5,
        radiusMetres: 1000,
      );
      final second = service.search(
        product: DatedImageryProduct.swissEo,
        latitude: 46.9,
        longitude: 7.5,
        radiusMetres: 1000,
      );
      expect(identical(first, second), true);
      expect((await first).items.single.id, 'scene-1');
      expect(count, 2);
      expect(
        (await service.search(
          product: DatedImageryProduct.swissEo,
          latitude: 46.9,
          longitude: 7.5,
          radiusMetres: 1000,
        )).fromCache,
        true,
      );
      expect(count, 2);
      await service.dispose();
      transport.dispose();
    },
  );

  test('failed refresh retains dated snapshot, without silently claiming current coverage', () async {
    final area = DatedImageryService.bounds(46.9, 7.5, 1000);
    final cache = MemoryImageryCache()
      ..stored[DatedImageryProduct.swissEo] = DatedImagerySnapshot(
        product: DatedImageryProduct.swissEo,
        fetchedUtc: now.subtract(const Duration(days: 2)),
        area: area,
        items: const [],
        incomplete: true,
      );
    final transport = MobilityHttp(
      client: MockClient((_) async => http.Response('busy', 429)),
    );
    final service = DatedImageryService(
      cache: cache,
      transport: transport,
      clock: () => now,
    );
    final snap = await service.search(
      product: DatedImageryProduct.swissEo,
      latitude: 46.9,
      longitude: 7.5,
      radiusMetres: 1000,
      refresh: true,
    );
    expect(snap.refreshFailed, true);
    expect(snap.fromCache, true);
    expect(snap.incomplete, true);
    expect(snap.isOld(now), true);
    await service.dispose();
    transport.dispose();
  });

  test('without previous metadata, auth errors and timeouts are not empty successes', () async {
    final transport = MobilityHttp(
      client: MockClient((_) async => http.Response('forbidden', 403)),
    );
    final service = DatedImageryService(
      cache: MemoryImageryCache(),
      transport: transport,
      clock: () => now,
    );
    await expectLater(
      service.search(
        product: DatedImageryProduct.rapidMapping,
        latitude: 46.9,
        longitude: 7.5,
        radiusMetres: 500,
      ),
      throwsFormatException,
    );
    await service.dispose();
    transport.dispose();
  });

  test('Blatten search includes both RGB mosaics when a STAC page contains oblique photos', () async {
    const area = [7.75, 46.37, 7.86, 46.46];
    final provider = DatedImageryProduct.rapidMapping.collection;
    Map<String, Object?> item(String id, String date, [Map? assets]) => {
      'id': id,
      'collection': provider,
      'bbox': area,
      'properties': {'datetime': date},
      'assets': ?assets,
    };
    final transport = MobilityHttp(
      client: MockClient((request) async {
        final id = request.url.pathSegments.last;
        final Object body;
        if (id == provider) {
          body = {'id': provider};
        } else if (id == 'items') {
          body = {
            'features': [item('ram-photo', '2025-05-30T09:32:00Z')],
          };
        } else {
          body = item(
            id,
            id == blattenFollowupOrthophoto
                ? '2025-09-19T09:47:00Z'
                : '2025-05-30T08:09:00Z',
            {
              'rgb-mosaic': {
                'href': 'https://data.geo.admin.ch/$id-rgb-mosaic.tif',
                'type': 'image/tiff',
                'proj:epsg': 2056,
              },
              'nrgb-16bit': {
                'href': 'https://data.geo.admin.ch/$id-nrgb-16bit.tif',
                'type': 'image/tiff',
                'proj:epsg': 2056,
              },
            },
          );
        }
        return http.Response(jsonEncode(body), 200);
      }),
    );
    final service = DatedImageryService(
      cache: MemoryImageryCache(),
      transport: transport,
      clock: () => now,
    );
    addTearDown(service.dispose);
    addTearDown(transport.dispose);
    final result = await service.search(
      product: DatedImageryProduct.rapidMapping,
      latitude: 46.419,
      longitude: 7.818,
      radiusMetres: 1000,
    );
    expect(
      result.items
          .where((item) => item.displayAsset != null)
          .map((item) => item.id),
      [blattenFollowupOrthophoto, blattenRapidMappingOrthophoto],
    );
    expect(result.items.first.displayAsset!.href, endsWith('-rgb-mosaic.tif'));
  });

  test(
    'spatial bounds and hourly rate limits enforce narrow catalogue searches',
    () {
      expect(
        () => DatedImageryService.bounds(46.9, 7.5, 5001),
        throwsFormatException,
      );
      expect(
        () => DatedImageryService.bounds(91, 7.5, 1000),
        throwsFormatException,
      );
      final b = DatedImageryService.bounds(46.9, 7.5, 500);
      expect(b[0], lessThan(7.5));
      expect(b[2], greaterThan(7.5));
      var time = now;
      final budget = DatedImageryRequestBudget(clock: () => time);
      budget.reserve();
      expect(budget.reserve, throwsFormatException);
      time = time.add(const Duration(seconds: 16));
      budget.reserve();
    },
  );
}
