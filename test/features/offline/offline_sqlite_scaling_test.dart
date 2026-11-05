import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/offline/offline_map_store_native.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final region = OfflineRegion(
    id: 'keep',
    name: 'Keep offline',
    west: 8.39,
    south: 46.69,
    east: 8.41,
    north: 46.71,
  );
  final range = region.range(12, terrain: false);
  final validKey = 'imagery/topographic/12/${range.left}/${range.bottom}.jpeg';

  Future<void> seed(OsintCacheDatabase db, int stale) async {
    final payload = Uint8List.fromList([1, 2, 3]);
    await db.batch((b) {
      for (var i = 0; i < stale; i++) {
        b.customStatement('INSERT INTO offline_tiles VALUES (?,?,?,?,?)', [
          'unrelated/${i.toString().padLeft(6, '0')}',
          payload,
          'image/jpeg',
          1,
          payload.length,
        ]);
      }
      b.customStatement('INSERT INTO offline_tiles VALUES (?,?,?,?,?)', [
        validKey,
        payload,
        'image/jpeg',
        1,
        payload.length,
      ]);
    });
  }

  test(
    'keyset pruning handles >8 pages without evicting retained offline tiles',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      final store = NativeOfflineMapStore(
        database: db,
        client: MockClient(
          (_) async => throw StateError('No network expected'),
        ),
      );
      addTearDown(db.close);
      addTearDown(store.close);
      await seed(db, 2300);
      await store.setRegions([region]);
      final tiles = await store.tiles();
      expect(tiles.map((t) => t.key), [validKey]);
      expect((await store.regions()).single.id, 'keep');
      await store.clear();
      expect(await store.tiles(), isEmpty);
      expect(await store.regions(), isEmpty);
    },
  );

  test(
    'failed batched pruning atomically preserves previous metadata and bytes',
    () async {
      final db = OsintCacheDatabase(NativeDatabase.memory());
      final store = NativeOfflineMapStore(
        database: db,
        client: MockClient(
          (_) async => throw StateError('No network expected'),
        ),
      );
      addTearDown(db.close);
      addTearDown(store.close);
      await store.setRegions([region]);
      await seed(db, 600);
      await db.customStatement(
        "CREATE TRIGGER reject_pruning BEFORE DELETE ON offline_tiles "
        "WHEN OLD.key='unrelated/000400' "
        "BEGIN SELECT RAISE(ABORT,'fixture rollback'); END",
      );
      final changed = OfflineRegion.fromJson({
        ...region.toJson(),
        'id': 'replacement',
        'name': 'Should not commit',
      });
      await expectLater(store.setRegions([changed]), throwsException);
      expect((await store.regions()).single.id, 'keep');
      expect((await store.tiles()).length, 601);
      final row = await db
          .customSelect(
            'SELECT body FROM offline_tiles WHERE key=?',
            variables: [Variable(validKey)],
          )
          .getSingle();
      expect(row.read<Uint8List>('body'), [1, 2, 3]);
    },
  );
}
