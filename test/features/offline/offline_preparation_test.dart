import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/offline/offline_map_store_native.dart';
import 'package:fpvmanager/features/offline/offline_preparation_storage_native.dart';
import 'package:fpvmanager/features/offline/offline_preparation_options.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('25 km and nationwide options preserve selected detail and assets across storage', () {
    const options = OfflinePreparationOptions(
      latitude: 47.3,
      longitude: 8.5,
      radiusKm: 25,
      name: 'Region',
      maps: ['topographic', 'satellite', 'relief'],
    );
    final region = OfflineRegion.fromJson(options.region().toJson());
    expect(region.radiusKm, 25);
    expect(region.maps, ['topographic', 'satellite', 'relief']);
    expect(options.estimate().tiles, greaterThan(5000));
    const country = OfflinePreparationOptions(
      latitude: 46.8,
      longitude: 8.3,
      radiusKm: 1,
      name: 'Schweiz',
      maps: ['satellite'],
      wholeSwitzerland: true,
      terrainLevel: 12,
    );
    expect(country.region().west, 5.95);
    expect(country.region().east, 10.5);
    expect(country.request()['scope'], 'switzerland');
    expect(country.estimate().bytes, greaterThan(1024 * 1024 * 1024));
  });
  test('native preparation survives restart and only publishes a successful staged replacement', () async {
    final database = OsintCacheDatabase(NativeDatabase.memory()),
        store = NativeOfflineMapStore(database: database);
    addTearDown(() async {
      await store.close();
      await database.close();
    });
    final old = OfflineRegion(
      id: 'old',
      name: 'Previous',
      west: 8.4,
      east: 8.41,
      south: 47.3,
      north: 47.31,
    );
    await store.setRegions([old]);
    const options = OfflinePreparationOptions(
      latitude: 47.3,
      longitude: 8.5,
      radiusKm: 1,
      name: 'New',
      maps: ['satellite'],
      includeTerrain: false,
    );
    final config = options.request(),
        stage = NativeOfflinePreparationStorage(store),
        job = await stage.begin(config),
        id = job['id'] as String;
    final range = options.region().range(0, terrain: false),
        key = 'imagery/satellite/0/${range.left}/${range.bottom}.png';
    await stage.bindSources(id, 'a' * 64);
    await stage.write(id, key, utf8.encode('test pixels'), 1024 * 1024);
    expect(
      await stage.remainingBytes(config),
      (config['estimatedBytes'] as int) - utf8.encode('test pixels').length,
    );
    expect((await store.regions()).single.id, 'old');
    final resumed = NativeOfflinePreparationStorage(store),
        again = await resumed.begin({...config, 'id': 'new-id'});
    expect(again['id'], id);
    expect(await resumed.has(id, key), isTrue);
    await resumed.bindSources(id, 'b' * 64);
    expect(await resumed.has(id, key), isFalse);
    await resumed.write(id, key, utf8.encode('test pixels'), 1024 * 1024);
    await expectLater(
      resumed.write(id, '../bad', utf8.encode('bad'), 1024 * 1024),
      throwsFormatException,
    );
    final committed = await resumed.commit({
      ...config,
      'packageId': id,
      'packageActive': true,
      'packageTiles': 1,
      'preparedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    expect(committed.packageTiles, 1);
    expect((await store.regions()).last.packageId, id);
    expect(
      (await store.load('prepared/$id/$key', cacheOnly: true)).bytes,
      utf8.encode('test pixels'),
    );
  });
}
