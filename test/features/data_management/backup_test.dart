import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_codec.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/preflight/checklist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FpvDatabase database;
  late BackupRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = BackupRepository(database);
  });
  tearDown(() => database.close());
  Future<void> seed() async {
    for (final sql in [
      "INSERT INTO spots(id,name,latitude,longitude,notes,search_text) VALUES(7,'Secret spot',46.7,8.4,'Private notes','secret spot private notes')",
      "INSERT INTO drones(id,name) VALUES(2,'Freestyle')",
      "INSERT INTO batteries(id,name,cell_count,capacity_mah,is_type) VALUES(3,'6S template',6,1300,1)",
      "INSERT INTO batteries(id,name,cell_count,capacity_mah,type_id) VALUES(4,'Pack',6,1300,3)",
      "INSERT INTO flight_plans(id,name,drone_id,start_spot_id,planning_json) VALUES(5,'Route',2,7,'{}')",
      "INSERT INTO flight_waypoints(plan_id,sequence_number,latitude,longitude,height_meters,altitude_mode) VALUES(5,0,46.7,8.4,30,'aboveGroundLevel')",
      "INSERT INTO battery_drones VALUES(4,2)",
      "INSERT INTO battery_flight_plans VALUES(4,5)",
      "INSERT INTO radio_equipment(id,name,category) VALUES(8,'Radio','control')",
      "INSERT INTO radio_equipment_drones VALUES(8,2)",
      "INSERT INTO drone_parameter_sources VALUES(2,'hoverPowerWatts','measured')",
      "INSERT INTO spot_tags VALUES(7,'private')",
    ]) {
      await database.customStatement(sql);
    }
    await database.customStatement(
      "INSERT INTO preflight_checklists(name,items_json,drone_id,plan_id) VALUES('Checklist',?,2,5)",
      [
        encodeChecklist([const ChecklistItem('Review')]),
      ],
    );
    await database.customStatement(
      'INSERT INTO spot_photos(spot_id,image_bytes,thumbnail_bytes,width,height) VALUES(7,?,?,2,2)',
      [
        image.encodeJpg(image.Image(width: 2, height: 2)),
        image.encodeJpg(image.Image(width: 1, height: 1)),
      ],
    );
    await database.customStatement(
      'INSERT INTO telemetry_flights(file_name,raw_bytes,drone_id,plan_id) VALUES(?,?,2,5)',
      ['flight.csv', Uint8List.fromList(utf8.encode('time,voltage\n0,22'))],
    );
    for (final key in ['map.style', 'private.future.api.key']) {
      await database.customStatement('INSERT INTO app_settings VALUES(?,?,0)', [
        key,
        key == 'map.style' ? 'relief' : 'DO NOT EXPORT',
      ]);
    }
  }

  test('portable replacement preserves every table, image and association and excludes secrets', () async {
    await seed();
    final bytes = await repository.create();
    expect(isEncryptedBackup(bytes), isFalse);
    expect(utf8.decode(bytes.sublist(69)), isNot(contains('DO NOT EXPORT')));
    final document = await repository.preview(bytes);
    final before = {
      for (final t in database.allTables)
        t.actualTableName: await database
            .customSelect('SELECT * FROM "${t.actualTableName}"')
            .get(),
    };
    await database.customStatement(
      "INSERT INTO spots(name,latitude,longitude) VALUES('Later',47,8)",
    );
    await repository.restore(document);
    for (final t in database.allTables) {
      final actual = await database
          .customSelect('SELECT * FROM "${t.actualTableName}"')
          .get();
      expect(
        actual.map((r) => r.data),
        unorderedEquals(before[t.actualTableName]!.map((r) => r.data)),
        reason: t.actualTableName,
      );
    }
    expect(
      (await database.customSelect('PRAGMA foreign_key_check').get()),
      isEmpty,
    );
  });
  test('AES-GCM authenticates password, ciphertext, nonce and header; salt and nonce are fresh', () async {
    final payload = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'fpvmanager-backup',
          'version': 1,
          'schema': 9,
          'createdAt': '2026-10-25T12:00:00Z',
          'tables': <String, dynamic>{},
        }),
      ),
    );
    const password = 'long unique backup password';
    final a = await encodeBackup(BackupEncodeJob(payload, password)),
        b = await encodeBackup(BackupEncodeJob(payload, password));
    expect(a, isNot(equals(b)));
    expect(isEncryptedBackup(a), isTrue);
    expect((await decodeBackup(BackupDecodeJob(a, password)))['schema'], 9);
    await expectLater(
      decodeBackup(BackupDecodeJob(a, 'incorrect password')),
      throwsFormatException,
    );
    for (final index in [9, 25, a.length - 1]) {
      final broken = Uint8List.fromList(a);
      broken[index] ^= 1;
      await expectLater(
        decodeBackup(BackupDecodeJob(broken, password)),
        throwsFormatException,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('invalid records, SQL names and broken references preserve the existing data atomically', () async {
    await seed();
    final doc = await repository.preview(await repository.create());
    final spots = (doc['tables'] as Map)['spots'] as List;
    spots.add({...spots.first as Map, 'id': 99, 'name': 'Staged'});
    ((doc['tables'] as Map)['flight_plans'] as List).first['drone_id'] = 999;
    await expectLater(repository.restore(doc), throwsFormatException);
    expect((await database.select(database.spots).get()).map((r) => r.id), [7]);
    spots.first['name");DROP TABLE spots;--'] = 'bad';
    await expectLater(repository.restore(doc), throwsFormatException);
    expect(
      (await database.select(database.spots).get()).single.name,
      'Secret spot',
    );
  });
  test(
    'v1 and v8 database backup records migrate without requiring legacy SQL',
    () async {
      for (final schema in [1, 8]) {
        final doc = {
          'schema': schema,
          'tables': <String, dynamic>{
            'spots': [
              {
                'id': 12,
                'name': 'Legacy',
                'latitude': 46.0,
                'longitude': 8.0,
                'notes': 'Known',
                if (schema >= 4) 'search_text': 'legacy known',
              },
            ],
          },
        };
        if (schema == 8) {
          final tables = doc['tables'] as Map;
          for (final t in database.allTables) {
            if (![
              'preflight_checklists',
              'telemetry_flights',
            ].contains(t.actualTableName)) {
              tables.putIfAbsent(t.actualTableName, () => []);
            }
          }
        }
        await repository.restore(doc);
        final spot = (await database.select(database.spots).get()).single;
        expect(spot.id, 12);
        expect(spot.name, 'Legacy');
        expect(spot.searchText, startsWith('legacy known'));
        expect(
          await database.select(database.preflightChecklists).get(),
          isEmpty,
        );
      }
      await expectLater(
        repository.restore({'schema': 11, 'tables': {}}),
        throwsFormatException,
      );
    },
  );
  test('invalid waypoint semantics, preferences and nested planning data cannot replace personal records', () async {
    await seed();
    final document = await repository.preview(await repository.create());
    final changes = <void Function(Map)>[
      (tables) => (tables['flight_waypoints'] as List).first['altitude_mode'] =
          'unknown',
      (tables) =>
          (tables['flight_waypoints'] as List).first['sequence_number'] = 3,
      (tables) =>
          (tables['app_settings'] as List).first['value'] = 'unknown-map',
      (tables) =>
          (tables['preflight_checklists'] as List).first['items_json'] = '[]',
      (tables) => (tables['flight_plans'] as List).first['planning_json'] =
          '{"nested":${'[' * 21}0${']' * 21}}',
    ];
    for (final change in changes) {
      final invalid = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
      change(invalid['tables'] as Map);
      await expectLater(repository.restore(invalid), throwsFormatException);
      expect(
        (await database.select(database.spots).get()).single.name,
        'Secret spot',
      );
      expect(
        (await database.select(database.flightWaypoints).get())
            .single
            .sequenceNumber,
        0,
      );
    }
  });
  test('truncated, deeply nested, wrong version and modified plaintext files are rejected', () async {
    await seed();
    final original = await repository.create();
    final changed = Uint8List.fromList(original);
    changed[changed.length - 1] ^= 1;
    await expectLater(repository.preview(changed), throwsFormatException);
    for (final bytes in [Uint8List(0), original.sublist(0, 20)]) {
      await expectLater(repository.preview(bytes), throwsFormatException);
    }
    for (final payload in [
      '[' * 13 + ']' * 13,
      jsonEncode({'format': 'fpvmanager-backup', 'version': 2}),
    ]) {
      final bytes = await encodeBackup(
        BackupEncodeJob(Uint8List.fromList(utf8.encode(payload)), null),
      );
      await expectLater(repository.preview(bytes), throwsFormatException);
    }
    expect(
      (await database.select(database.spots).get()).single.name,
      'Secret spot',
    );
  });
}
