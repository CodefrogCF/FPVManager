import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_models.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_service.dart';

void main() {
  test(
    'separate OSINT DB saves and reads dated, attributed POI snapshots',
    () async {
      final database = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final cache = PersistentOsmPoiCache(database: database);
      final search = OsmPoiSearch(
        latitude: 47.4,
        longitude: 8.5,
        radiusMeters: 250,
        categories: {OsmPoiCategory.toilets},
      );
      final poi = OsmPoi(
        type: 'way',
        id: 123,
        latitude: 47.401,
        longitude: 8.502,
        category: OsmPoiCategory.toilets,
        tags: {'amenity': 'toilets', 'wheelchair': 'limited'},
      );
      final retrieved = DateTime.now().toUtc().subtract(
        const Duration(hours: 27),
      );
      await cache.write(
        OsmPoiSnapshot(
          search: search,
          fetchedAtUtc: retrieved,
          pois: [poi],
          truncated: false,
        ),
      );
      final stored = await cache.read(search);
      expect(stored, isNotNull);
      expect(stored!.fromCache, true);
      expect(stored.isOutdated(DateTime.now()), true);
      expect(stored.pois.single.reference, 'way/123');
      expect(stored.pois.single.suppliedDetails['wheelchair'], 'limited');
      await database.customStatement(
        "UPDATE osint_snapshots SET envelope='corrupt' WHERE provider LIKE 'osm-nearby-%'",
      );
      expect(await cache.read(search), null);
    },
  );
}
