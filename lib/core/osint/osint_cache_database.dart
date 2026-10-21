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
  int get schemaVersion => 1;
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
    },
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
  }) async {
    if (categories.isEmpty || !v.isLocal) return [];
    final rows = await customSelect(
      'SELECT payload FROM obstacles WHERE snapshot=? AND '
      'west<=? AND east>=? AND south<=? AND north>=? AND category IN '
      '(${List.filled(categories.length, '?').join(',')}) ORDER BY id LIMIT ?',
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
