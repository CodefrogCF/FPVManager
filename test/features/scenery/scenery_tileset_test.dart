import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_tileset_options.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';

import '../../support/scenery_tileset_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Dart compiled catalog matches the fixture validated by the JS renderer',
    () {
      final fixture = jsonDecode(
        File('test/fixtures/scenery/remote_tileset_catalog.json')
            .readAsStringSync(),
      );
      expect(
        SceneryAssetProviders().compile([sceneryTilesetFixture()]),
        fixture,
      );
    },
  );
  test('backup roundtrip preserves URL, cache policy, quality, corrections and activation', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    final repository = SceneryRepository(db);
    try {
      final doc = sceneryTilesetFixture().toJson();
      doc['assets'][0]['tileset']['correction'] = {
        'eastM': 12,
        'upM': 3,
        'headingDeg': 5,
      };
      doc['assets'][0]['tileset']['cachePolicy'] = 'provider';
      doc['assets'][0]['tileset']['maximumScreenSpaceError'] = 24;
      final original = SceneryManifest.fromJson(doc);
      await repository.create(original);
      final backup = BackupRepository(db), bytes = await backup.create();
      await repository.update(original.withEnabled(false));
      await backup.restore(await backup.preview(bytes));
      expect((await repository.list()).single.toJson(), original.toJson());
    } finally {
      await db.close();
    }
  });
  test('remote provider compiles an HTTPS URL, quality, cache policy and corrections without relocating it', () {
    final m = sceneryTilesetFixture(),
        catalog = SceneryAssetProviders().compile([sceneryTilesetFixture()]);
    final item = (catalog['sceneries'] as List).single as Map;
    final asset = (item['assets'] as List).single as Map;
    expect(asset['kind'], '3d-tiles');
    expect(asset['url'], m.assets.single.uri);
    expect(asset.containsKey('path'), false);
    expect(asset['options']['maximumScreenSpaceError'], 16);
    expect(asset['options']['cachePolicy'], 'no-store');
    expect(asset['options']['correction']['scale'], 1);
    expect(item['heightAlignmentMode'], 'fixed');
    expect(item['physicalCollisionsEnabled'], false);
    expect(item['sourceUrl'], 'https://provider.example/terms');
  });
  test('unsafe URLs, unsupported formats, stale/missing bounds and invalid options fail', () {
    for (final url in [
      'http://provider.example/a.json',
      'file:///a.json',
      'https://u:p@provider.example/a.json',
      'https://provider.example/a.json#key',
      'https://provider.example/a b.json',
    ]) {
      expect(() => validateTilesetUrl(url), throwsFormatException);
    }
    final mutations = <void Function(Map<String, dynamic>)>[
      (d) => d['assets'][0]['tileset']['version'] = '2.0',
      (d) => d['assets'][0]['tileset']['maximumScreenSpaceError'] = 0,
      (d) => d['assets'][0]['tileset']['cachePolicy'] = 'download-all',
      (d) => d['assets'][0]['tileset'].remove('boundingSphere'),
      (d) => d['assets'][0]['tileset']['correction'] = {'scale': 0},
      (d) => d['anchor']['reference'] = 'TERRAIN_RELATIVE',
      (d) => d['assets'][0]['format'] = 'glb',
      (d) => d['assets'][0]['role'] = 'collision',
    ];
    for (final mutate in mutations) {
      final doc = sceneryTilesetFixture().toJson();
      mutate(doc);
      expect(() => SceneryManifest.fromJson(doc), throwsFormatException);
    }
  });
  test('correction and SSE changes survive immutable serialization and update conservative coverage', () {
    final original = sceneryTilesetFixture(), doc = original.toJson();
    doc['assets'][0]['tileset']['correction'] = {
      'eastM': 4000,
      'headingDeg': 45,
      'scale': 2,
    };
    doc['assets'][0]['tileset']['maximumScreenSpaceError'] = 32;
    final changed = SceneryManifest.fromJson(doc),
        roundtrip = SceneryManifest.fromJson(
          jsonDecode(jsonEncode(changed.toJson())),
        );
    expect(roundtrip.assets.single.tileset!['correction']['eastM'], 4000);
    expect(
      (roundtrip.toJson()['bounds']['east'] as num) -
          (roundtrip.toJson()['bounds']['west'] as num),
      greaterThan(
        (original.toJson()['bounds']['east'] as num) -
            (original.toJson()['bounds']['west'] as num),
      ),
    );
    expect(original.assets.single.tileset!['maximumScreenSpaceError'], 16);
  });
  test('remote definitions persist across database reopen without storing downloaded provider bytes', () async {
    final temp = await Directory.systemTemp.createTemp('fpv-tileset-db-');
    final file = File('${temp.path}/catalog.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    try {
      await SceneryRepository(db).create(sceneryTilesetFixture());
      await db.close();
      db = FpvDatabase(NativeDatabase(file));
      final restored = (await SceneryRepository(db).list()).single;
      expect(restored.toJson(), sceneryTilesetFixture().toJson());
      expect(
        restored.assets.single.tileset!['boundingSphere'],
        tilesetMetadata()['boundingSphere'],
      );
      expect(await temp.list().where((e) => e.path.endsWith('.glb')).length, 0);
    } finally {
      await db.close();
      await temp.delete(recursive: true);
    }
  });
}
