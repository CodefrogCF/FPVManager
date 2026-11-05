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
  int get schemaVersion => 6;
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
      await _createSnapshotRevalidations();
      await _createSnapshotRetentionIndex();
      await _createOfflineMaps();
      await _createMobileSites();
    },
    onUpgrade: (_, from, to) async {
      if (from < 3) await _createOfflineMaps();
      if (from < 4) await _createMobileSites();
      if (from < 5) await _createSnapshotRevalidations();
      if (from < 6) {
        // Some older/partial caches do not contain the v2 snapshot table.
        // Ensure it exists before creating the v6 retention index. Existing
        // snapshot rows must survive migration without replacement.
        await _createSnapshots();
        await _createSnapshotRetentionIndex();
      }
    },
  );

  /// Independent public BAKOM snapshots; never part of user backup/profile data.
  /// Numeric range indexes serve viewport bounding-box queries on Android/Web.
  Future<void> _createMobileSites() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS mobile_site_regions('
      'area_key TEXT PRIMARY KEY, metadata TEXT NOT NULL, fetched_at INTEGER NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS mobile_site_points('
      'area_key TEXT NOT NULL, site_id TEXT NOT NULL, '
      'lat REAL NOT NULL, lon REAL NOT NULL, payload TEXT NOT NULL, '
      'PRIMARY KEY(area_key,site_id))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS mobile_site_view '
      'ON mobile_site_points(area_key,lat,lon)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS mobile_site_view_lon '
      'ON mobile_site_points(area_key,lon,lat)',
    );
  }

  Future<void> _createOfflineMaps() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS offline_regions(id TEXT PRIMARY KEY,payload TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS offline_tiles(key TEXT PRIMARY KEY,body BLOB NOT NULL,content_type TEXT NOT NULL,fetched_at INTEGER NOT NULL,byte_size INTEGER NOT NULL)',
    );
  }

  Future<void> _createSnapshots() => customStatement(
    'CREATE TABLE IF NOT EXISTS osint_snapshots (provider TEXT PRIMARY KEY, '
    'envelope TEXT NOT NULL, checksum TEXT NOT NULL, retained_until INTEGER NOT NULL)',
  );

  /// Retention sweeps must not scan large, still-valid public snapshots.
  /// The provider primary key continues to serve individual lookups.
  Future<void> _createSnapshotRetentionIndex() => customStatement(
    'CREATE INDEX IF NOT EXISTS osint_snapshots_retained_until '
    'ON osint_snapshots(retained_until)',
  );

  Future<void> _createSnapshotRevalidations() => customStatement(
    'CREATE TABLE IF NOT EXISTS osint_snapshot_revalidations('
    'provider TEXT PRIMARY KEY, base_checksum TEXT NOT NULL, '
    'metadata TEXT NOT NULL, metadata_checksum TEXT NOT NULL)',
  );

  Future<(String, String)?> readSnapshotRevalidation(
    String provider,
    String baseChecksum,
  ) async {
    final row = await customSelect(
      'SELECT metadata, metadata_checksum FROM osint_snapshot_revalidations '
      'WHERE provider=? AND base_checksum=?',
      variables: [Variable(provider), Variable(baseChecksum)],
    ).getSingleOrNull();
    return row == null
        ? null
        : (row.read<String>('metadata'), row.read<String>('metadata_checksum'));
  }

  Future<void> clearSnapshotRevalidation(String provider) => customStatement(
    'DELETE FROM osint_snapshot_revalidations WHERE provider=?',
    [provider],
  );

  /// Updates only small HTTP validators/check times, never re-serializes the
  /// large official dataset. The base snapshot is required and both updates
  /// commit atomically. Overlay is tied to its checksum to reject old data.
  Future<void> writeSnapshotRevalidation(
    String provider,
    String metadata,
    String metadataChecksum,
    DateTime retainedUntil,
  ) => transaction(() async {
    final base = await customSelect(
      'SELECT checksum FROM osint_snapshots WHERE provider=?',
      variables: [Variable(provider)],
    ).getSingleOrNull();
    if (base == null) throw StateError('Missing base OSINT snapshot');
    await customStatement(
      'INSERT OR REPLACE INTO osint_snapshot_revalidations VALUES (?,?,?,?)',
      [provider, base.read<String>('checksum'), metadata, metadataChecksum],
    );
    await customStatement(
      'UPDATE osint_snapshots SET retained_until=? WHERE provider=?',
      [retainedUntil.millisecondsSinceEpoch, provider],
    );
  });

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
  ) => transaction(() async {
    await customStatement(
      'INSERT OR REPLACE INTO osint_snapshots VALUES (?,?,?,?)',
      [provider, payload, checksum, retainedUntil.millisecondsSinceEpoch],
    );
    await clearSnapshotRevalidation(provider);
  });

  Future<void> removeSnapshot(String provider) => transaction(() async {
    await clearSnapshotRevalidation(provider);
    await customStatement('DELETE FROM osint_snapshots WHERE provider=?', [
      provider,
    ]);
  });

  Future<void> cleanSnapshots(DateTime now) => transaction(() async {
    await customStatement(
      'DELETE FROM osint_snapshots WHERE retained_until<=?',
      [now.millisecondsSinceEpoch],
    );
    await customStatement(
      'DELETE FROM osint_snapshot_revalidations WHERE NOT EXISTS '
      '(SELECT 1 FROM osint_snapshots WHERE '
      'osint_snapshots.provider=osint_snapshot_revalidations.provider)',
    );
  });

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
