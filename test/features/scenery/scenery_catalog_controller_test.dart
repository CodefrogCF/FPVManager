import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_catalog_controller.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';

import '../../support/scenery_fixture.dart';

void main() {
  late FpvDatabase db;
  late SceneryRepository repo;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repo = SceneryRepository(db);
  });
  tearDown(() => db.close());
  final bundled = File('web/assets/scenery/catalog.json').readAsStringSync();
  test('shutdown does not wait for a renderer and cannot start storage work afterwards', () async {
    final gate = Completer<void>();
    final controller = SceneryCatalogController(
      repository: repo,
      loadBundled: () async {
        await gate.future;
        return bundled;
      },
      canSend: () => true,
      send: (_) async => {'sceneries': []},
    );
    final pending = controller.synchronize();
    final rejected = expectLater(pending, throwsStateError);
    controller.dispose();
    await controller.storageSettled;
    gate.complete();
    await rejected;
    expect(await repo.list(), isEmpty);
  });
  test(
    'obsolete queued renderer generations never send their catalog',
    () async {
      final gate = Completer<void>();
      var sent = 0;
      var current = true;
      final controller = SceneryCatalogController(
        repository: repo,
        loadBundled: () async {
          await gate.future;
          return bundled;
        },
        canSend: () => true,
        send: (_) async {
          sent++;
          return {'sceneries': []};
        },
      );
      final obsolete = controller.synchronize(isCurrent: () => current);
      current = false;
      final newest = controller.synchronize(isCurrent: () => true);
      gate.complete();
      await Future.wait([obsolete, newest]);
      expect(sent, 1);
    },
  );
  test('restoring an older backup in the same session reinitializes legacy definitions', () async {
    final controller = SceneryCatalogController(
      repository: repo,
      loadBundled: () async => bundled,
      canSend: () => true,
      send: (_) async => {'sceneries': []},
    );
    final first = await controller.definitions();
    await controller.remove(first.single.id);
    await db.customStatement('DELETE FROM sceneries');
    await db.customStatement('DELETE FROM app_settings WHERE key=?', [
      SceneryRepository.initializedKey,
    ]);
    await controller.synchronize();
    expect((await controller.definitions()).single.id, first.single.id);
  });
  test('synchronization repairs stripped bundled building masks without resetting saved pose', () async {
    Map<String, dynamic>? sent;
    final controller = SceneryCatalogController(
      repository: repo,
      loadBundled: () async => bundled,
      canSend: () => true,
      send: (command) async {
        sent = command;
        return {};
      },
    );
    final base = (await controller.definitions()).single;
    final doc = base.toJson();
    final source = doc['extensions']['cesium'] as Map;
    final originalRegions = source['buildingRegions'];
    final anchor = doc['anchor'] as Map;
    anchor['longitude'] = (anchor['longitude'] as num) + .00004;
    for (final key in [
      'buildingRegions',
      'terrainRegions',
      'terrainCertificate',
      'terrainCertificates',
      'terrainUnderlay',
      'heightCalibration',
      'heightAlignmentMode',
      'requireGroundCalibration',
      'groundReferenceLocalUp',
    ]) {
      source.remove(key);
    }
    source['replaceBuildings'] = false;
    source['clipTerrain'] = false;
    await repo.update(SceneryManifest.fromJson(doc));
    await controller.synchronize();
    final restored = (await repo.list()).single.toJson();
    expect(restored['anchor'], anchor);
    expect(
      restored['extensions']['cesium']['buildingRegions'],
      originalRegions,
    );
    final item = (sent!['catalog']['sceneries'] as List).single as Map;
    expect(item['replaceBuildings'], true);
    expect(item['clipTerrain'], false);
    // Explicitly disabled existing footprint is authoritative.
    restored['extensions']['cesium']['replaceBuildings'] = false;
    await repo.update(SceneryManifest.fromJson(restored));
    await controller.synchronize();
    expect(
      (sent!['catalog']['sceneries'] as List).single['replaceBuildings'],
      false,
    );
    controller.dispose();
  });
  test(
    'bundled BKG default migrates once without changing placement or masks',
    () async {
      Map<String, dynamic>? sent;
      final controller = SceneryCatalogController(
        repository: repo,
        loadBundled: () async => bundled,
        canSend: () => true,
        send: (command) async {
          sent = command;
          return {};
        },
      );
      final base = (await controller.definitions()).single;
      final doc = base.toJson();
      final cesium = doc['extensions']['cesium'] as Map;
      cesium.remove('bkgHeightOffsetDefaultRevision');
      cesium['bkgHeightOffsetM'] = -16.9;
      await repo.update(SceneryManifest.fromJson(doc));
      await controller.synchronize();
      final migrated = (await repo.list()).single.toJson();
      final result = migrated['extensions']['cesium'] as Map;
      expect(result['bkgHeightOffsetM'], 0);
      expect(result['bkgHeightOffsetDefaultRevision'], 1);
      expect(migrated['anchor'], doc['anchor']);
      expect(result['terrainRegions'], cesium['terrainRegions']);
      expect(result['terrainCertificate'], cesium['terrainCertificate']);
      expect(
        (sent!['catalog']['sceneries'] as List).single['bkgHeightOffsetM'],
        0,
      );
      // A new deliberate edit, even equal to the old default, is respected.
      result['bkgHeightOffsetM'] = -16.9;
      await repo.update(SceneryManifest.fromJson(migrated));
      await controller.synchronize();
      expect(
        (sent!['catalog']['sceneries'] as List).single['bkgHeightOffsetM'],
        -16.9,
      );
      // A previously customized offset is never overwritten.
      result.remove('bkgHeightOffsetDefaultRevision');
      result['bkgHeightOffsetM'] = 3.5;
      await repo.update(SceneryManifest.fromJson(migrated));
      await controller.synchronize();
      expect(
        (sent!['catalog']['sceneries'] as List).single['bkgHeightOffsetM'],
        3.5,
      );
      controller.dispose();
    },
  );
  test('legacy catalog-declared base heights upgrade without overwriting deliberate custom anchors', () {
    final raw =
        ((jsonDecode(bundled) as Map)['sceneries'] as List).single
            as Map<String, dynamic>;
    final base = SceneryManifest.fromBundled(raw),
        original = raw['alignment'] as Map;
    final legacy = {
      'alignment': {
        ...original.cast<String, dynamic>(),
        'ellipsoidHeightM': 34.25,
      },
    };
    expect(
      (base.withLegacyEdit(legacy, migrateLegacyBase: true).toJson()['anchor']
          as Map)['heightM'],
      original['ellipsoidHeightM'],
    );
    legacy['alignment']!['longitude'] = 14;
    expect(
      (base.withLegacyEdit(legacy, migrateLegacyBase: true).toJson()['anchor']
          as Map)['heightM'],
      34.25,
    );
    final changed = base.toJson();
    changed['scale'] = 20.0;
    final catalog = SceneryAssetProviders().compile([
      SceneryManifest.fromJson(changed),
    ]);
    final item = (catalog['sceneries'] as List).single as Map;
    expect(item['terrainCertificate'], isNull);
    expect(item['replaceBuildings'], false);
    expect(item['terrainRegions'], isEmpty);
    final cal = item['heightCalibration'] as Map;
    expect(
      cal['referenceRootHeightM'],
      (cal['referenceGroundHeightM'] as num) -
          (cal['groundReferenceLocalUp'] as num) * 20,
    );
  });
  test('bundled scenery retains calibration, certificates, source and physical transform', () {
    final raw = (jsonDecode(bundled) as Map)['sceneries'] as List;
    final m = SceneryManifest.fromBundled(raw.single as Map<String, dynamic>);
    final item =
        (SceneryAssetProviders().compile([m])['sceneries'] as List).single
            as Map;
    for (final key in [
      'id',
      'collisionAsset',
      'terrainCertificate',
      'terrainCertificates',
      'heightCalibration',
      'bkgHeightOffsetM',
      'groundReferenceLocalUp',
      'buildingRegions',
      'terrainRegions',
    ]) {
      expect(item[key], (raw.single as Map)[key], reason: key);
    }
    expect(
      (item['alignment'] as Map)['ellipsoidHeightM'],
      ((raw.single as Map)['alignment'] as Map)['ellipsoidHeightM'],
    );
  });
  test('reconnect replays database definitions, including removals and unsupported providers', () async {
    final commands = <Map<String, dynamic>>[];
    final controller = SceneryCatalogController(
      repository: repo,
      loadBundled: () async => bundled,
      canSend: () => true,
      send: (c) async {
        commands.add(c);
        return {'sceneries': []};
      },
    );
    await controller.synchronize();
    final defaults = await controller.definitions();
    await controller.remove(defaults.single.id);
    final remote = sceneryFixture().toJson();
    ((remote['assets'] as List).first as Map)['provider'] = 'future';
    await controller.save(SceneryManifest.fromJson(remote), create: true);
    await controller.synchronize();
    final catalog = commands.last['catalog'] as Map;
    expect(catalog['sceneries'], isEmpty);
    expect((catalog['unavailable'] as List).length, 1);
    expect((await controller.definitions()).single.id, 'synthetic-site');
  });
  test(
    'bridge outage retains saved state and synchronization recovers',
    () async {
      var connected = true;
      var fail = false;
      final controller = SceneryCatalogController(
        repository: repo,
        loadBundled: () async => bundled,
        canSend: () => connected,
        send: (c) async {
          if (fail) throw StateError('Bridge timeout');
          return {'sceneries': []};
        },
      );
      await controller.synchronize();
      connected = false;
      await expectLater(
        controller.save(sceneryFixture(), create: true),
        throwsStateError,
      );
      expect(
        (await controller.definitions()).any((m) => m.id == 'synthetic-site'),
        true,
      );
      connected = true;
      fail = true;
      await expectLater(controller.synchronize(), throwsStateError);
      fail = false;
      await controller.synchronize();
      await controller.setEnabled('synthetic-site', false);
      expect(
        (await controller.definitions())
            .firstWhere((m) => m.id == 'synthetic-site')
            .enabled,
        false,
      );
    },
  );
  test(
    'restore only the requested bundled definition and retain other scenes',
    () async {
      final commands = <Map<String, dynamic>>[];
      final controller = SceneryCatalogController(
        repository: repo,
        loadBundled: () async => bundled,
        canSend: () => true,
        send: (c) async {
          commands.add(c);
          return {'sceneries': []};
        },
      );
      final base = (await controller.definitions()).single;
      final changed = base.toJson();
      changed['scale'] = 20.0;
      await controller.save(SceneryManifest.fromJson(changed), create: false);
      await controller.save(sceneryFixture(), create: true);
      await controller.setEnabled(base.id, false);
      await controller.restoreBundled(base.id);
      final all = await controller.definitions();
      final restored = all.firstWhere((m) => m.id == base.id);
      expect(restored.toJson(), base.withEnabled(false).toJson());
      expect(all.any((m) => m.id == 'synthetic-site'), isTrue);
      final catalog = commands.last['catalog'] as Map;
      final item = (catalog['sceneries'] as List).firstWhere(
        (m) => m['id'] == base.id,
      );
      expect(item['collisionRegion'], base.toJson()['bounds']);
    },
  );

  test('writes serialize behind pending bridge work and recover after failed commands', () async {
    final gate = Completer<void>();
    var count = 0;
    final controller = SceneryCatalogController(
      repository: repo,
      loadBundled: () async => bundled,
      canSend: () => true,
      send: (c) async {
        if (++count == 1) await gate.future;
        return {'sceneries': []};
      },
    );
    final first = controller.synchronize();
    final create = controller.save(sceneryFixture(), create: true);
    final disable = controller.setEnabled('synthetic-site', false);
    gate.complete();
    await Future.wait([first, create, disable]);
    expect(count, 3);
    await expectLater(
      controller.save(sceneryFixture(), create: true),
      throwsStateError,
    );
    await controller.remove('synthetic-site');
    await controller.settled;
    expect((await controller.definitions()).length, 1);
  });
}
