import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:fpvmanager/features/offline/offline_region.dart';

/// Standalone, synthetic *SQL-pattern* benchmark.
///
/// This deliberately doesn't import FpvDatabase, OsintCacheDatabase or
/// NativeOfflineMapStore: they depend on drift_flutter, which requires a
/// Flutter engine and cannot be launched by `dart run`.
///
/// The SQL and keyset algorithm mirror the production implementation. The
/// actual repositories, migrations and offline lifecycle are tested by
/// `flutter test` instead. Only in-memory, synthetic records are used here.
Future<void> main(List<String> arguments) async {
  final tiles = _option(arguments, '--tiles', 10000, 1, 100000);
  final spots = _option(arguments, '--spots', 10000, 1, 100000);
  final runs = _option(arguments, '--runs', 3, 1, 12);
  stdout.writeln(
    'FPVManager synthetic SQLite SQL-pattern benchmark; tiles=$tiles '
    'spots=$spots runs=$runs; no personal or downloaded data used',
  );

  final region = OfflineRegion(
    id: 'region',
    name: 'Benchmark',
    west: 8.39,
    south: 46.69,
    east: 8.41,
    north: 46.71,
  );

  final legacy = <double>[];
  final bounded = <double>[];
  for (var run = 1; run <= runs; run++) {
    legacy.add(await _prune(tiles, region, batched: false));
    bounded.add(await _prune(tiles, region, batched: true));
    stdout.writeln(
      'run=$run legacy_prune_ms=${legacy.last.toStringAsFixed(2)} '
      'bounded_prune_ms=${bounded.last.toStringAsFixed(2)}',
    );
  }
  stdout.writeln(
    'median_legacy_ms=${_median(legacy).toStringAsFixed(2)} '
    'median_bounded_ms=${_median(bounded).toStringAsFixed(2)} '
    'speedup=${(_median(legacy) / _median(bounded)).toStringAsFixed(2)}x',
  );

  await _spotBenchmark(spots);
  stdout.writeln(
    'SQL-pattern benchmark only: production Drift repositories are exercised '
    'by flutter test. Times depend on the SQLite backend, JIT, OS, and cache; '
    'GC, peak memory, and UI responsiveness are not measured.',
  );
}

int _option(
  List<String> arguments,
  String name,
  int fallback,
  int min,
  int max,
) {
  final option = arguments.where((arg) => arg.startsWith('$name=')).firstOrNull;
  final parsed = option == null
      ? fallback
      : int.tryParse(option.substring(name.length + 1));
  if (parsed == null || parsed < min || parsed > max) {
    throw FormatException('$name must be between $min and $max');
  }
  return parsed;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// SQL-only in-memory database: no drift_flutter, dart:ui or app state.
class _BenchmarkDatabase extends GeneratedDatabase {
  _BenchmarkDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE offline_regions('
        'id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE offline_tiles('
        'key TEXT PRIMARY KEY, body BLOB NOT NULL, '
        'content_type TEXT NOT NULL, fetched_at INTEGER NOT NULL, '
        'byte_size INTEGER NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE spots('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
        'latitude REAL NOT NULL, longitude REAL NOT NULL, '
        'is_favorite INTEGER NOT NULL, category TEXT, '
        'category_key TEXT NOT NULL, search_text TEXT NOT NULL, notes TEXT)',
      );
      await customStatement(
        'CREATE TABLE spot_tags('
        'spot_id INTEGER NOT NULL, tag TEXT NOT NULL, '
        'PRIMARY KEY (spot_id,tag))',
      );
      await customStatement(
        'CREATE INDEX spots_category_id ON spots(category_key,id)',
      );
      await customStatement(
        'CREATE INDEX spots_favorite_id ON spots(is_favorite,id)',
      );
    },
  );
}

Future<double> _prune(
  int stale,
  OfflineRegion region, {
  required bool batched,
}) async {
  final db = _BenchmarkDatabase();
  try {
    final body = Uint8List.fromList([1, 2, 3, 4]);
    final range = region.range(12, terrain: false);
    final retained =
        'imagery/topographic/12/${range.left}/${range.bottom}.jpeg';
    await db.batch((batch) {
      for (var i = 0; i < stale; i++) {
        batch.customStatement('INSERT INTO offline_tiles VALUES (?,?,?,?,?)', [
          'unrelated/${i.toString().padLeft(6, '0')}',
          body,
          'image/jpeg',
          1,
          body.length,
        ]);
      }
      batch.customStatement('INSERT INTO offline_tiles VALUES (?,?,?,?,?)', [
        retained,
        body,
        'image/jpeg',
        1,
        body.length,
      ]);
    });

    final watch = Stopwatch()..start();
    await db.transaction(() async {
      await db.customStatement('DELETE FROM offline_regions');
      await db.customStatement('INSERT INTO offline_regions VALUES (?,?)', [
        region.id,
        jsonEncode(region.toJson()),
      ]);
      if (batched) {
        // Mirrors NativeOfflineMapStore.setRegions(): keyset scan plus a
        // single indexed DELETE for each bounded page of discarded keys.
        String? afterKey;
        while (true) {
          final rows = await db
              .customSelect(
                afterKey == null
                    ? 'SELECT key FROM offline_tiles ORDER BY key LIMIT 256'
                    : 'SELECT key FROM offline_tiles WHERE key>? '
                          'ORDER BY key LIMIT 256',
                variables: afterKey == null ? const [] : [Variable(afterKey)],
              )
              .get();
          if (rows.isEmpty) break;
          final removed = <String>[];
          for (final row in rows) {
            final key = row.read<String>('key');
            if (!region.includesKey(key)) removed.add(key);
          }
          afterKey = rows.last.read<String>('key');
          if (removed.isNotEmpty) {
            await db.customStatement(
              'DELETE FROM offline_tiles WHERE key IN '
              '(${List.filled(removed.length, '?').join(',')})',
              removed,
            );
          }
        }
      } else {
        final rows = await db
            .customSelect('SELECT key,byte_size,fetched_at FROM offline_tiles')
            .get();
        for (final row in rows) {
          final key = row.read<String>('key');
          if (!region.includesKey(key)) {
            await db.customStatement('DELETE FROM offline_tiles WHERE key=?', [
              key,
            ]);
          }
        }
      }
    });
    watch.stop();

    final remaining = await db
        .customSelect('SELECT key FROM offline_tiles ORDER BY key LIMIT 2')
        .get();
    if (remaining.length != 1 ||
        remaining.single.read<String>('key') != retained) {
      throw StateError('Benchmark pruning changed retention semantics');
    }
    return watch.elapsedMicroseconds / 1000;
  } finally {
    await db.close();
  }
}

Future<void> _spotBenchmark(int count) async {
  final db = _BenchmarkDatabase();
  try {
    await db.batch((batch) {
      for (var i = 0; i < count; i++) {
        batch.customStatement(
          'INSERT INTO spots('
          'name,latitude,longitude,is_favorite,category,category_key,'
          'search_text,notes) VALUES (?,?,?,?,?,?,?,?)',
          [
            'Spot $i',
            47.0,
            8.0,
            i % 5 == 0 ? 1 : 0,
            null,
            i.isEven ? 'alpine' : 'field',
            'spot $i',
            null,
          ],
        );
      }
    });

    // Mirrors DriftSpotRepository._pageQuery() with favorite + category
    // filters; preserves its id-keyset paging and notes/tags projection.
    const query = '''
      SELECT s.id, s.name, s.latitude, s.longitude, s.is_favorite, s.category,
             substr(coalesce(s.notes, ''), 1, 120) AS notes_preview,
             (SELECT group_concat(tag, char(31)) FROM
               (SELECT tag FROM spot_tags WHERE spot_id = s.id ORDER BY tag)) AS tags
      FROM spots s
      WHERE s.is_favorite = 1 AND s.category_key = ?
      ORDER BY s.id DESC LIMIT ?
    ''';
    final watch = Stopwatch()..start();
    final first = await db
        .customSelect(
          query,
          variables: [const Variable('alpine'), const Variable(51)],
        )
        .get();
    watch.stop();

    final next = first.length <= 50
        ? const <QueryRow>[]
        : await db
              .customSelect(
                '''
            SELECT s.id, s.name, s.latitude, s.longitude,
                   s.is_favorite, s.category,
                   substr(coalesce(s.notes, ''), 1, 120) AS notes_preview,
                   (SELECT group_concat(tag, char(31)) FROM
                     (SELECT tag FROM spot_tags
                      WHERE spot_id = s.id ORDER BY tag)) AS tags
            FROM spots s
            WHERE s.is_favorite = 1 AND s.category_key = ? AND s.id < ?
            ORDER BY s.id DESC LIMIT ?
            ''',
                variables: [
                  const Variable('alpine'),
                  Variable(first[49].read<int>('id')),
                  const Variable(51),
                ],
              )
              .get();

    stdout.writeln(
      'spot_page_ms=${(watch.elapsedMicroseconds / 1000).toStringAsFixed(2)} '
      'page_size=${first.length > 50 ? 50 : first.length} '
      'has_next=${first.length > 50} '
      'second_page_size=${next.length > 50 ? 50 : next.length}',
    );

    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT id FROM spots '
          'WHERE category_key=? AND is_favorite=1 ORDER BY id DESC LIMIT 51',
          variables: [const Variable('alpine')],
        )
        .get();
    for (final row in plan) {
      stdout.writeln('spot_query_plan=${row.read<String>('detail')}');
    }
  } finally {
    await db.close();
  }
}
