import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';
import 'package:fpvmanager/features/offline/swiss_offline_sources.dart';

final region = OfflineRegion(
  id: 'r',
  name: 'Zürich',
  west: 8.52,
  east: 8.53,
  south: 47.37,
  north: 47.38,
);
Map<String, dynamic> sheet(bool terrain, int year) {
  final collection = terrain
      ? SwissOfflineSources.terrainCollection
      : SwissOfflineSources.imageryCollection;
  final id = terrain
      ? 'swissalti3d_${year}_2681-1248'
      : 'swiss-map-raster25_${year}_1091';
  final asset = terrain ? '${id}_2_2056_5728.tif' : '${id}_komb_1.25_2056.tif';
  return {
    'type': 'Feature',
    'collection': collection,
    'id': id,
    'bbox': [8.51, 47.36, 8.54, 47.39],
    'properties': {'datetime': '$year-01-01T00:00:00Z'},
    'assets': {
      asset: {
        'href': 'https://data.geo.admin.ch/$collection/$id/$asset',
        'type': 'image/tiff; application=geotiff; profile=cloud-optimized',
        'proj:epsg': 2056,
        'gsd': terrain ? 2 : 1.25,
        'geoadmin:variant': terrain ? null : 'komb',
        'file:checksum': '1220${List.filled(64, 'a').join()}',
        'updated': '2025-01-18T04:23:14Z',
      },
    },
  };
}

http.Response page(List<Map<String, dynamic>> items, {String? next}) =>
    http.Response(
      jsonEncode({
        'type': 'FeatureCollection',
        'features': items,
        'links': [
          if (next != null) {'rel': 'next', 'href': next},
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('official source discovery follows pagination and picks newest per sheet without WMTS requests', () async {
    var calls = 0;
    final source = SwissOfflineSources(
      now: () => DateTime.utc(2026, 10, 29),
      client: MockClient((r) async {
        calls++;
        expect(r.url.host, 'data.geo.admin.ch');
        expect(r.url.path, endsWith('/items'));
        if (r.url.path.contains('swissalti3d')) {
          if (!r.url.queryParameters.containsKey('cursor')) {
            expect(r.url.queryParameters['bbox'], '8.52,47.37,8.53,47.38');
            return page(
              [sheet(true, 2019)],
              next: r.url
                  .replace(queryParameters: {'limit': '100', 'cursor': 'next'})
                  .toString(),
            );
          }
          return page([sheet(true, 2024)]);
        }
        return page([sheet(false, 2013), sheet(false, 2019)]);
      }),
    );
    addTearDown(source.dispose);
    final first = source.discover(region), second = source.discover(region);
    expect(first, same(second));
    final plan = await first;
    expect(calls, 3);
    expect(plan.assets, hasLength(2));
    expect(plan.assets.first.sourceTime, DateTime.utc(2024));
    expect(plan.assets.last.sourceTime, DateTime.utc(2019));
    expect(plan.assets.first.toJson()['verticalReference'], 'LN02');
    expect(plan.assets.first.updatedAt, DateTime.utc(2025, 1, 18, 4, 23, 14));
    expect(plan.retrievedAt, DateTime.utc(2026, 10, 29));
    expect(
      plan.totalBytes,
      isNull,
    ); // source does not publish sizes in this fixture
    expect(plan.toJson()['readyForGlobe'], false);
  });
  test('foreign asset URLs, missing checksums and unknown height references reject incomplete plans', () async {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (s) => (s['assets'] as Map).values.first['href'] =
          'https://example.com/private.tif',
      (s) => (s['assets'] as Map).values.first.remove('file:checksum'),
      (s) => (s['assets'] as Map).values.first['proj:epsg'] = 4326,
      (s) => s['bbox'] = [8.5, 47.4, 8.4, 47.3],
      (s) => s['properties']['datetime'] = '2099-01-01T00:00:00Z',
      (s) =>
          (s['assets'] as Map).values.first['file:size'] = 1024 * 1024 * 1024,
    ]) {
      final source = SwissOfflineSources(
        client: MockClient((_) async {
          final s = sheet(true, 2024);
          mutate(s);
          return page([s]);
        }),
      );
      await expectLater(source.discover(region), throwsFormatException);
      source.dispose();
    }
  });
  test('pagination cycles, foreign pagination and missing source coverage remain explicit errors', () async {
    for (final variant in ['cycle', 'foreign', 'empty']) {
      final source = SwissOfflineSources(
        client: MockClient(
          (r) async => page(
            variant == 'empty' ? [] : [sheet(true, 2024)],
            next: variant == 'empty'
                ? null
                : variant == 'cycle'
                ? r.url.toString()
                : 'https://example.com/more',
          ),
        ),
      );
      await expectLater(source.discover(region), throwsFormatException);
      source.dispose();
    }
  });
  test('retired discovery does not publish a late plan and different concurrent regions are rejected', () async {
    final pending = Completer<http.Response>(), started = Completer<void>();
    final source = SwissOfflineSources(
      client: MockClient((_) async {
        started.complete();
        return pending.future;
      }),
    );
    final result = source.discover(region);
    await started.future;
    final other = OfflineRegion(
      id: 'different',
      name: 'Other',
      west: 8.5,
      east: 8.6,
      south: 47.3,
      north: 47.4,
    );
    await expectLater(source.discover(other), throwsStateError);
    final retired = expectLater(result, throwsStateError);
    source.dispose();
    pending.complete(page([sheet(true, 2024)]));
    await retired;
    await expectLater(source.discover(region), throwsStateError);
  });
}
