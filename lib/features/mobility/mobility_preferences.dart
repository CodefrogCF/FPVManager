import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/fpv_database.dart';
import 'road_routing.dart';
import 'ojp/ojp_models.dart';

class SpotAccess {
  const SpotAccess({this.parking, this.access});
  final MobilityPoint? parking, access;
}

/// User-owned last-mile notes stay in the personal database, outside OSINT caches.
class MobilityPreferences {
  const MobilityPreferences(this.database);
  final FpvDatabase database;
  String _key(int spotId) => 'mobility.access.$spotId.v1';
  Future<SpotAccess> loadAccess(int spotId) async {
    final row = await (database.select(
      database.appSettings,
    )..where((r) => r.key.equals(_key(spotId)))).getSingleOrNull();
    if (row == null) return const SpotAccess();
    final json = jsonDecode(row.value) as Map;
    return SpotAccess(
      parking: json['parking'] == null
          ? null
          : MobilityPoint.fromJson(json['parking']),
      access: json['access'] == null
          ? null
          : MobilityPoint.fromJson(json['access']),
    );
  }

  static const _ojpSnapshotsKey = 'mobility.ojp.snapshots.v1';

  /// Keeps at most five explicitly saved, dated snapshots in local app data.
  /// An OJP credential is never written to this table.
  Future<List<OjpJourneySnapshot>> loadOjpSnapshots() async {
    final row = await (database.select(
      database.appSettings,
    )..where((r) => r.key.equals(_ojpSnapshotsKey))).getSingleOrNull();
    if (row == null) return [];
    if (row.value.length > 1024 * 1024) {
      throw const FormatException('Saved OJP data too large');
    }
    final decoded = jsonDecode(row.value);
    if (decoded is! List || decoded.length > 5) {
      throw const FormatException('Invalid saved OJP journeys');
    }
    return [
      for (final item in decoded)
        OjpJourneySnapshot.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<void> saveOjpSnapshot(OjpJourneySnapshot snapshot) async {
    final current = await loadOjpSnapshots();
    final updated = [
      snapshot,
      ...current.where(
        (item) => item.query.identity != snapshot.query.identity,
      ),
    ].take(5).toList();
    final data = jsonEncode(updated.map((item) => item.toJson()).toList());
    if (data.length > 1024 * 1024) {
      throw const FormatException('Saved OJP data too large');
    }
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _ojpSnapshotsKey,
            value: data,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> saveAccess(int spotId, SpotAccess value) =>
      database.transaction(() async {
        final spot = await (database.select(
          database.spots,
        )..where((s) => s.id.equals(spotId))).getSingleOrNull();
        if (spot == null) throw StateError('Spot no longer exists');
        if (value.parking == null && value.access == null) {
          await (database.delete(
            database.appSettings,
          )..where((r) => r.key.equals(_key(spotId)))).go();
        } else {
          await database
              .into(database.appSettings)
              .insertOnConflictUpdate(
                AppSettingsCompanion.insert(
                  key: _key(spotId),
                  value: jsonEncode({
                    'parking': value.parking?.toJson(),
                    'access': value.access?.toJson(),
                  }),
                  updatedAt: Value(DateTime.now().toUtc()),
                ),
              );
        }
      });
}
