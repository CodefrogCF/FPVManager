import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/offline/offline_map_store_native.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';

void main() {
  test('cached terrain preserves the real mesh but removes live availability metadata', () {
    final original = File('test/fixtures/offline/root.terrain')
        .readAsBytesSync();
    final local = withoutTerrainMetadata(original);
    expect(local.length, lessThan(original.length));
    expect(local.sublist(0, 100), original.sublist(0, 100));
    expect(withoutTerrainMetadata(local), local);
    expect(
      () => withoutTerrainMetadata(Uint8List.sublistView(original, 0, 90)),
      throwsFormatException,
    );
  });
  late OsintCacheDatabase database;
  late NativeOfflineMapStore store;
  var calls = 0, fail = false, noStore = false;
  final region = OfflineRegion(
    id: 'region',
    name: 'Test',
    west: 8.39,
    south: 46.69,
    east: 8.41,
    north: 46.71,
  );
  late String key;
  group('offline store operations', () {
    test('closing the cache cancels queued requests without starting more downloads', () async {
      var calls = 0;
      final started = Completer<void>(), gate = Completer<void>();
      final burst = NativeOfflineMapStore(
        database: database,
        client: MockClient((_) async {
          if (++calls == 8) started.complete();
          await gate.future;
          return http.Response.bytes([255, 216, 255, 217], 200);
        }),
      );
      final jobs = [
        for (var i = 0; i < 24; i++)
          burst
              .load('imagery/topographic/6/$i/0.jpeg')
              .then((_) => true, onError: (Object _) => false),
      ];
      await started.future;
      final closing = burst.close();
      gate.complete();
      final replies = await Future.wait(jobs);
      await closing;
      expect(calls, 8);
      expect(replies.where((ok) => !ok).length, 16);
    });
    test('a profile-sized burst queues downloads with bounded concurrency and deduplicates matching requests', () async {
      var active = 0, peak = 0, calls = 0;
      final started = Completer<void>(), gate = Completer<void>();
      final burst = NativeOfflineMapStore(
        database: database,
        client: MockClient((request) async {
          calls++;
          active++;
          if (active > peak) peak = active;
          if (active == 8 && !started.isCompleted) started.complete();
          await gate.future;
          active--;
          return http.Response.bytes([255, 216, 255, 217], 200);
        }),
      );
      addTearDown(burst.close);
      final jobs = [
        for (var i = 0; i < 24; i++)
          burst.load('imagery/topographic/6/$i/0.jpeg'),
      ];
      expect(burst.load('imagery/topographic/6/0/0.jpeg'), same(jobs.first));
      await started.future;
      expect(calls, 8);
      gate.complete();
      expect((await Future.wait(jobs)).length, 24);
      expect(peak, 8);
      expect(calls, 24);
    });
    setUp(() {
      calls = 0;
      fail = false;
      noStore = false;
      final range = region.range(12, terrain: false);
      key = 'imagery/topographic/12/${range.left}/${range.bottom}.jpeg';
      database = OsintCacheDatabase(NativeDatabase.memory());
      store = NativeOfflineMapStore(
        database: database,
        client: MockClient((request) async {
          calls++;
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(request.followRedirects, isFalse);
          if (fail) throw http.ClientException('Network unavailable');
          return http.Response.bytes(
            [255, 216, 255, 217],
            200,
            headers: {if (noStore) 'cache-control': 'no-store'},
          );
        }),
      );
    });
    tearDown(() async {
      await store.close();
      await database.close();
    });
    test('Swiss region estimates and WMTS/geographic TMS ranges retain the correct axis order', () {
      expect(region.range(0, terrain: true).left, 1);
      expect(region.range(0, terrain: true).bottom, 0);
      expect(region.range(0, terrain: false).left, 0);
      expect(region.includesKey(key), isTrue);
      expect(region.includesKey('terrain/20250101/0/0/0.terrain'), isTrue);
      expect(region.includesKey('imagery/relief/12/1/1.png'), isFalse);
      expect(region.expectedTiles, greaterThan(10));
      expect(region.expectedTiles, lessThan(5000));
      expect(region.estimatedBytes, region.expectedTiles * 45 * 1024);
      expect(
        () => OfflineRegion(
          id: 'bad',
          name: 'bad',
          west: -180,
          south: -90,
          east: 180,
          north: 90,
        ),
        throwsFormatException,
      );
    });
    test('viewed supported tiles persist, reopen offline and missing tiles never use the network', () async {
      await store.setRegions([region]);
      final original = await store.load(key);
      expect(calls, 1);
      expect((await store.tiles()).single.bytes, 4);
      fail = true;
      final reopened = NativeOfflineMapStore(
        database: database,
        client: MockClient((_) async => throw StateError('Unexpected network')),
      );
      final cached = await reopened.load(key, cacheOnly: true);
      expect(cached.bytes, original.bytes);
      expect(cached.fetchedAt, original.fetchedAt);
      await expectLater(
        reopened.load('imagery/topographic/0/0/0.jpeg', cacheOnly: true),
        throwsStateError,
      );
      await reopened.close();
      await expectLater(
        store.load('imagery/topographic/0/0/0.jpeg'),
        throwsA(isA<http.ClientException>()),
      );
      expect((await store.load(key, cacheOnly: true)).bytes, original.bytes);
    });
    test('no-store and unsupported providers cannot enter the cache; shared region deletion prunes safely', () async {
      await store.setRegions([region]);
      noStore = true;
      await store.load(key);
      expect(await store.tiles(), isEmpty);
      noStore = false;
      await store.load(key);
      expect(await store.tiles(), hasLength(1));
      final duplicate = OfflineRegion.fromJson({
        ...region.toJson(),
        'id': 'overlap',
      });
      await store.setRegions([region, duplicate]);
      await store.setRegions([duplicate]);
      expect(await store.tiles(), hasLength(1));
      await store.clear();
      expect(await store.tiles(), isEmpty);
      final before = calls;
      for (final invalid in [
        '../secret',
        'https://attacker.invalid/',
        'imagery/satellite/0/0/0.jpeg',
        'terrain/20/0/0.terrain',
        'imagery/topographic/4/999/0.jpeg',
      ]) {
        await expectLater(store.load(invalid), throwsFormatException);
      }
      expect(calls, before);
    });
    test(
      'removing a region during a tile request does not recreate deleted data',
      () async {
        await store.setRegions([region]);
        final response = Completer<http.Response>(),
            started = Completer<void>();
        final slow = NativeOfflineMapStore(
          database: database,
          client: MockClient((_) async {
            started.complete();
            return response.future;
          }),
        );
        final pending = slow.load(key);
        await started.future;
        await store.clear();
        response.complete(http.Response.bytes([255, 216, 255, 217], 200));
        await pending;
        expect(await store.tiles(), isEmpty);
        await slow.close();
      },
    );
    test('dated metadata stays local and preserves the published terrain time and extension availability', () {
      final meta = {
        'format': 'quantized-mesh-1.0',
        'projection': 'EPSG:4326',
        'metadataAvailability': 10,
        'tiles': ['20250101/{z}/{x}/{y}.terrain?v={version}'],
        'parentUrl': 'https://unrelated.invalid/',
      };
      final result = sanitizeOfflineTile(
        'terrain/layer.json',
        Uint8List.fromList(utf8.encode(jsonEncode(meta))),
      );
      final decoded = jsonDecode(utf8.decode(result.bytes)) as Map;
      expect(decoded['tiles'], ['20250101/{z}/{x}/{y}.terrain']);
      expect(decoded['metadataAvailability'], 10);
      expect(decoded.containsKey('parentUrl'), isFalse);
      final local = jsonDecode(
        utf8.decode(
          cachedTerrainMetadata(result.bytes, [
            'terrain/20250101/0/0/0.terrain',
            'terrain/20250101/0/1/0.terrain',
            'terrain/20250101/2/4/3.terrain',
          ]),
        ),
      ) as Map;
      expect(local['metadataAvailability'], isNull);
      expect(local['maxzoom'], 2);
      expect((local['available'] as List)[2], [
        {'startX': 4, 'endX': 4, 'startY': 3, 'endY': 3},
      ]);
      expect(
        offlineSourceUri('terrain/20250101/18/1/1.terrain')!.path,
        contains('/v1/20250101/18/1/1.terrain'),
      );
      meta['tiles'] = ['https://unrelated.invalid/{z}/{x}/{y}.terrain'];
      expect(
        () => sanitizeOfflineTile(
          'terrain/layer.json',
          Uint8List.fromList(utf8.encode(jsonEncode(meta))),
        ),
        throwsFormatException,
      );
    });
  }); // The migration test runs without the store group's database.

  test(
    'cache v2 migration preserves public snapshots and adds map tables',
    () async {
      final old = OsintCacheDatabase(
        NativeDatabase.memory(
          setup: (db) {
            db.execute('PRAGMA user_version=2');
            db.execute(
              'CREATE TABLE datasets(provider TEXT PRIMARY KEY,payload TEXT NOT NULL)',
            );
            db.execute("INSERT INTO datasets VALUES('existing','retained')");
          },
        ),
      );
      addTearDown(old.close);
      expect(
        (await old.customSelect('SELECT payload FROM datasets').getSingle())
            .read<String>('payload'),
        'retained',
      );
      expect(
        await old.customSelect('SELECT * FROM offline_regions').get(),
        isEmpty,
      );
    },
  );
}
