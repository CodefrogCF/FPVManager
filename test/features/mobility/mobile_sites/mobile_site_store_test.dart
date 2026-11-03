import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_models.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_store.dart';

void main() {
  test('atomic replacement, indexed viewport, and failed replacement retains old snapshot', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = SqliteMobileSiteStore(database: db);
    final area = MobileSiteArea(46.95, 7.44, 2000);
    final old = MobileSite(
      id: 'A',
      station: 'A',
      latitude: 46.95,
      longitude: 7.44,
    );
    final next = MobileSite(
      id: 'B',
      station: 'B',
      latitude: 46.9501,
      longitude: 7.4402,
    );
    final t = DateTime.utc(2026, 11, 3);
    MobileSiteSnapshot snapshot(List<MobileSite> sites) => MobileSiteSnapshot(
      area: area,
      stations: sites,
      fetchedUtc: t,
      truncated: false,
      sourceUpdatedUtc: t,
    );
    await store.replace(snapshot([old]));
    expect((await store.read(area))!.stations.map((e) => e.id), ['A']);
    final subset = await store.viewport(area, [7.439, 46.949, 7.441, 46.951]);
    expect(subset, hasLength(1));
    expect(await store.viewport(area, [7.0, 46.0, 7.01, 46.01]), isEmpty);
    expect(() => store.viewport(area, [5, 45, 11, 48]), throwsFormatException);

    // Duplicate primary keys fail during SQL staging; rollback keeps old area.
    await expectLater(
      store.replace(snapshot([next, next])),
      throwsA(isA<Exception>()),
    );
    expect((await store.read(area))!.stations.map((e) => e.id), ['A']);
    await store.replace(snapshot([next]));
    expect((await store.read(area))!.stations.map((e) => e.id), ['B']);
  });
}
