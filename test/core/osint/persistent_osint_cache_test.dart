import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/geojson_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/core/osint/osint_dataset_store.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';

void main() {
  final source = OsintSource(
    id: 'fixture',
    name: 'Airspace fixture',
    publisher: 'Fixture authority',
    dataUri: Uri.parse('https://example.invalid/zones'),
    metadataUri: Uri.parse('https://example.invalid/metadata'),
    attribution: 'Fixture credit',
    coordinateReference: 'EPSG:4326',
    licenseName: 'Fixture storage terms',
    licenseUri: Uri.parse('https://example.invalid/terms'),
  );
  const content = '{"type":"FeatureCollection","features":[]}';
  final fetched = DateTime.utc(2026, 10, 22, 8);
  JsonOsintDatasetStore store(
    OsintCacheDatabase db, {
    Duration retention = const Duration(days: 30),
    int maxBytes = 64 * 1024 * 1024,
  }) => JsonOsintDatasetStore(
    database: () => db,
    storageTerms: source.licenseUri!,
    retention: retention,
    maxBytes: maxBytes,
  );
  OsintDataset<Map<String, dynamic>> dataset({
    DateTime? checked,
    OsintValidityPeriod? validity,
    int number = 1,
  }) => OsintDataset(
    source: source,
    data: {'type': 'FeatureCollection', 'features': [], 'fixture': number},
    fetchedAtUtc: fetched,
    lastCheckedAtUtc: checked ?? fetched,
    cacheExpiresAtUtc: (checked ?? fetched).add(const Duration(hours: 1)),
    publishedAtUtc: fetched.subtract(const Duration(hours: 2)),
    validity: validity,
    httpEtag: '"v1"',
    httpLastModified: 'Thu, 22 Oct 2026 06:00:00 GMT',
  );

  test('persistent envelope preserves source, separate dates, validators and validity', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = store(db);
    final original = dataset(
      checked: fetched.add(const Duration(minutes: 10)),
      validity: OsintValidityPeriod(
        from: fetched,
        until: fetched.add(const Duration(days: 1)),
      ),
    );
    await cache.write(original);
    final restored = (await cache.read(source, fetched))!;
    expect(restored.data, original.data);
    expect(restored.source.attribution, 'Fixture credit');
    expect(restored.source.licenseUri, source.licenseUri);
    expect(restored.fetchedAtUtc, fetched);
    expect(restored.lastCheckedAtUtc, original.lastCheckedAtUtc);
    expect(restored.publishedAtUtc, original.publishedAtUtc);
    expect(restored.httpEtag, '"v1"');
    expect(restored.httpLastModified, original.httpLastModified);
    expect(restored.validity!.untilUtc, original.validity!.untilUtc);
  });

  test('restart revalidates with ETag, retains retrieval time and serves marked old data offline', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-osint-restart-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.sqlite');
    var now = fetched, calls = 0;
    final firstDb = OsintCacheDatabase(NativeDatabase(file));
    final firstClient = MockClient((request) async {
      calls++;
      expect(request.headers['If-None-Match'], isNull);
      return http.Response(content, 200, headers: {'etag': '"v1"'});
    });
    final first = GeoJsonOsintProvider(
      source: source,
      client: firstClient,
      now: () => now,
      persistentCache: store(firstDb),
    );
    await first.fetch();
    first.dispose();
    firstClient.close();
    await firstDb.close();
    now = now.add(const Duration(hours: 2));
    final secondDb = OsintCacheDatabase(NativeDatabase(file));
    addTearDown(secondDb.close);
    var offline = false;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['If-None-Match'], '"v1"');
      if (offline) throw http.ClientException('fixture offline');
      return http.Response('', 304);
    });
    addTearDown(client.close);
    final second = GeoJsonOsintProvider(
      source: source,
      client: client,
      now: () => now,
      persistentCache: store(secondDb),
    );
    addTearDown(second.dispose);
    final revalidated = await second.fetch();
    expect(calls, 2);
    expect(revalidated.fetchedAtUtc, fetched);
    expect(revalidated.lastCheckedAtUtc, now);
    expect(revalidated.publishedAtUtc, isNull);
    expect(second.status.dataState, OsintDataState.fresh);
    offline = true;
    now = now.add(const Duration(hours: 2));
    expect(await second.fetch(), same(revalidated));
    expect(second.status.dataState, OsintDataState.refreshFailed);
    expect(second.status.freshness, OsintFreshness.stale);
    expect(second.status.servedFromCache, isTrue);
    await expectLater(
      second.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    offline = false;
    await second.fetch(forceRefresh: true);
    expect(second.status.error, isNull);
    expect(second.status.dataState, OsintDataState.fresh);
    await second.clearCache();
    expect(second.status.dataState, OsintDataState.unavailable);
    expect(await store(secondDb).read(source, now), isNull);
  });

  test('fresh disk opens without network; official expiry is independent of cache lifetime', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = store(db);
    await cache.write(
      dataset(
        validity: OsintValidityPeriod(
          until: fetched.subtract(const Duration(hours: 1)),
        ),
      ),
    );
    final client = MockClient(
      (_) async => throw StateError('must not download fresh disk data'),
    );
    addTearDown(client.close);
    final provider = GeoJsonOsintProvider(
      source: source,
      client: client,
      now: () => fetched,
      persistentCache: cache,
    );
    addTearDown(provider.dispose);
    await provider.fetch();
    expect(provider.status.freshness, OsintFreshness.fresh);
    expect(provider.status.dataState, OsintDataState.expired);
    expect(provider.status.servedFromCache, isTrue);
  });

  test(
    'Last-Modified fallback, manual refresh and no-store purge old disk data',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cache = store(db);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            content,
            200,
            headers: {'last-modified': 'Thu, 22 Oct 2026 06:00:00 GMT'},
          );
        }
        expect(request.headers['If-None-Match'], isNull);
        expect(
          request.headers['If-Modified-Since'],
          'Thu, 22 Oct 2026 06:00:00 GMT',
        );
        return http.Response(
          content,
          200,
          headers: {'cache-control': 'private, no-store'},
        );
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: source,
        client: client,
        now: () => fetched,
        persistentCache: cache,
      );
      addTearDown(provider.dispose);
      await provider.fetch();
      expect(await cache.read(source, fetched), isNotNull);
      await provider.fetch(forceRefresh: true);
      expect(calls, 2);
      expect(provider.cached!.persistable, isFalse);
      expect(await cache.read(source, fetched), isNull);
    },
  );

  test(
    'corrupt or oversized cache is discarded and download recovers',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cache = store(db);
      await cache.write(dataset());
      await db.customStatement("UPDATE osint_snapshots SET checksum='broken'");
      final client = MockClient((_) async => http.Response(content, 200));
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: source,
        client: client,
        now: () => fetched,
        persistentCache: cache,
      );
      addTearDown(provider.dispose);
      await provider.fetch();
      expect(provider.status.cacheError, isNull);
      expect(await cache.read(source, fetched), isNotNull);
      await expectLater(
        store(db, maxBytes: 8).read(source, fetched),
        throwsFormatException,
      );
      expect(await cache.read(source, fetched), isNull);
    },
  );

  test('atomic disk failure keeps old disk snapshot and downloaded data usable in memory', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = store(db);
    await cache.write(dataset(number: 1));
    await db.customStatement(
      "CREATE TRIGGER block_cache BEFORE INSERT ON osint_snapshots BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    final client = MockClient((_) async => http.Response(content, 200));
    addTearDown(client.close);
    final provider = GeoJsonOsintProvider(
      source: source,
      client: client,
      now: () => fetched,
      persistentCache: cache,
    );
    addTearDown(provider.dispose);
    final downloaded = await provider.fetch(forceRefresh: true);
    expect(downloaded.data['fixture'], isNull);
    expect(provider.status.cacheError, contains('could not be saved'));
    expect((await cache.read(source, fetched))!.data['fixture'], 1);
  });

  test('retention and changed terms invalidate public snapshots independently of obstacles', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = store(db, retention: const Duration(hours: 2));
    await cache.write(dataset());
    await db.customStatement(
      "INSERT INTO datasets VALUES ('swiss-obstacles','preserved')",
    );
    expect(
      await cache.read(source, fetched.add(const Duration(hours: 2))),
      isNull,
    );
    expect(
      (await db.customSelect('SELECT payload FROM datasets').getSingle())
          .read<String>('payload'),
      'preserved',
    );
    await cache.write(dataset());
    final changed = JsonOsintDatasetStore(
      database: () => db,
      storageTerms: Uri.parse('https://example.invalid/new-terms'),
    );
    await expectLater(changed.read(source, fetched), throwsFormatException);
    expect(await cache.read(source, fetched), isNull);
  });

  test(
    'no-cache survives 304 responses without repeated cache-control headers',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            content,
            200,
            headers: {'etag': '"v1"', 'cache-control': 'no-cache'},
          );
        }
        expect(request.headers['If-None-Match'], '"v1"');
        return http.Response('', 304);
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: source,
        client: client,
        now: () => fetched,
      );
      addTearDown(provider.dispose);
      await provider.fetch();
      await provider.fetch();
      await provider.fetch();
      expect(calls, 3);
      expect(provider.cached!.requiresRevalidation, isTrue);
    },
  );

  test('adapters can disable conditional headers for sources without browser CORS support', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers.containsKey('If-None-Match'), isFalse);
      expect(request.headers.containsKey('If-Modified-Since'), isFalse);
      return http.Response(content, 200, headers: {'etag': '"v1"'});
    });
    addTearDown(client.close);
    final provider = GeoJsonOsintProvider(
      source: source,
      client: client,
      conditionalRequests: false,
    );
    addTearDown(provider.dispose);
    await provider.fetch();
    await provider.fetch(forceRefresh: true);
    expect(calls, 2);
  });

  test('shared data states distinguish unavailable, stale, expired, failed and clock rollback', () {
    OsintProviderState<Map<String, dynamic>> status(
      OsintDataset<Map<String, dynamic>>? data,
      DateTime now, {
      OsintProviderException? error,
    }) => OsintProviderState(
      update: error == null ? OsintUpdateState.ready : OsintUpdateState.failed,
      freshness: data?.freshnessAt(now) ?? OsintFreshness.notLoaded,
      checkedAtUtc: now,
      dataset: data,
      error: error,
    );
    expect(status(null, fetched).dataState, OsintDataState.unavailable);
    expect(status(dataset(), fetched).dataState, OsintDataState.fresh);
    expect(
      status(dataset(), fetched.add(const Duration(hours: 1))).dataState,
      OsintDataState.stale,
    );
    expect(
      status(dataset(), fetched.subtract(const Duration(seconds: 1))).dataState,
      OsintDataState.clockSkew,
    );
    expect(
      status(
        dataset(validity: OsintValidityPeriod(until: fetched)),
        fetched,
      ).dataState,
      OsintDataState.expired,
    );
    expect(
      status(
        dataset(),
        fetched,
        error: const OsintProviderException(
          providerId: 'fixture',
          kind: OsintFailureKind.network,
          message: 'offline',
        ),
      ).dataState,
      OsintDataState.refreshFailed,
    );
  });

  test('v1 cache upgrade retains obstacle generations', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-osint-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.sqlite');
    final previous = OsintCacheDatabase(NativeDatabase(file));
    await previous.customStatement(
      "INSERT INTO datasets VALUES ('swiss-obstacles','old-generation')",
    );
    await previous.customStatement('DROP TABLE osint_snapshots');
    await previous.customStatement('PRAGMA user_version=1');
    await previous.close();
    final upgraded = OsintCacheDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await store(upgraded).write(dataset());
    expect(await store(upgraded).read(source, fetched), isNotNull);
    expect(
      (await upgraded.customSelect('SELECT payload FROM datasets').getSingle())
          .read<String>('payload'),
      'old-generation',
    );
  });
}
