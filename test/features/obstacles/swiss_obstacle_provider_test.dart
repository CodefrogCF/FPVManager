import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/obstacles/obstacle_models.dart';
import 'package:fpvmanager/features/obstacles/swiss_obstacle_heights.dart';
import 'package:fpvmanager/features/obstacles/swiss_obstacle_provider.dart';

import '../../helpers/obstacle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'LN02 conversion matches independent official REFRAME Bern control point',
    () async {
      final heights = await SwissObstacleHeights.load();
      // REFRAME wgs84tolv95 (600m ellipsoid) -> Bessel 550.3778010914;
      // besseltoln02 at LV95 2600000/1200000 -> LN02 551.0533111950.
      expect(
        heights.ellipsoidHeight(7.438632, 46.951083, 551.0533111950),
        closeTo(600, 0.01),
      );
      expect(heights.ellipsoidHeight(0, 0, 500), isNull);
      expect(heights.ellipsoidHeight(8, 46, double.nan), isNull);
      expect(() => SwissObstacleHeights(ByteData(50)), throwsFormatException);
      final first = await rootBundle.load('assets/geo/chgeo2004_ln02.bin');
      expect(first.lengthInBytes, 565748);
    },
  );
  test('STAC discovery, unchanged checksum and failed replacement preserve provenance and snapshot', () async {
    final cache = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(cache.close);
    var bytes = obstacleKmz(obstacleKml());
    var updated = '2026-10-20T00:00:00Z',
        format = 'application/vnd.google-earth.kmz';
    var downloads = 0, metadataChecks = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/items')) {
        metadataChecks++;
        return http.Response(
          jsonEncode(
            obstacleStac(
              checksum: '1220${sha256.convert(bytes)}',
              updated: updated,
              format: format,
            ),
          ),
          200,
        );
      }
      downloads++;
      return http.Response.bytes(bytes, 200);
    });
    addTearDown(client.close);
    var clock = DateTime.utc(2026, 10, 21);
    final provider = SwissObstacleProvider(
      cache: cache,
      client: client,
      clock: () => clock,
    );
    addTearDown(provider.dispose);
    final first = await provider.fetch(forceRefresh: true);
    expect(first.data.count, 1);
    expect(first.data.assetUrl, 'https://data.geo.admin.ch/fixture/full.kmz');
    expect(downloads, 1);
    expect(metadataChecks, 1);
    clock = clock.add(const Duration(hours: 1));
    updated = '2026-10-21T00:00:00Z';
    final same = await provider.fetch(forceRefresh: true);
    expect(downloads, 1);
    expect(metadataChecks, 2);
    expect(same.fetchedAtUtc, first.fetchedAtUtc);
    expect(same.data.sourceUpdated, DateTime.utc(2026, 10, 21));
    expect(same.data.checkedAt, clock);
    bytes = Uint8List.fromList([1, 2, 3]);
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(provider.status.update, OsintUpdateState.failed);
    expect((await cache.obstacleSnapshot())!.key, first.data.key);
    expect(
      await cache.queryObstacles(
        first.data.key,
        const ObstacleViewport(8.3, 46.6, 8.5, 46.8),
        {...ObstacleCategory.values},
      ),
      hasLength(1),
    );
    format = 'application/zip';
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(
        predicate((e) => e.toString().contains('No supported full WGS84 KMZ')),
      ),
    );
    expect(provider.status.dataset!.data.key, first.data.key);
  });
  test('staged records are invisible and duplicate IDs cannot replace a valid snapshot', () async {
    final cache = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(cache.close);
    var kml = obstacleKml();
    final client = MockClient(
      (r) async => r.url.path.endsWith('/items')
          ? http.Response(
              jsonEncode(
                obstacleStac(
                  checksum: '1220${sha256.convert(obstacleKmz(kml))}',
                ),
              ),
              200,
            )
          : http.Response.bytes(obstacleKmz(kml), 200),
    );
    addTearDown(client.close);
    final provider = SwissObstacleProvider(client: client, cache: cache);
    addTearDown(provider.dispose);
    final good = await provider.fetch(forceRefresh: true);
    kml = obstacleKml(
      extra: obstacleKml().split('<Document>')[1].split('</Document>')[0],
    );
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect((await cache.obstacleSnapshot())!.key, good.data.key);
    expect(
      (await cache
              .customSelect('SELECT count(*) AS n FROM obstacles')
              .getSingle())
          .read<int>('n'),
      1,
    );
    final empty = await cache.queryObstacles(
      good.data.key,
      const ObstacleViewport(8.3, 46.6, 8.5, 46.8),
      {ObstacleCategory.masts},
    );
    expect(empty, isEmpty);
  });
  test('persistent snapshot can be reopened offline and stale is distinct from coverage/validity', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-obstacle-cache-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.sqlite');
    final firstCache = OsintCacheDatabase(NativeDatabase(file));
    final bytes = obstacleKmz(
      obstacleKml(
        metadata:
            '<ExtendedData><SchemaData>'
            '<SimpleData name="datasetValidFrom">2026-10-20 00:00:00</SimpleData>'
            '<SimpleData name="datasetValidTo">2026-10-21 00:00:00</SimpleData></SchemaData></ExtendedData>',
      ),
    );
    final client = MockClient(
      (r) async => r.url.path.endsWith('/items')
          ? http.Response(jsonEncode(obstacleStac()), 200)
          : http.Response.bytes(bytes, 200),
    );
    final first = SwissObstacleProvider(
      cache: firstCache,
      client: client,
      clock: () => DateTime.utc(2026, 10, 20),
    );
    await first.fetch(forceRefresh: true);
    first.dispose();
    client.close();
    await firstCache.close();
    final offline = MockClient(
      (_) async => throw StateError('offline must not be contacted'),
    );
    addTearDown(offline.close);
    final reopened = OsintCacheDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final second = SwissObstacleProvider(
      cache: reopened,
      client: offline,
      clock: () => DateTime.utc(2026, 10, 23),
    );
    addTearDown(second.dispose);
    await second.loadCached();
    expect(second.status.freshness, OsintFreshness.stale);
    expect(
      second.status.dataset!.validity!.at(DateTime.utc(2026, 10, 23)).name,
      'expired',
    );
    final records = await reopened.queryObstacles(
      second.status.dataset!.data.key,
      const ObstacleViewport(8.3, 46.6, 8.5, 46.8),
      {ObstacleCategory.powerLines},
    );
    expect(records.single.id, 'source-1');
    await expectLater(
      second.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(second.status.dataset, isNotNull);
  });
  test(
    'unsupported projection or non-official asset hosts are not downloaded',
    () async {
      for (final invalid in ['host', 'projection', 'checksum']) {
        final cache = OsintCacheDatabase(NativeDatabase.memory());
        var downloads = 0;
        final client = MockClient((r) async {
          if (!r.url.path.endsWith('/items')) {
            downloads++;
            return http.Response('', 200);
          }
          final stac = obstacleStac();
          final asset =
              ((stac['features'] as List).single['assets'] as Map).values.single
                  as Map;
          if (invalid == 'host') {
            asset['href'] = 'https://invalid.test/evil.kmz';
          }
          if (invalid == 'projection') asset['proj:epsg'] = 2056;
          if (invalid == 'checksum') asset['file:checksum'] = 'unknown';
          return http.Response(jsonEncode(stac), 200);
        });
        final provider = SwissObstacleProvider(cache: cache, client: client);
        await expectLater(
          provider.fetch(forceRefresh: true),
          throwsA(isA<OsintProviderException>()),
        );
        expect(downloads, 0);
        provider.dispose();
        client.close();
        await cache.close();
      }
    },
  );
}
