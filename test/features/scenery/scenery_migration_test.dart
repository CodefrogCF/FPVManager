import 'dart:convert';
import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_repository.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v12.dart' as v12;
import '../../support/current_schema_verifier.dart';

void main() {
  test('v12 migrates to v13 preserving flight data, settings and legacy scenery alignment', () async {
    final expected = await captureFreshCurrentSchema();
    final verifier = SchemaVerifier(GeneratedHelper()),
        schema = await verifier.schemaAt(12);
    final old = v12.DatabaseAtV12(schema.newConnection());
    await old.customStatement(
      "INSERT INTO spots(name,latitude,longitude) VALUES('Existing spot',52.4,13.8)",
    );
    await old.customStatement(
      "INSERT INTO drones(name) VALUES('Existing drone')",
    );
    await old.customStatement(
      "INSERT INTO flight_plans(name) VALUES('Existing flight')",
    );
    final raw =
        (jsonDecode(File('web/assets/scenery/catalog.json').readAsStringSync())
                as Map)['sceneries']
            as List;
    final original = raw.single as Map<String, dynamic>,
        id = original['id'] as String;
    final alignment = {
      ...(original['alignment'] as Map).cast<String, dynamic>(),
      'ellipsoidHeightM': 145.5,
    };
    await old.customStatement(
      'INSERT INTO app_settings(key,value) VALUES(?,?)',
      [
        'map.scenery.enabled.v1',
        jsonEncode({id: false}),
      ],
    );
    await old.customStatement(
      'INSERT INTO app_settings(key,value) VALUES(?,?)',
      [
        'map.scenery.edits.v1',
        jsonEncode({
          id: {'alignment': alignment, 'bkgHeightOffsetM': -16.9},
        }),
      ],
    );
    await old.close();
    final db = FpvDatabase(schema.newConnection());
    try {
      await migrateAndValidateCurrentSchema(db, expectedSchema: expected);
      expect((await db.select(db.spots).get()).single.name, 'Existing spot');
      expect((await db.select(db.drones).get()).single.name, 'Existing drone');
      expect(
        (await db.select(db.flightPlans).get()).single.name,
        'Existing flight',
      );
      final repository = SceneryRepository(db);
      await repository.initializeBundled([
        SceneryManifest.fromBundled(original),
      ]);
      final manifest = (await repository.list()).single;
      expect(manifest.enabled, false);
      expect((manifest.toJson()['anchor'] as Map)['heightM'], 145.5);
      expect(
        ((manifest.toJson()['extensions'] as Map)['cesium']
            as Map)['bkgHeightOffsetM'],
        0.0,
      );
      await repository.remove(id);
      await repository.initializeBundled([
        SceneryManifest.fromBundled(original),
      ]);
      expect(await repository.list(), isEmpty);
    } finally {
      await db.close();
    }
  });
}
