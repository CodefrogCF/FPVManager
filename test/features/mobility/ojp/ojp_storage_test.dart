import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/mobility/mobility_preferences.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_models.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_parser.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

import 'ojp_parser_test.dart' show ojpFixture;

void main() {
  test('saved snapshots retain retrieval time and no credentials', () async {
    final database = FpvDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = MobilityPreferences(database);
    final queriedAt = DateTime.utc(2026, 11, 3, 12);
    final item = OjpJourneySnapshot(
      query: OjpTripQuery(
        origin: MobilityPoint(46.95, 7.45),
        destination: MobilityPoint(47.35, 8.52),
        timeUtc: queriedAt,
        mode: OjpTimeMode.arrival,
      ),
      originName: 'Bern',
      destinationName: 'Zürich',
      fetchedAtUtc: queriedAt,
      journeys: const OjpTripParser().parse(ojpFixture),
    );
    await preferences.saveOjpSnapshot(item);
    final restored = await preferences.loadOjpSnapshots();
    expect(restored, hasLength(1));
    expect(restored.single.fetchedAtUtc, queriedAt);
    expect(restored.single.query.mode, OjpTimeMode.arrival);
    expect(
      restored.single.journeys.single.legs[1].departure.hasRealtimeChange,
      true,
    );
    expect(backupSetting('mobility.ojp.snapshots.v1'), true);
    expect(backupSetting('fpvmanager.api.key.ojp20'), false);
  });
}
