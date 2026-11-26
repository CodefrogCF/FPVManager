import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_storage_native.dart';
import 'package:fpvmanager/features/scenery/scenery_storage.dart';

import '../../support/scenery_model_fixture.dart';

void main() {
  late Directory temp;
  late NativeSceneryStorage store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fpv-scenery-import-');
    store = NativeSceneryStorage(directory: () async => temp);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'verified model survives storage reopen and deduplicates identical bytes',
    () async {
      final model = await prepareTriangle();
      expect(await store.put(model.key, model.bytes), isTrue);
      expect(await store.put(model.key, model.bytes), isFalse);
      final reopened = NativeSceneryStorage(directory: () async => temp);
      expect(await reopened.read(model.key), model.bytes);
      expect(await temp.list().length, 1);
      await reopened.remove(model.key);
      expect(await store.read(model.key), isNull);
    },
  );
  test('invalid keys, checksum mismatch and oversized files fail without a staging leak', () async {
    final model = await prepareTriangle();
    await expectLater(
      store.put('../outside.glb', model.bytes),
      throwsFormatException,
    );
    await expectLater(
      store.put('${'0' * 64}.glb', model.bytes),
      throwsFormatException,
    );
    await expectLater(store.read('../outside.glb'), throwsFormatException);
    expect(await temp.list().length, 0);
    final limited = NativeSceneryStorage(
      directory: () async => temp,
      fileBytes: 1024,
    );
    final oversized = await File('${temp.path}/${model.key}')
        .open(mode: FileMode.write);
    try {
      await oversized.truncate(1025);
    } finally {
      await oversized.close();
    }
    await expectLater(limited.read(model.key), throwsFormatException);
  });
  test(
    'corrupted content is reported and can be repaired by reimport',
    () async {
      final model = await prepareTriangle();
      await store.put(model.key, model.bytes);
      await File('${temp.path}/${model.key}').writeAsBytes([1, 2, 3]);
      await expectLater(store.read(model.key), throwsFormatException);
      expect(await store.put(model.key, model.bytes), isTrue);
      expect(await store.read(model.key), model.bytes);
    },
  );
  test('storage budget prevents uncontrolled allocation', () async {
    final model = await prepareTriangle();
    final reserved = await File('${temp.path}/${'0' * 64}.glb')
        .open(mode: FileMode.write);
    try {
      await reserved.truncate(4096);
    } finally {
      await reserved.close();
    }
    final limited = NativeSceneryStorage(
      directory: () async => temp,
      storageBytes: 4096,
    );
    await expectLater(
      limited.put(model.key, model.bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('storage limit'),
        ),
      ),
    );
    expect(await temp.list().length, 1);
  });
  test(
    'adjacent resources resolve relative to selected file, never traversal',
    () async {
      await File('${temp.path}/scene.gltf').writeAsString('{}');
      await Directory('${temp.path}/textures').create();
      await File('${temp.path}/textures/a.bin').writeAsBytes([1, 2, 3]);
      expect(
        await readAdjacentSceneryResource(
          '${temp.path}/scene.gltf',
          'textures/a.bin',
        ),
        [1, 2, 3],
      );
      expect(
        await readAdjacentSceneryResource(
          '${temp.path}/scene.gltf',
          'missing.bin',
        ),
        isNull,
      );
      await expectLater(
        readAdjacentSceneryResource(
          '${temp.path}/scene.gltf',
          '../outside.bin',
        ),
        throwsFormatException,
      );
    },
  );
  test('definition and bytes survive database reopen; last reference removal releases bytes', () async {
    final file = File('${temp.path}/catalog.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    var repo = SceneryRepository(db);
    SceneryCatalogController controller() => SceneryCatalogController(
      repository: repo,
      storage: store,
      loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
      canSend: () => true,
      send: (_) async => {},
    );
    final model = await prepareTriangle();
    var c = controller();
    await c.importModel(importedTriangle(model), model);
    await c.save(importedTriangle(model, id: 'second-instance'), create: true);
    c.dispose();
    await c.storageSettled;
    await db.close();
    db = FpvDatabase(NativeDatabase(file));
    repo = SceneryRepository(db);
    c = controller();
    try {
      expect((await c.definitions()).length, 2);
      expect(await c.readManagedModel(model.key), model.bytes);
      await c.remove('imported-triangle');
      expect(await c.readManagedModel(model.key), model.bytes);
      await c.remove('second-instance');
      expect(await store.read(model.key), isNull);
    } finally {
      c.dispose();
      await c.storageSettled;
      await db.close();
    }
  });
  test('failed database create rolls back newly staged bytes but retains shared bytes', () async {
    final db = FpvDatabase(NativeDatabase.memory()),
        model = await prepareTriangle();
    final repo = SceneryRepository(db), manifest = importedTriangle(model);
    final c = SceneryCatalogController(
      repository: repo,
      storage: store,
      loadBundled: () async => ' {"schemaVersion":1,"sceneries":[]}',
      canSend: () => true,
      send: (_) async => {},
    );
    try {
      await c.importModel(manifest, model);
      await expectLater(c.importModel(manifest, model), throwsStateError);
      expect(await store.read(model.key), model.bytes);
      await store.remove(model.key);
      // Existing definitions must keep repaired bytes even when duplicate creation fails.
      await expectLater(c.importModel(manifest, model), throwsStateError);
      expect(await store.read(model.key), model.bytes);
    } finally {
      c.dispose();
      await c.storageSettled;
      await db.close();
    }
  });
  test(
    'bridge failure after commit retains offline model and restart metadata',
    () async {
      final db = FpvDatabase(NativeDatabase.memory()),
          model = await prepareTriangle();
      final repo = SceneryRepository(db);
      final c = SceneryCatalogController(
        repository: repo,
        storage: store,
        loadBundled: () async => ' {"schemaVersion":1,"sceneries":[]}',
        canSend: () => false,
        send: (_) async => {},
      );
      try {
        await expectLater(
          c.importModel(importedTriangle(model), model),
          throwsStateError,
        );
        expect((await repo.list()).single.assets.single.uri, model.key);
        expect(await store.read(model.key), model.bytes);
        expect(await c.readManagedModel('${'0' * 64}.glb'), isNull);
      } finally {
        c.dispose();
        await c.storageSettled;
        await db.close();
      }
    },
  );
  test('shutdown waits for an owned write and rolls back before the database closes', () async {
    final db = FpvDatabase(NativeDatabase.memory()),
        model = await prepareTriangle();
    final delayed = _DelayedStore(), repo = SceneryRepository(db);
    final c = SceneryCatalogController(
      repository: repo,
      storage: delayed,
      loadBundled: () async => ' {"schemaVersion":1,"sceneries":[]}',
      canSend: () => true,
      send: (_) async => {},
    );
    final work = c.importModel(importedTriangle(model), model);
    final rejected = expectLater(work, throwsStateError);
    await delayed.started.future;
    c.dispose();
    final settled = c.storageSettled;
    delayed.proceed.complete();
    await settled;
    await rejected;
    expect(delayed.bytes, isNull);
    expect(await repo.list(), isEmpty);
    await db.close();
  });
}

class _DelayedStore implements SceneryStorage {
  final started = Completer<void>(), proceed = Completer<void>();
  Uint8List? bytes;
  @override
  Map<String, String> get rendererOptions => const {'backend': 'server'};
  @override
  Future<bool> put(String key, Uint8List value) async {
    started.complete();
    await proceed.future;
    bytes = value;
    return true;
  }

  @override
  Future<Uint8List?> read(String key) async => bytes;
  @override
  Future<void> remove(String key) async {
    bytes = null;
  }
}
