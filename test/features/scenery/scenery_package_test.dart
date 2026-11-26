import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_collision_import.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_package.dart';
import 'package:fpvmanager/features/scenery/scenery_package_files.dart';
import 'package:fpvmanager/features/scenery/scenery_package_zip.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_storage.dart';

import '../../support/scenery_model_fixture.dart';

class MemoryStore implements SceneryStorage {
  final files = <String, Uint8List>{};
  @override
  Map<String, String> get rendererOptions => {'backend': 'server'};
  @override
  Future<Uint8List?> read(String key) async => files[key];
  @override
  Future<bool> put(String key, Uint8List bytes) async {
    await verifyManagedScenery(key, bytes);
    if (files.containsKey(key)) return false;
    files[key] = bytes;
    return true;
  }

  @override
  Future<void> remove(String key) async {
    files.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'STORE ZIP roundtrip, rejects corrupted CRC, path and compressed entry',
    () {
      final zip = writeSceneryZip({
        'manifest.json': Uint8List.fromList([123, 125]),
      });
      expect(readSceneryZip(zip)['manifest.json'], [123, 125]);
      final corrupt = Uint8List.fromList(zip)..[43] = 0;
      expect(() => readSceneryZip(corrupt), throwsFormatException);
      final compressed = Uint8List.fromList(zip)..[8] = 8;
      expect(() => readSceneryZip(compressed), throwsFormatException);
      final path = Uint8List.fromList(zip)..[30] = 46;
      expect(() => readSceneryZip(path), throwsFormatException);
      expect(
        () => writeSceneryZip({'../manifest.json': Uint8List(1)}),
        throwsFormatException,
      );
      expect(() => readSceneryZip(Uint8List(22)), throwsFormatException);
      final bomb = Uint8List.fromList(zip);
      final d = ByteData.sublistView(bomb);
      final central = d.getUint32(bomb.length - 6, Endian.little);
      d.setUint32(central + 24, 0xffffffff, Endian.little);
      expect(() => readSceneryZip(bomb), throwsFormatException);
    },
  );
  test(
    'complete package roundtrip preserves anchor, collision and managed LODs',
    () async {
      final model = await prepareTriangle(),
          mesh = await generateSceneryCollision(model.bytes);
      final base = importedTriangle(model);
      final doc = configureSceneryCollision(
        base,
        [
          {
            ...sceneryCollisionAsset(mesh),
            'rf': {'material': 'reinforcedConcrete', 'thicknessM': .3},
          },
        ],
        enabled: true,
        sidedness: 'front',
      ).toJson();
      final alt = triangleGltf();
      alt['asset']['generator'] = 'LOD fixture';
      final lod = await prepareTriangle(doc: alt);
      expect(lod.key, isNot(model.key));
      (doc['assets'] as List).add({
        'id': 'low',
        'role': 'visual',
        'format': 'glb',
        'provider': 'managed',
        'uri': lod.key,
        'model': lod.metadata,
      });
      doc['extensions'] = {
        'lods': {
          'visual': {'low': 'low'},
        },
      };
      final m = SceneryManifest.fromJson(doc),
          files = {
            model.key: model.bytes,
            mesh.key: mesh.bytes,
            lod.key: lod.bytes,
          };
      final encoded = await encodeSceneryPackage(
        m,
        read: (key) async => files[key],
        metadataOnly: false,
        redistributionAllowed: true,
        revision: 2,
      );
      final imported = await decodeSceneryPackage(encoded);
      expect(imported.revision, 2);
      expect(imported.manifest.enabled, false);
      expect(imported.manifest.toJson()['anchor'], m.toJson()['anchor']);
      expect(imported.manifest.toJson()['collision'], m.toJson()['collision']);
      expect(imported.manifest.toJson()['source'], m.toJson()['source']);
      expect(imported.files.keys.toSet(), files.keys.toSet());
      final compiled = SceneryAssetProviders().compile([imported.manifest]);
      final item = (compiled['sceneries'] as List).single as Map;
      expect((item['assets'] as List).length, 1);
      expect(item['rfMaterials']['managed/${mesh.key}'], {
        'material': 'reinforcedConcrete',
        'thicknessM': .3,
      });
      expect(
        () => validateSceneryRf({'material': 'invalid'}),
        throwsFormatException,
      );
      expect(
        () => validateSceneryRf({'material': 'metal', 'thicknessM': -1}),
        throwsFormatException,
      );
      expect(
        item['visualLods']['managed/${model.key}']['low']['path'],
        'managed/${lod.key}',
      );
      // Recompute ZIP CRC but leave the manifest SHA-256 unchanged.
      final entries = readSceneryZip(encoded);
      final key = 'assets/${model.key}';
      entries[key] = Uint8List.fromList(entries[key]!)..[0] = 0;
      await expectLater(
        decodeSceneryPackage(writeSceneryZip(entries)),
        throwsFormatException,
      );
    },
  );
  test(
    'metadata only never reads or resolves assets; permission is explicit',
    () async {
      final model = await prepareTriangle(), m = importedTriangle(model);
      Future<Uint8List?> forbidden(String _) async =>
          throw StateError('must not read');
      await expectLater(
        encodeSceneryPackage(
          m,
          read: forbidden,
          metadataOnly: false,
          redistributionAllowed: false,
          revision: 1,
        ),
        throwsFormatException,
      );
      final bytes = await encodeSceneryPackage(
        m,
        read: forbidden,
        metadataOnly: true,
        redistributionAllowed: false,
        revision: 1,
      );
      final p = await decodeSceneryPackage(bytes);
      expect(p.files, isEmpty);
      expect(p.metadataOnly, true);
      expect(
        SceneryAssetProviders().compile([p.manifest])['sceneries'],
        isEmpty,
      );
      await expectLater(
        encodeSceneryPackage(
          p.manifest,
          read: forbidden,
          metadataOnly: false,
          redistributionAllowed: true,
          revision: 2,
        ),
        throwsFormatException,
      );
      final entries = readSceneryZip(bytes);
      final raw = jsonDecode(utf8.decode(entries['manifest.json']!)) as Map;
      raw['version'] = 2;
      entries['manifest.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(raw)),
      );
      await expectLater(
        decodeSceneryPackage(writeSceneryZip(entries)),
        throwsFormatException,
      );
    },
  );
  test('catalog import, duplicate rejection, backup references, repair and removal', () async {
    final model = await prepareTriangle(), m = importedTriangle(model);
    final bytes = await encodeSceneryPackage(
      m,
      read: (_) async => model.bytes,
      metadataOnly: false,
      redistributionAllowed: true,
      revision: 1,
    );
    final p = await decodeSceneryPackage(bytes);
    final db = FpvDatabase(NativeDatabase.memory()), store = MemoryStore();
    final c = SceneryCatalogController(
      repository: SceneryRepository(db),
      storage: store,
      loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
      canSend: () => true,
      send: (_) async => {},
    );
    try {
      await c.importPackage(p, replace: false);
      expect(await store.read(model.key), model.bytes);
      await expectLater(c.importPackage(p, replace: false), throwsStateError);
      final backup = BackupRepository(db), data = await backup.create();
      await c.remove(m.id);
      expect(store.files, isEmpty);
      await backup.restore(await backup.preview(data));
      expect(packageInfo((await c.definitions()).single)?['revision'], 1);
      await c.importPackage(p, replace: true);
      expect(await store.read(model.key), model.bytes);
      await c.remove(m.id);
      expect(store.files, isEmpty);
    } finally {
      c.dispose();
      await c.storageSettled;
      await db.close();
    }
  });
  test(
    'repair an original managed definition restored without package metadata',
    () async {
      final model = await prepareTriangle(), m = importedTriangle(model);
      final bytes = await encodeSceneryPackage(
        m,
        read: (_) async => model.bytes,
        metadataOnly: false,
        redistributionAllowed: true,
        revision: 1,
      );
      final p = await decodeSceneryPackage(bytes);
      final db = FpvDatabase(NativeDatabase.memory()),
          store = MemoryStore(),
          repo = SceneryRepository(db);
      final c = SceneryCatalogController(
        repository: repo,
        storage: store,
        loadBundled: () async => '{"schemaVersion":1,"sceneries":[]}',
        canSend: () => true,
        send: (_) async => {},
      );
      try {
        await c.definitions();
        final original = m.toJson();
        (original['anchor'] as Map)['heightM'] = 145;
        await repo.create(SceneryManifest.fromJson(original));
        await c.importPackage(p, replace: true);
        final restored = (await c.definitions()).single;
        expect(restored.toJson()['anchor']['heightM'], 145);
        expect(restored.enabled, false);
        expect(await store.read(model.key), model.bytes);
        expect(packageInfo(restored)?['revision'], 1);
      } finally {
        c.dispose();
        await c.storageSettled;
        await db.close();
      }
    },
  );
  test('remote import accepts only HTTPS without credentials or fragment', () {
    expect(
      SceneryPackageFiles.validateRemoteUrl(
        'https://example.invalid/scene.fpvscenery',
      ).scheme,
      'https',
    );
    for (final bad in [
      'http://example.invalid/x',
      'file:///tmp/x',
      'https://user:secret@example.invalid/x',
      'https://example.invalid/x#anchor',
    ]) {
      expect(
        () => SceneryPackageFiles.validateRemoteUrl(bad),
        throwsFormatException,
      );
    }
  });
}
