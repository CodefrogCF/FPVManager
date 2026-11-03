import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/fpv_database.dart';
import '../../../core/models/spot_classification.dart';
import '../../spots/data/spot_repository.dart';
import 'osm_poi_models.dart';

/// Provenance is not part of the editable spot fields. It survives personal
/// modifications, exports and future Overpass refreshes without merging tags.
class OsmPoiSavedSpots {
  const OsmPoiSavedSpots(this.database, this.spots);
  final FpvDatabase database;
  final SpotRepository spots;

  static String sourceKey(int spotId) => 'spot.osm.source.$spotId.v1';
  static String indexKey(OsmPoi poi) =>
      'spot.osm.index.${poi.type}.${poi.id}.v1';

  Future<int?> existingSpotId(OsmPoi poi) async {
    final row = await (database.select(
      database.appSettings,
    )..where((s) => s.key.equals(indexKey(poi)))).getSingleOrNull();
    final id = int.tryParse(row?.value ?? '');
    if (id == null) {
      return null;
    }
    return (await spots.getSpot(id)) == null ? null : id;
  }

  Future<int> save(
    OsmPoi poi,
    DateTime retrievedAtUtc,
  ) => database.transaction(() async {
    final existing = await existingSpotId(poi);
    if (existing != null) {
      return existing;
    }

    final name = poi.name.length > 120 ? poi.name.substring(0, 120) : poi.name;
    final id = await spots.createSpot(
      name: name,
      latitude: poi.latitude,
      longitude: poi.longitude,
      notes:
          'Imported from OpenStreetMap (${poi.reference}).\n${poi.sourceUrl}\n© OpenStreetMap contributors · ODbL',
      classification: SpotClassification(category: poi.category.label),
    );
    final provenance = jsonEncode({
      'version': 1,
      'reference': poi.reference,
      'uri': poi.sourceUrl.toString(),
      'retrievedAtUtc': retrievedAtUtc.toUtc().toIso8601String(),
      'originalTags': poi.tags,
    });
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: sourceKey(id),
            value: provenance,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: indexKey(poi),
            value: '$id',
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    return id;
  });

  Future<Map<String, dynamic>?> sourceForSpot(int spotId) async {
    final row = await (database.select(
      database.appSettings,
    )..where((s) => s.key.equals(sourceKey(spotId)))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return Map<String, dynamic>.from(jsonDecode(row.value) as Map);
  }
}
