import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v6 indexes retention; cleanup removes only expired public snapshots',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='osint_snapshots_retained_until'",
          )
          .get();
      expect(
        indexes.single.read<String>('name'),
        'osint_snapshots_retained_until',
      );

      final now = DateTime.utc(2026, 11, 5);
      await db.writeSnapshot(
        'expired',
        '{"name":"old"}',
        'digest-1',
        now.subtract(const Duration(seconds: 1)),
      );
      await db.writeSnapshot(
        'live',
        '{"name":"current"}',
        'digest-2',
        now.add(const Duration(days: 1)),
      );
      await db.writeSnapshotRevalidation(
        'live',
        '{"etag":"new"}',
        'meta-digest',
        now.add(const Duration(days: 1)),
      );
      await db.cleanSnapshots(now);
      expect(await db.readSnapshot('expired', 100), isNull);
      expect((await db.readSnapshot('live', 100))!.$1, '{"name":"current"}');
      expect(await db.readSnapshotRevalidation('live', 'digest-2'), isNotNull);
    },
  );

  test(
    'failed public snapshot eviction does not partially delete cache',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 5);
      for (final id in ['a', 'b']) {
        await db.writeSnapshot(
          id,
          '{"saved":true}',
          id,
          now.subtract(const Duration(days: 1)),
        );
      }
      await db.customStatement(
        "CREATE TRIGGER block_expiration BEFORE DELETE ON osint_snapshots "
        "WHEN OLD.provider='b' "
        "BEGIN SELECT RAISE(ABORT,'retain all'); END",
      );
      await expectLater(db.cleanSnapshots(now), throwsException);
      for (final id in ['a', 'b']) {
        expect(await db.readSnapshot(id, 100), isNotNull);
      }
    },
  );
  for (final hasSnapshots in [false, true]) {
    test('v2 cache migration ${hasSnapshots ? 'preserves' : 'repairs missing'} '
        'snapshots and creates retention index', () async {
      final db = OsintCacheDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 2');
            raw.execute(
              'CREATE TABLE datasets('
              'provider TEXT PRIMARY KEY,payload TEXT NOT NULL)',
            );
            raw.execute("INSERT INTO datasets VALUES('existing','retained')");
            if (hasSnapshots) {
              raw.execute(
                'CREATE TABLE osint_snapshots('
                'provider TEXT PRIMARY KEY,envelope TEXT NOT NULL,'
                'checksum TEXT NOT NULL,retained_until INTEGER NOT NULL)',
              );
              raw.execute(
                "INSERT INTO osint_snapshots VALUES("
                "'saved','{\"original\":true}','digest',1800000000000)",
              );
            }
          },
        ),
      );
      addTearDown(db.close);
      final dataset = await db
          .customSelect(
            "SELECT payload FROM datasets WHERE provider='existing'",
          )
          .getSingle();
      expect(dataset.read<String>('payload'), 'retained');
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='osint_snapshots_retained_until'",
          )
          .get();
      expect(indexes, hasLength(1));
      if (hasSnapshots) {
        expect((await db.readSnapshot('saved', 100))!.$1, '{"original":true}');
      } else {
        expect(await db.readSnapshot('saved', 100), isNull);
      }
      await db.writeSnapshot(
        'new',
        '{"valid":true}',
        'checksum',
        DateTime.utc(2026, 11, 7),
      );
      expect((await db.readSnapshot('new', 100))!.$1, '{"valid":true}');
      expect(
        await db.customSelect('SELECT * FROM offline_regions').get(),
        isEmpty,
      );
    });
  }

  test(
    'existing v5 cache migrates to v6 without losing public snapshots',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'fpv-osint-v5-migration-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/cache.sqlite');
      final first = OsintCacheDatabase(NativeDatabase(file));
      await first.writeSnapshot(
        'saved',
        '{"original":true}',
        'digest',
        DateTime.utc(2026, 11, 7),
      );
      // Schema v5 differs from v6 only by this retention index. Simulate the
      // existing persisted version and verify the real onUpgrade path.
      await first.customStatement('DROP INDEX osint_snapshots_retained_until');
      await first.customStatement('PRAGMA user_version = 5');
      await first.close();
      final reopened = OsintCacheDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(
        (await reopened.readSnapshot('saved', 100))!.$1,
        '{"original":true}',
      );
      final index = await reopened
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='osint_snapshots_retained_until'",
          )
          .get();
      expect(index, hasLength(1));
    },
  );

  test(
    'concurrent snapshot updates retain matching payload and checksum',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final retained = DateTime.utc(2026, 11, 7);
      await Future.wait([
        for (var i = 0; i < 24; i++)
          db.writeSnapshot('shared', '{"version":$i}', 'digest-$i', retained),
      ]);
      final result = (await db.readSnapshot('shared', 100))!;
      final version = int.parse(
        RegExp(r'"version":(\d+)').firstMatch(result.$1)!.group(1)!,
      );
      expect(result.$2, 'digest-$version');
    },
  );
}
