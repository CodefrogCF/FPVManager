import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_collision_import.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';
import 'package:fpvmanager/features/scenery/scenery_storage_native.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';

import '../../support/scenery_collision_fixture.dart';
import '../../support/scenery_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('prepared collision bytes and metadata cannot change during asynchronous validation', () async {
    final original = await collisionRoom().collider(),
        input = Uint8List.fromList(original.bytes);
    final pending = prepareSceneryCollision(input);
    input[0] = 0;
    final prepared = await pending;
    expect(prepared.bytes, original.bytes);
    expect(() => prepared.bytes[0] = 0, throwsUnsupportedError);
    expect(
      () => (prepared.metadata['localBounds'] as List)[0] = 999,
      throwsUnsupportedError,
    );
  });
  test('backup preserves collision references, transform and sidedness without model bytes', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    try {
      final mesh = await collisionRoom().collider(),
          scene = configureSceneryCollision(
            sceneryFixture(),
            [sceneryCollisionAsset(mesh)],
            enabled: true,
            sidedness: 'back',
          ),
          repo = SceneryRepository(db);
      await repo.create(scene);
      final backup = BackupRepository(db), bytes = await backup.create();
      await repo.update(scene.withEnabled(false));
      await backup.restore(await backup.preview(bytes));
      expect((await repo.list()).single.toJson(), scene.toJson());
    } finally {
      await db.close();
    }
  });
  test('room fixture preserves windows, doors, floors and structural objects without simplification', () async {
    final mesh = await collisionRoom().collider();
    expect(mesh.metadata['triangles'], 66);
    expect(mesh.key, endsWith('.fpc'));
    expect(mesh.metadata['localBounds'], [0.0, -15.0, 0.0, 20.0, 15.0, 6.0]);
    final fixture = File('test/fixtures/scenery/collision_room.fpc');
    if (autoUpdateGoldenFiles) await fixture.writeAsBytes(mesh.bytes);
    expect(mesh.bytes, await fixture.readAsBytes());
  });
  test('balanced triangle BVH is deterministic and matches the JS benchmark fixture', () async {
    final mesh = await collisionGrid().collider();
    expect(mesh.metadata['triangles'], 9800);
    final fixture = File('test/fixtures/scenery/collision_grid.fpc');
    if (autoUpdateGoldenFiles) await fixture.writeAsBytes(mesh.bytes);
    expect(mesh.bytes, await fixture.readAsBytes());
    expect((await prepareSceneryCollision(mesh.bytes)).metadata, mesh.metadata);
  });
  test('malformed indices, nonfinite geometry, incomplete trees and out-of-bounds leaves fail', () async {
    final mesh = await collisionRoom().collider();
    final original = ByteData.sublistView(mesh.bytes),
        v = original.getUint32(4, Endian.little),
        t = original.getUint32(8, Endian.little);
    for (final mutate in <void Function(ByteData)>[
      (b) => b.setUint32(0, 0, Endian.little),
      (b) => b.setFloat32(16, double.nan, Endian.little),
      (b) => b.setUint32(16 + v * 12, v, Endian.little),
      (b) => b.setFloat32(16 + v * 12 + t * 12, 9999, Endian.little),
    ]) {
      final bytes = Uint8List.fromList(mesh.bytes);
      mutate(ByteData.sublistView(bytes));
      await expectLater(prepareSceneryCollision(bytes), throwsFormatException);
    }
  });
  test('managed FPC policy and front/back settings compile without coupling to visual assets', () async {
    final mesh = await collisionRoom().collider(), base = sceneryFixture();
    final scene = configureSceneryCollision(
      base,
      [sceneryCollisionAsset(mesh)],
      enabled: true,
      sidedness: 'front',
    );
    final item =
        (SceneryAssetProviders().compile([scene])['sceneries'] as List).single
            as Map;
    expect(item['collisionIndependent'], true);
    expect(item['collisionSidedness'], 'front');
    expect(item['collisionResources'][0]['path'], 'managed/${mesh.key}');
    final disabled = configureSceneryCollision(
      scene,
      [sceneryCollisionAsset(mesh)],
      enabled: false,
      sidedness: 'back',
    );
    expect(
      (SceneryAssetProviders().compile([disabled])['sceneries'] as List)
          .single['physicalCollisionsEnabled'],
      false,
    );
    expect(scene.toJson()['source'], base.toJson()['source']);
  });
  test(
    'triangle strips/fans and mirrored nodes keep authored front-face winding',
    () async {
      for (final mode in [5, 6]) {
        final f = CollisionFixture();
        f.vertices.addAll(
          mode == 5
              ? [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0]
              : [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0],
        );
        final visual = await f.model(
          mode: mode,
          node: {
            'mesh': 0,
            'scale': [-1, 1, 1],
          },
        );
        final mesh = await generateSceneryCollision(visual.bytes),
            b = ByteData.sublistView(mesh.bytes),
            v = b.getUint32(4, Endian.little);
        expect(mesh.metadata['triangles'], 2);
        for (var t = 0; t < 2; t++) {
          final ids = [
            for (var j = 0; j < 3; j++)
              b.getUint32(16 + v * 12 + t * 12 + j * 4, Endian.little),
          ];
          final points = [
            for (final id in ids)
              [
                for (var j = 0; j < 3; j++)
                  b.getFloat32(16 + id * 12 + j * 4, Endian.little),
              ],
          ];
          final a = points[0], bb = points[1], c = points[2];
          expect(
            (bb[1] - a[1]) * (c[2] - a[2]) - (bb[2] - a[2]) * (c[1] - a[1]),
            greaterThan(0),
          );
        }
      }
    },
  );
  test(
    'collision files survive native storage restart and verify their checksum',
    () async {
      final temp = await Directory.systemTemp.createTemp('fpv-fpc-storage-');
      try {
        final mesh = await collisionRoom().collider(),
            store = NativeSceneryStorage(directory: () async => temp);
        expect(await store.put(mesh.key, mesh.bytes), true);
        expect(await store.put(mesh.key, mesh.bytes), false);
        final reopened = NativeSceneryStorage(directory: () async => temp);
        expect(await reopened.read(mesh.key), mesh.bytes);
        await File('${temp.path}/${mesh.key}').writeAsBytes([1, 2, 3]);
        await expectLater(reopened.read(mesh.key), throwsFormatException);
      } finally {
        expect(
          temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
          true,
        );
        await temp.delete(recursive: true);
      }
    },
  );
  test('file/definition commit is atomic and shared FPC survives removal until its last reference', () async {
    final temp = await Directory.systemTemp.createTemp('fpv-fpc-commit-'),
        db = FpvDatabase(NativeDatabase.memory());
    final repo = SceneryRepository(db),
        store = NativeSceneryStorage(directory: () async => temp);
    final c = SceneryCatalogController(
      repository: repo,
      storage: store,
      send: (_) async => {},
      loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
      canSend: () => true,
    );
    try {
      final mesh = await collisionRoom().collider(), base = sceneryFixture();
      await c.save(base, create: true);
      final next = configureSceneryCollision(
        base,
        [sceneryCollisionAsset(mesh)],
        enabled: true,
        sidedness: 'double',
      );
      await db.customStatement(
        "CREATE TRIGGER fail_mesh BEFORE UPDATE ON sceneries BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      await expectLater(c.saveCollision(base, next, [mesh]), throwsA(anything));
      expect(await File('${temp.path}/${mesh.key}').exists(), false);
      expect((await repo.list()).single.toJson(), base.toJson());
      await db.customStatement('DROP TRIGGER fail_mesh');
      await c.saveCollision(base, next, [mesh]);
      final other = SceneryManifest.fromJson(
        next.toJson()..['id'] = 'other-site',
      );
      await c.save(other, create: true);
      await c.remove(base.id);
      expect(await store.read(mesh.key), mesh.bytes);
      await c.remove(other.id);
      expect(await store.read(mesh.key), isNull);
    } finally {
      c.dispose();
      await c.settled;
      await db.close();
      expect(
        temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
        true,
      );
      await temp.delete(recursive: true);
    }
  });
}
