import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_models.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_saved_spots.dart';

void main() {
  test('saving same OSM feature twice preserves personal edits and source metadata', () async {
    final database = FpvDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSpotRepository(database);
    final saved = OsmPoiSavedSpots(database, repository);
    final poi = OsmPoi(
      type: 'node',
      id: 482,
      latitude: 47.1,
      longitude: 8.4,
      category: OsmPoiCategory.drinkingWater,
      tags: {'amenity': 'drinking_water', 'name': 'Original', 'access': 'yes'},
    );
    final time = DateTime.utc(2026, 11, 3, 12);
    final first = await saved.save(poi, time);
    expect(await saved.save(poi, time), first);
    expect((await repository.getAllSpots()).length, 1);
    final source = await saved.sourceForSpot(first);
    expect(source!['reference'], 'node/482');
    expect(source['originalTags']['access'], 'yes');
    expect(source['retrievedAtUtc'], time.toIso8601String());
    expect(backupSetting(OsmPoiSavedSpots.sourceKey(first)), true);
    expect(backupSetting(OsmPoiSavedSpots.indexKey(poi)), true);
    final changed = await repository.updateSpot(
      id: first,
      name: 'My water point',
      latitude: 47.1001,
      longitude: 8.4001,
      notes: 'My own field notes',
    );
    expect(changed, true);
    expect(await saved.save(poi, DateTime.utc(2026, 11, 6)), first);
    final edited = await repository.getSpot(first);
    expect(edited!.name, 'My water point');
    expect(edited.latitude, 47.1001);
    expect(edited.notes, 'My own field notes');
    expect((await saved.sourceForSpot(first))!['reference'], 'node/482');
    expect(
      (await saved.sourceForSpot(first))!['retrievedAtUtc'],
      time.toIso8601String(),
    );
    await repository.deleteSpot(first);
    expect(await saved.sourceForSpot(first), null);
    expect(await saved.existingSpotId(poi), null);
    expect(backupSetting('spot.osm.not-trusted-key'), false);
  });
}
