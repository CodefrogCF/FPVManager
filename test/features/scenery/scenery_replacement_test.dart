import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_alignment_edit.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_replacement.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';

import '../../support/scenery_fixture.dart';

Map<String, dynamic> config() => {
  'schemaVersion': 1,
  'buildings': {
    'enabled': true,
    'regions': [
      [
        [13.7999, 52.3999],
        [13.8001, 52.3999],
        [13.8001, 52.4001],
        [13.7999, 52.4001],
      ],
    ],
    'features': [
      {'provider': 'swisstopo', 'property': 'uuid', 'id': 'one'},
    ],
  },
  'terrain': {
    'enabled': true,
    'regions': [
      {
        'polygon': [
          [13.7999, 52.3999],
          [13.8001, 52.3999],
          [13.8001, 52.4001],
          [13.7999, 52.4001],
        ],
        'minimumUpM': -1,
        'maximumUpM': 1,
        'seamToleranceM': .5,
      },
    ],
  },
};

void main() {
  test('version-one optional replacement roundtrips and compiles without changing old definitions', () {
    final base = sceneryFixture(),
        next = configureSceneryReplacement(base, config());
    expect(base.toJson().containsKey('replacement'), false);
    expect(next.toJson()['replacement'], config());
    expect(
      SceneryManifest.fromJson(jsonDecode(jsonEncode(next.toJson()))).toJson(),
      next.toJson(),
    );
    final compiled = SceneryAssetProviders().compile([next]);
    expect((compiled['sceneries'] as List).single['replacement'], config());
    expect(next.toJson()['source'], base.toJson()['source']);
    expect(next.toJson()['assets'], base.toJson()['assets']);
  });
  test('invalid or unbounded polygons, IDs and terrain bands are rejected', () {
    for (final mutate in <void Function(Map)>[
      (c) => c['buildings']['regions'][0].add([13.7999, 52.3999]),
      (c) => c['buildings']['regions'][0][1] = [14, 52.4],
      (c) => c['buildings']['regions'][0] = [
        [13.7999, 52.3999],
        [13.8001, 52.4001],
        [13.8001, 52.3999],
        [13.7999, 52.4001],
      ],
      (c) => c['buildings']['features'].add({
        'provider': 'swisstopo',
        'property': 'uuid',
        'id': 'one',
      }),
      (c) => c['buildings']['features'][0]['provider'] = 'other',
      (c) => c['terrain']['regions'][0]['maximumUpM'] = -2,
      (c) => c['terrain']['regions'][0]['seamToleranceM'] = double.nan,
      (c) => c['terrain']['regions'][0]['seamToleranceM'] = 1,
      (c) => c['terrain']['regions'] = [],
    ]) {
      final c = jsonDecode(jsonEncode(config())) as Map<String, dynamic>;
      mutate(c);
      expect(
        () => configureSceneryReplacement(sceneryFixture(), c),
        throwsFormatException,
      );
    }
  });
  test(
    'clockwise winding normalizes and antimeridian regions remain local',
    () {
      final c = config();
      (c['buildings']['regions'] as List)[0] =
          (c['buildings']['regions'][0] as List).reversed.toList();
      expect(
        configureSceneryReplacement(
          sceneryFixture(),
          c,
        ).toJson()['replacement']['buildings']['regions'],
        config()['buildings']['regions'],
      );
      final region = [
        [179.9999, 52.3999],
        [-179.9999, 52.3999],
        [-179.9999, 52.4001],
        [179.9999, 52.4001],
      ];
      final d = emptySceneryReplacement();
      d['buildings'] = {
        'enabled': true,
        'regions': [region],
        'features': [],
      };
      expect(
        validateSceneryReplacement(d, {
          'longitude': 180.0,
          'latitude': 52.4,
        })['buildings']['regions'],
        [region],
      );
    },
  );
  test('placement changes revoke replacement while opacity-only changes retain configuration', () {
    final base = configureSceneryReplacement(sceneryFixture(), config());
    Map<String, dynamic> edit(bool moved) => {
      'alignment': {
        'longitude': 13.8002,
        'latitude': 52.4,
        'ellipsoidHeightM': 100,
        'rotationDeg': 20,
        'pitchDeg': 0,
        'rollDeg': 0,
        'scale': 1,
        'opacity': .7,
      },
      'reference': 'WGS84_ELLIPSOID',
      'heightM': 100,
      'transformChanged': moved,
    };
    final unchanged = applySceneryAlignment(base, edit(false));
    expect(unchanged.toJson()['replacement'], base.toJson()['replacement']);
    final moved = applySceneryAlignment(
      base,
      edit(true),
    ).toJson()['replacement'];
    expect(moved['buildings']['enabled'], false);
    expect(moved['terrain']['enabled'], false);
    expect(moved['buildings']['regions'], config()['buildings']['regions']);
  });
  test('serial replacement saves persist after database reopen and preserve asset/source fields', () async {
    final temp = await Directory.systemTemp.createTemp('fpv-replacement-');
    final file = File('${temp.path}/test.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    try {
      final repository = SceneryRepository(db), base = sceneryFixture();
      await repository.create(base);
      final controller = SceneryCatalogController(
        repository: repository,
        loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
        canSend: () => true,
        send: (command) async => {'sceneries': command['catalog']},
      );
      await controller.saveReplacement(base, config());
      controller.dispose();
      await controller.storageSettled;
      await db.close();
      db = FpvDatabase(NativeDatabase(file));
      final saved = (await SceneryRepository(db).list()).single;
      expect(saved.toJson()['replacement'], config());
      expect(saved.toJson()['assets'], base.toJson()['assets']);
    } finally {
      await db.close();
      await temp.delete(recursive: true);
    }
  });
  test(
    'conflicts and navigation changes cannot overwrite existing replacement',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      try {
        final repository = SceneryRepository(db), base = sceneryFixture();
        await repository.create(base);
        var canSend = true;
        final controller = SceneryCatalogController(
          repository: repository,
          loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
          canSend: () => canSend,
          send: (_) async => {},
        );
        await repository.update(base.withEnabled(false));
        await expectLater(
          controller.saveReplacement(base, config()),
          throwsStateError,
        );
        canSend = false;
        await expectLater(
          controller.saveReplacement(base.withEnabled(false), config()),
          throwsStateError,
        );
        expect(
          (await repository.list()).single.toJson().containsKey('replacement'),
          false,
        );
        controller.dispose();
        await controller.storageSettled;
      } finally {
        await db.close();
      }
    },
  );
}
