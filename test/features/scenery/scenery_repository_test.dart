import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';

import '../../support/scenery_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FpvDatabase db;
  late SceneryRepository repo;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repo = SceneryRepository(db);
  });
  tearDown(() => db.close());
  test('create update remove independently enabled scenes without overwriting peers', () async {
    await repo.initializeBundled([]);
    await repo.create(sceneryFixture());
    await repo.create(sceneryFixture(id: 'other', enabled: false));
    await repo.update(sceneryFixture().withEnabled(false));
    expect((await repo.list()).map((m) => m.enabled), [false, false]);
    await expectLater(repo.create(sceneryFixture()), throwsStateError);
    await repo.remove('synthetic-site');
    expect((await repo.list()).single.id, 'other');
    await expectLater(repo.update(sceneryFixture()), throwsStateError);
    await expectLater(repo.remove('missing'), throwsStateError);
  });
  test(
    'legacy activation and alignment migrate once, deletion survives reseeding',
    () async {
      final legacy = DriftUserPreferencesRepository(db);
      await legacy.saveSceneryPreference('synthetic-site', false);
      final edit = {
        'alignment': {
          'schemaVersion': 1,
          'longitude': 13.9,
          'latitude': 52.5,
          'ellipsoidHeightM': 123.0,
          'rotationDeg': 31.0,
          'scale': 2.0,
          'opacity': 1.0,
        },
        'bkgHeightOffsetM': -16.9,
      };
      await legacy.saveSceneryEdit('synthetic-site', edit);
      await repo.initializeBundled([sceneryFixture()]);
      final m = (await repo.list()).single;
      expect(m.enabled, false);
      expect((m.toJson()['anchor'] as Map)['heightM'], 123);
      expect(
        ((m.toJson()['extensions'] as Map)['cesium']
            as Map)['bkgHeightOffsetM'],
        -16.9,
      );
      await repo.remove(m.id);
      await repo.initializeBundled([sceneryFixture()]);
      expect(await repo.list(), isEmpty);
    },
  );
  test(
    'malformed legacy settings roll back seeding and remain recoverable',
    () async {
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'map.scenery.enabled.v1',
              value: '{"bad": 2}',
            ),
          );
      await expectLater(
        repo.initializeBundled([sceneryFixture()]),
        throwsFormatException,
      );
      expect(await repo.list(), isEmpty);
      expect(
        await (db.select(
          db.appSettings,
        )..where((t) => t.key.equals(SceneryRepository.initializedKey))).get(),
        isEmpty,
      );
      await (db.delete(
        db.appSettings,
      )..where((t) => t.key.equals('map.scenery.enabled.v1'))).go();
      await repo.initializeBundled([sceneryFixture()]);
      expect((await repo.list()).length, 1);
    },
  );
  test('backup roundtrip preserves definitions and does not resurrect removed bundled scenes', () async {
    await repo.initializeBundled([sceneryFixture()]);
    await repo.remove('synthetic-site');
    await repo.create(sceneryFixture(id: 'custom', enabled: false));
    final backup = BackupRepository(db), bytes = await backup.create();
    await repo.update(sceneryFixture(id: 'custom'));
    await backup.restore(await backup.preview(bytes));
    final reopened = SceneryRepository(db);
    await reopened.initializeBundled([sceneryFixture()]);
    final restored = (await reopened.list()).single;
    expect(restored.id, 'custom');
    expect(restored.enabled, false);
  });
  test('backup rejects mismatched or malformed scenery before replacing personal data', () async {
    await repo.initializeBundled([sceneryFixture()]);
    final backup = BackupRepository(db),
        document = await backup.preview(await backup.create());
    final tables = document['tables'] as Map;
    final row = (tables['sceneries'] as List).single as Map;
    row['id'] = 'mismatch';
    await expectLater(backup.restore(document), throwsFormatException);
    expect((await repo.list()).single.id, 'synthetic-site');
    row['id'] = 'synthetic-site';
    row['manifest_json'] = jsonEncode({'schemaVersion': 99});
    await expectLater(backup.restore(document), throwsFormatException);
  });
  test('unrecognized future scene provider persists without format-specific DB fields', () async {
    await repo.initializeBundled([]);
    final doc = sceneryFixture().toJson();
    ((doc['assets'] as List).first as Map).addAll(<String, dynamic>{
      'provider': 'remote',
      'format': '3d-tiles',
      'uri': 'https://example.invalid/site/tileset.json',
    });
    await repo.create(SceneryManifest.fromJson(doc));
    expect((await repo.list()).single.toJson(), doc);
  });
  test('failed update preserves previous manifest atomically', () async {
    await repo.initializeBundled([sceneryFixture()]);
    final before = (await repo.list()).single.toJson();
    await expectLater(
      db.transaction(() async {
        await repo.update(sceneryFixture().withEnabled(false));
        throw StateError('Interrupted');
      }),
      throwsStateError,
    );
    expect((await repo.list()).single.toJson(), before);
  });
}
