import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/obstacles/obstacle_models.dart';

/// Downloaded public datasets are separate from user-owned spots and backups.
/// Staging generations remain invisible until publication in one transaction.
class OsintCacheDatabase extends GeneratedDatabase {
  OsintCacheDatabase(super.executor);
  factory OsintCacheDatabase.open() => OsintCacheDatabase(
    driftDatabase(
      name: 'fpvmanager_osint_cache',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE datasets (provider TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE obstacles (snapshot TEXT NOT NULL, id TEXT NOT NULL, '
        'category TEXT NOT NULL, west REAL NOT NULL, south REAL NOT NULL, east REAL NOT NULL, '
        'north REAL NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(snapshot,id))',
      );
      await customStatement(
        'CREATE INDEX obstacles_view ON obstacles(snapshot, category, west, east, south, north)',
      );
      await _createSnapshots();
      await _createOfflineMaps();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createSnapshots();
      if (from < 3) await _createOfflineMaps();
    },
  );

  Future<void> _createOfflineMaps() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS offline_regions(id TEXT PRIMARY KEY,payload TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS offline_tiles(key TEXT PRIMARY KEY,body BLOB NOT NULL,content_type TEXT NOT NULL,fetched_at INTEGER NOT NULL,byte_size INTEGER NOT NULL)',
    );
  }

  Future<void> _createSnapshots() => customStatement(
    'CREATE TABLE osint_snapshots (provider TEXT PRIMARY KEY, '
    'envelope TEXT NOT NULL, checksum TEXT NOT NULL, retained_until INTEGER NOT NULL)',
  );

  Future<(String, String)?> readSnapshot(String provider, int maxBytes) async {
    final row = await customSelect(
      'SELECT CASE WHEN length(CAST(envelope AS BLOB))<=? THEN envelope END AS payload, '
      'checksum FROM osint_snapshots WHERE provider=?',
      variables: [Variable(maxBytes), Variable(provider)],
    ).getSingleOrNull();
    if (row == null) return null;
    final payload = row.readNullable<String>('payload');
    if (payload == null) {
      throw const FormatException('Cached dataset is too large');
    }
    return (payload, row.read<String>('checksum'));
  }

  Future<void> writeSnapshot(
    String provider,
    String payload,
    String checksum,
    DateTime retainedUntil,
  ) => customStatement(
    'INSERT OR REPLACE INTO osint_snapshots VALUES (?,?,?,?)',
    [provider, payload, checksum, retainedUntil.millisecondsSinceEpoch],
  );

  Future<void> removeSnapshot(String provider) => customStatement(
    'DELETE FROM osint_snapshots WHERE provider=?',
    [provider],
  );

  Future<void> cleanSnapshots(DateTime now) => customStatement(
    'DELETE FROM osint_snapshots WHERE retained_until<=?',
    [now.millisecondsSinceEpoch],
  );

  Future<ObstacleSnapshot?> obstacleSnapshot() async {
    final row = await customSelect(
      "SELECT payload FROM datasets WHERE provider='swiss-obstacles'",
    ).getSingleOrNull();
    return row == null
        ? null
        : ObstacleSnapshot.fromJson(
            jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
          );
  }

  Future<void> stageObstacles(String key, List<ObstacleFeature> features) =>
      batch((b) {
        for (final f in features) {
          b.customStatement('INSERT INTO obstacles VALUES (?,?,?,?,?,?,?,?)', [
            key,
            f.id,
            f.category.name,
            f.west,
            f.south,
            f.east,
            f.north,
            jsonEncode(f.toJson()),
          ]);
        }
      });
  Future<void> discardObstacles(String key) =>
      customStatement('DELETE FROM obstacles WHERE snapshot=?', [key]);
  Future<void> publishObstacles(ObstacleSnapshot snapshot) =>
      transaction(() async {
        await customStatement('INSERT OR REPLACE INTO datasets VALUES (?,?)', [
          'swiss-obstacles',
          jsonEncode(snapshot.toJson()),
        ]);
        await customStatement('DELETE FROM obstacles WHERE snapshot<>?', [
          snapshot.key,
        ]);
      });
  Future<void> cleanObstacleStaging() async {
    final active = await obstacleSnapshot();
    await customStatement('DELETE FROM obstacles WHERE snapshot<>?', [
      active?.key ?? '',
    ]);
  }

  Future<List<ObstacleFeature>> queryObstacles(
    String key,
    ObstacleViewport v,
    Set<ObstacleCategory> categories, {
    int limit = 1201,
    bool localViewOnly = true,
    bool pointsOnly = false,
  }) async {
    if (categories.isEmpty || (localViewOnly && !v.isLocal)) return [];
    final rows = await customSelect(
      'SELECT payload FROM obstacles WHERE snapshot=? AND '
      'west<=? AND east>=? AND south<=? AND north>=? AND category IN '
      '(${List.filled(categories.length, '?').join(',')}) '
      '${pointsOnly ? "AND json_array_length(payload, '\$.parts')=1 AND json_extract(payload, '\$.parts[0].kind')='Point' " : ""}'
      'ORDER BY id LIMIT ?',
      variables: [
        Variable(key),
        Variable(v.east),
        Variable(v.west),
        Variable(v.north),
        Variable(v.south),
        ...categories.map((c) => Variable(c.name)),
        Variable(limit.clamp(1, 1201)),
      ],
    ).get();
    return rows
        .map(
          (r) => ObstacleFeature.fromJson(
            jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
