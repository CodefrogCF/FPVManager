import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/osint/osint_cache_database.dart';
import 'mobile_site_models.dart';

abstract interface class MobileSiteStore {
  Future<MobileSiteSnapshot?> read(MobileSiteArea area);
  Future<void> replace(MobileSiteSnapshot snapshot);
  Future<List<MobileSite>> viewport(
    MobileSiteArea area,
    List<double> bounds, {
    int limit = 180,
  });
}

/// Bounded, transactional area replacement. Network/parser errors occur before
/// this transaction starts, so an existing generation survives all failures.
class SqliteMobileSiteStore implements MobileSiteStore {
  SqliteMobileSiteStore({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;

  @override
  Future<void> replace(MobileSiteSnapshot snapshot) async {
    if (snapshot.stations.length > 200) {
      throw const FormatException('BAKOM import exceeds the 200-site area cap');
    }
    final metadata = jsonEncode(snapshot.toMetadata());
    if (metadata.length > 12000) {
      throw const FormatException('Invalid metadata size');
    }
    await database.transaction(() async {
      await database.customStatement(
        'DELETE FROM mobile_site_points WHERE area_key=?',
        [snapshot.area.key],
      );
      await database.batch((batch) {
        for (final station in snapshot.stations) {
          final json = jsonEncode(station.toJson());
          batch.customStatement(
            'INSERT INTO mobile_site_points(area_key,site_id,lat,lon,payload) '
            'VALUES(?,?,?,?,?)',
            [
              snapshot.area.key,
              station.id,
              station.latitude,
              station.longitude,
              json,
            ],
          );
        }
      });
      await database.customStatement(
        'INSERT OR REPLACE INTO mobile_site_regions '
        '(area_key,metadata,fetched_at) VALUES(?,?,?)',
        [
          snapshot.area.key,
          metadata,
          snapshot.fetchedUtc.millisecondsSinceEpoch,
        ],
      );
      // At most twelve stored local areas. Pruning is part of the publication.
      await database.customStatement(
        'DELETE FROM mobile_site_regions WHERE area_key NOT IN '
        '(SELECT area_key FROM mobile_site_regions ORDER BY fetched_at DESC LIMIT 12)',
      );
      await database.customStatement(
        'DELETE FROM mobile_site_points WHERE area_key NOT IN '
        '(SELECT area_key FROM mobile_site_regions)',
      );
    });
  }

  @override
  Future<MobileSiteSnapshot?> read(MobileSiteArea area) async {
    final rows = await database
        .customSelect(
          'SELECT metadata FROM mobile_site_regions WHERE area_key=?',
          variables: [Variable(area.key)],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final raw = rows.single.read<String>('metadata');
    if (raw.length > 12000) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final stations = await viewport(area, area.wgs84Envelope, limit: 201);
    final snapshot = MobileSiteSnapshot.fromMetadata(decoded, stations);
    if (snapshot.area.key != area.key) {
      return null;
    }
    return snapshot.cached();
  }

  @override
  Future<List<MobileSite>> viewport(
    MobileSiteArea area,
    List<double> bounds, {
    int limit = 180,
  }) async {
    if (bounds.length != 4 ||
        bounds.any((n) => !n.isFinite) ||
        bounds[0] >= bounds[2] ||
        bounds[1] >= bounds[3] ||
        bounds[2] - bounds[0] > .25 ||
        bounds[3] - bounds[1] > .25) {
      throw const FormatException('Viewport too large or invalid');
    }
    final rows = await database
        .customSelect(
          'SELECT payload FROM mobile_site_points '
          'WHERE area_key=? AND lon>=? AND lon<=? AND lat>=? AND lat<=? '
          'ORDER BY site_id LIMIT ?',
          variables: [
            Variable(area.key),
            Variable(bounds[0]),
            Variable(bounds[2]),
            Variable(bounds[1]),
            Variable(bounds[3]),
            Variable(limit.clamp(1, 201)),
          ],
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (r) => MobileSite.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(r.read<String>('payload')) as Map,
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    if (ownsDatabase) {
      await database.close();
    }
  }
}
