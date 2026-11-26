import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_alignment_edit.dart';
import 'package:fpvmanager/features/scenery/scenery_alignment_session.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

import '../../support/scenery_fixture.dart';
import '../../support/scenery_tileset_fixture.dart';

Map<String, dynamic> edit({bool changed = true}) => {
  'transformChanged': changed,
  'alignment': <String, dynamic>{
    'longitude': 13.81,
    'latitude': 52.41,
    'ellipsoidHeightM': 120.0,
    'rotationDeg': 35.0,
    'pitchDeg': 8.0,
    'rollDeg': -4.0,
    'scale': 1.5,
    'opacity': .5,
  },
  'reference': 'WGS84_ELLIPSOID',
  'heightM': 120.0,
  'remoteCorrections': <dynamic>[],
};
void main() {
  test('placement preserves assets, source and collision definitions while sharing one transform', () {
    final base = sceneryFixture(),
        next = applySceneryAlignment(base, edit()),
        doc = next.toJson();
    expect(doc['assets'], base.toJson()['assets']);
    expect(doc['source'], base.toJson()['source']);
    expect(doc['collision'], base.toJson()['collision']);
    final item =
        (SceneryAssetProviders().compile([next])['sceneries'] as List).single
            as Map;
    expect(item['alignment']['pitchDeg'], 8);
    expect(item['alignment']['scale'], 1.5);
    expect(item['alignment']['opacity'], .5);
    expect(item['collisionAssets'], ['synthetic.fpc']);
    expect(item['heightAlignmentMode'], 'fixed');
  });
  test(
    'absolute and relative heights are persisted with explicit references',
    () {
      final value = edit()
        ..['reference'] = 'TERRAIN_RELATIVE'
        ..['heightM'] = 3;
      final next = applySceneryAlignment(sceneryFixture(), value),
          item =
              (SceneryAssetProviders().compile([next])['sceneries'] as List)
                      .single
                  as Map;
      expect(next.toJson()['anchor']['heightM'], 3);
      expect(item['heightOffsetM'], 3);
      expect(item['heightAlignmentMode'], 'terrain');
      expect(item['requireGroundCalibration'], true);
    },
  );
  test('opacity-only editing retains source calibration and placement', () {
    final base = sceneryFixture().toJson();
    base['extensions'] = {
      'cesium': {
        'heightAlignmentMode': 'terrain',
        'heightCalibration': {'method': 'example'},
      },
    };
    final manifest = applySceneryAlignment(
      SceneryManifest.fromJson(base),
      edit(changed: false),
    );
    expect(manifest.toJson()['anchor'], base['anchor']);
    expect(manifest.toJson()['rotation'], base['rotation']);
    expect(
      manifest.toJson()['extensions']['cesium']['heightCalibration'],
      base['extensions']['cesium']['heightCalibration'],
    );
  });
  test('invalid and nonfinite placement values are rejected', () {
    for (final entry in {
      'longitude': 181,
      'latitude': double.nan,
      'scale': 0,
      'opacity': 2,
      'pitchDeg': 91,
    }.entries) {
      final value = edit();
      (value['alignment'] as Map)[entry.key] = entry.value;
      expect(
        () => applySceneryAlignment(sceneryFixture(), value),
        throwsFormatException,
      );
    }
    expect(
      () => applySceneryAlignment(
        sceneryFixture(),
        edit()..['heightM'] = double.infinity,
      ),
      throwsFormatException,
    );
  });
  test('remote correction keeps the original anchor and endpoint', () {
    final base = sceneryTilesetFixture(), value = edit();
    value['remoteCorrections'] = [
      {
        'id': base.assets.first.id,
        'correction': {
          'eastM': 12,
          'northM': 4,
          'upM': 3,
          'headingDeg': 20,
          'scale': 1.2,
        },
      },
    ];
    final next = applySceneryAlignment(base, value);
    expect(next.toJson()['anchor'], base.toJson()['anchor']);
    expect(next.assets.first.uri, base.assets.first.uri);
    expect(next.assets.first.tileset!['correction']['eastM'], 12);
    expect(() => applySceneryAlignment(base, edit()), throwsFormatException);
  });
  test('confirmed placement and opacity survive a database restart', () async {
    final temp = await Directory.systemTemp.createTemp('fpv-alignment-db-');
    final file = File('${temp.path}/scenery.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    final confirmed = applySceneryAlignment(sceneryFixture(), edit());
    try {
      await SceneryRepository(db).create(confirmed);
      await db.close();
      db = FpvDatabase(NativeDatabase(file));
      expect(
        (await SceneryRepository(db).list()).single.toJson(),
        confirmed.toJson(),
      );
    } finally {
      await db.close();
      expect(
        temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
        true,
      );
      await temp.delete(recursive: true);
    }
  });
  group('editor sessions', () {
    late FpvDatabase db;
    late SceneryRepository repo;
    late SceneryCatalogController catalog;
    late SceneryAlignmentSession session;
    late List<Map<String, dynamic>> commands;
    setUp(() async {
      db = FpvDatabase(NativeDatabase.memory());
      repo = SceneryRepository(db);
      commands = [];
      Future<Map<String, dynamic>> send(Map<String, dynamic> c) async {
        commands.add(c);
        return {};
      }

      catalog = SceneryCatalogController(
        repository: repo,
        send: send,
        loadBundled: () async => ' {"schemaVersion":1,"sceneries":[]}',
        canSend: () => true,
      );
      await catalog.save(sceneryFixture(), create: true);
      session = SceneryAlignmentSession(
        catalog: catalog,
        send: send,
        canSend: () => true,
      );
    });
    tearDown(() async {
      session.invalidate();
      catalog.dispose();
      await catalog.settled;
      await db.close();
    });
    test('cancel and obsolete submissions never change persistence', () async {
      await session.begin(id: 'synthetic-site', german: false);
      final token = commands.last['token'];
      await session.event({'type': 'scenery-alignment-cancel', 'token': token});
      await session.event({
        'type': 'scenery-alignment-submit',
        'token': token,
        'id': 'synthetic-site',
        'placement': edit(),
      });
      expect((await repo.list()).single.toJson()['anchor']['heightM'], 100);
      expect(session.active, false);
    });
    test(
      'confirmation persists and replay uses the confirmed transform',
      () async {
        await session.begin(id: 'synthetic-site', german: true);
        final token = commands.last['token'];
        await session.event({
          'type': 'scenery-alignment-submit',
          'token': token,
          'id': 'synthetic-site',
          'placement': edit(),
        });
        expect((await repo.list()).single.toJson()['anchor']['heightM'], 120);
        expect(session.active, false);
        await catalog.synchronize();
        final item =
            (commands.last['catalog']['sceneries'] as List).single as Map;
        expect(item['alignment']['rotationDeg'], 35);
      },
    );
    test(
      'concurrent persisted edits cannot be overwritten by an old preview',
      () async {
        await session.begin(id: 'synthetic-site', german: false);
        final token = commands.last['token'];
        await catalog.save(
          SceneryManifest.fromJson(
            sceneryFixture().toJson()..['name'] = 'Changed elsewhere',
          ),
          create: false,
        );
        await session.event({
          'type': 'scenery-alignment-submit',
          'token': token,
          'id': 'synthetic-site',
          'placement': edit(),
        });
        expect((await repo.list()).single.name, 'Changed elsewhere');
        expect(commands.last['error'], contains('changed during editing'));
      },
    );
    test('reconnect invalidation rejects late confirmation events', () async {
      await session.begin(id: 'synthetic-site', german: false);
      final token = commands.last['token'];
      session.invalidate();
      await session.event({
        'type': 'scenery-alignment-submit',
        'token': token,
        'id': 'synthetic-site',
        'placement': edit(),
      });
      expect(
        jsonEncode((await repo.list()).single.toJson()),
        jsonEncode(sceneryFixture().toJson()),
      );
    });
  });
}
