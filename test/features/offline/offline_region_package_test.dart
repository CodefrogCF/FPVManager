import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/offline/offline_region_package.dart';
import 'package:fpvmanager/features/offline/offline_map_store_native.dart';
import 'package:fpvmanager/features/offline/offline_package_files.dart';
import 'package:fpvmanager/features/offline/offline_regions_section.dart';
import 'package:fpvmanager/features/offline/swiss_offline_sources.dart';

Uint8List fixture() =>
    File('test/fixtures/offline/prepared.fpvregion').readAsBytesSync();
Uint8List repack(
  void Function(Map<String, Uint8List>, Map<String, dynamic>) change, {
  bool compressed = false,
}) {
  final zip = ZipDecoder().decodeBytes(fixture());
  final files = {
    for (final f in zip.files) f.name: Uint8List.fromList(f.readBytes()!),
  };
  final manifest =
      jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, dynamic>;
  change(files, manifest);
  files['manifest.json'] = Uint8List.fromList(
    utf8.encode(jsonEncode(manifest)),
  );
  final archive = Archive();
  for (final e in files.entries) {
    archive.add(
      ArchiveFile.bytes(e.key, e.value)
        ..compression = compressed
            ? CompressionType.deflate
            : CompressionType.none,
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

class FixturePackageFiles extends OfflinePackageFiles {
  const FixturePackageFiles();
  @override
  Future<Uint8List?> pick() async => fixture();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android preparation plans use the document picker and exclude previous package internals', () async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.codefrog.fpvmanager/route_files');
    addTearDown(() {
      debugDefaultTargetPlatformOverride = previous;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (value) async {
          call = value;
          return true;
        });
    final plan = SwissOfflineSourcePlan(
      region: decodeRegionPackage(fixture()).region,
      retrievedAt: DateTime.utc(2026, 10, 29),
      assets: [],
      notices: [],
    );
    expect(await const OfflinePackageFiles().savePlan(plan), true);
    expect(call!.method, 'saveOfflinePlan');
    expect(call!.arguments['name'], 'offline-region.fpvofflineplan');
    final decoded = jsonDecode(
      utf8.decode(call!.arguments['bytes'] as Uint8List),
    );
    expect(decoded['region']['id'], 'synthetic-prepared');
    expect(decoded['region'].containsKey('packageId'), false);
    expect(decoded['region'].containsKey('provenance'), false);
  });
  test('prepared package retains complete pyramids, provenance and source height conversion', () {
    final p = decodeRegionPackage(fixture());
    expect(p.region.packageActive, true);
    expect(p.files.length, p.region.packageTiles);
    expect(p.manifest['sourceHeightReference'], 'LN02');
    expect(p.region.packageId, hasLength(64));
    final header = ByteData.sublistView(p.files['terrain/0/1/0.terrain']!);
    expect(header.getFloat32(24, Endian.little), greaterThan(1040));
    for (final key in p.files.keys) {
      expect(p.region.includesKey('prepared/${p.region.packageId}/$key'), true);
    }
    expect(p.region.includesKey('terrain/layer.json'), false);
    expect(
      p.region.includesKey('prepared/${'f' * 64}/terrain/layer.json'),
      false,
    );
  });
  test('missing, altered, compressed, foreign-path and unsupported-version packages are rejected', () {
    for (final mutation
        in <void Function(Map<String, Uint8List>, Map<String, dynamic>)>[
          (f, m) => f.remove('terrain/0/1/0.terrain'),
          (f, m) => f['terrain/0/1/0.terrain']![100] ^= 1,
          (f, m) => f['../escape'] = Uint8List.fromList([1]),
          (f, m) => m['version'] = 99,
          (f, m) => m['heightReference'] = 'LN02',
          (f, m) => m['sources'][0]['url'] = 'https://example.com/fake.tif',
        ]) {
      expect(
        () => decodeRegionPackage(repack(mutation)),
        throwsFormatException,
      );
    }
    expect(
      () => decodeRegionPackage(repack((_, _) {}, compressed: true)),
      throwsFormatException,
    );
    final broken = fixture();
    broken[8] = 8; // central STORE, local DEFLATE
    expect(() => decodeRegionPackage(broken), throwsFormatException);
  });
  test('prepared meshes reject truncated arrays and unsafe triangles', () {
    final mesh = decodeRegionPackage(fixture()).files['terrain/0/1/0.terrain']!;
    expect(
      () => validatePreparedMesh(Uint8List.sublistView(mesh, 0, 100)),
      throwsFormatException,
    );
    final invalid = Uint8List.fromList(mesh);
    ByteData.sublistView(invalid)
        .setUint16(92 + 65 * 65 * 6 + 4, 65535, Endian.little);
    expect(() => validatePreparedMesh(invalid), throwsFormatException);
  });
  test('native publication is atomic, restart reopens locally, and missing prepared files never use the network', () async {
    final database = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var requests = 0;
    NativeOfflineMapStore create() => NativeOfflineMapStore(
      database: database,
      client: MockClient((_) async {
        requests++;
        throw StateError('No network expected');
      }),
    );
    var store = create();
    final first = decodeRegionPackage(fixture());
    await store.importPackage(first);
    expect((await store.tiles()).length, first.files.length);
    await store.importPackage(first);
    expect((await store.tiles()).length, first.files.length);
    final second = decodeRegionPackage(
      repack((f, m) => m['region']['name'] = 'Updated fixture'),
    );
    await database.customStatement(
      "CREATE TRIGGER fail_replacement BEFORE INSERT ON offline_tiles WHEN NEW.key LIKE 'prepared/${second.region.packageId}/%' BEGIN SELECT RAISE(ABORT,'fixture failure'); END",
    );
    await expectLater(store.importPackage(second), throwsException);
    expect((await store.regions()).single.packageId, first.region.packageId);
    expect((await store.tiles()).length, first.files.length);
    await store.close();
    store = create();
    addTearDown(store.close);
    final active = jsonDecode(
      utf8.decode((await store.load('prepared.json', cacheOnly: true)).bytes),
    );
    expect(active['packageId'], first.region.packageId);
    expect(
      (await store.load(
        'prepared/${first.region.packageId}/terrain/0/1/0.terrain',
      )).bytes,
      first.files['terrain/0/1/0.terrain'],
    );
    await expectLater(
      store.load('prepared/${first.region.packageId}/terrain/16/0/0.terrain'),
      throwsStateError,
    );
    expect(requests, 0);
    await store.clear();
    expect(await store.tiles(), isEmpty);
  });
  testWidgets(
    'offline package imports through the compact controls and activates cached rendering',
    (tester) async {
      final database = OsintCacheDatabase(NativeDatabase.memory());
      final store = NativeOfflineMapStore(
        database: database,
        client: MockClient((_) async => throw StateError('No network')),
      );
      var enabled = false, changed = false;
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OfflineRegionsSection(
                  storage: store,
                  cachedMaps: false,
                  onCachedMaps: (v) => enabled = v,
                  onChanged: (r) => changed = r?.packageId != null,
                  packageFiles: const FixturePackageFiles(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Offline-Paket importieren'));
        for (var i = 0; i < 100 && !changed; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(enabled, true);
      expect(changed, true);
      expect(find.textContaining('Offline-Paket importiert.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.close();
      await database.close();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
