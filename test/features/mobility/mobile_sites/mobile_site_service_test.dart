import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_models.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_service.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_store.dart';

class TestSiteStore implements MobileSiteStore {
  MobileSiteSnapshot? snapshot;
  bool failReplace = false;
  @override
  Future<MobileSiteSnapshot?> read(MobileSiteArea area) async =>
      snapshot?.area.key == area.key ? snapshot!.cached() : null;
  @override
  Future<void> replace(MobileSiteSnapshot value) async {
    if (failReplace) throw StateError('fixture failed replacement');
    snapshot = value;
  }

  @override
  Future<List<MobileSite>> viewport(
    MobileSiteArea area,
    List<double> bounds, {
    int limit = 180,
  }) async => snapshot?.stations.take(limit).toList() ?? [];
}

String payload(List<String> ids) => jsonEncode({
  'results': [
    for (final id in ids)
      {
        'featureId': id,
        'attributes': {'station': 'Station $id', 'koord': '2600000,1200000'},
      },
  ],
});

void main() {
  final area = MobileSiteArea(46.95, 7.44, 2000);
  test(
    'refresh replaces disappearing stations and keeps explicit source age',
    () async {
      var at = DateTime.utc(2026, 11, 3, 12);
      var ids = ['first', 'second'];
      final httpClient = MockClient(
        (_) async => http.Response(payload(ids), 200),
      );
      final store = TestSiteStore();
      final service = MobileSitesService(
        store: store,
        transport: MobilityHttp(client: httpClient),
        budget: MobileSitesBudget(clock: () => at),
        clock: () => at,
      );
      addTearDown(() async {
        await service.dispose();
        httpClient.close();
      });
      expect((await service.search(area)).stations, hasLength(2));
      at = at.add(const Duration(minutes: 1));
      ids = ['second'];
      final updated = await service.search(area, refresh: true);
      expect(updated.stations.map((s) => s.id), ['second']);
      expect((await service.offline(area))!.stations, hasLength(1));
      expect(
        updated.sourceUpdatedUtc,
        isNull,
      ); // metadata not fetched = unknown
    },
  );

  test(
    'HTTP failure and timeout keep dated old snapshot, not fake new coverage',
    () async {
      var at = DateTime.utc(2026, 11, 3, 12);
      final store = TestSiteStore();
      var fail = false;
      final client = MockClient(
        (_) async => fail
            ? http.Response('busy', 429)
            : http.Response(payload(['old']), 200),
      );
      final service = MobileSitesService(
        store: store,
        transport: MobilityHttp(client: client),
        budget: MobileSitesBudget(clock: () => at),
        clock: () => at,
      );
      addTearDown(() async {
        await service.dispose();
        client.close();
      });
      await service.search(area);
      final original = store.snapshot;
      fail = true;
      at = at.add(const Duration(days: 2));
      final outdated = await service.search(area, refresh: true);
      expect(outdated.refreshFailed, true);
      expect(outdated.fromCache, true);
      expect(outdated.isOld(at), true);
      expect(outdated.stations.single.id, 'old');
      expect(identical(original, store.snapshot), true);
    },
  );

  test(
    'failed persistence publication never changes previous snapshot',
    () async {
      var at = DateTime.utc(2026, 11, 3, 12);
      var ids = ['A'];
      final store = TestSiteStore();
      final client = MockClient((_) async => http.Response(payload(ids), 200));
      final service = MobileSitesService(
        store: store,
        transport: MobilityHttp(client: client),
        budget: MobileSitesBudget(clock: () => at),
        clock: () => at,
      );
      addTearDown(() async {
        await service.dispose();
        client.close();
      });
      await service.search(area);
      store.failReplace = true;
      ids = ['B'];
      at = at.add(const Duration(minutes: 1));
      final saved = await service.search(area, refresh: true);
      expect(saved.refreshFailed, true);
      expect(saved.stations.single.id, 'A');
      expect(store.snapshot!.stations.single.id, 'A');
    },
  );

  test(
    'parallel same-area requests coalesce and no second unhandled error',
    () async {
      final pending = Completer<http.Response>();
      var count = 0;
      final client = MockClient((_) {
        count++;
        return pending.future;
      });
      final service = MobileSitesService(
        store: TestSiteStore(),
        transport: MobilityHttp(client: client),
        budget: MobileSitesBudget(clock: () => DateTime.utc(2026, 11, 3)),
        clock: () => DateTime.utc(2026, 11, 3),
      );
      addTearDown(() async {
        await service.dispose();
        client.close();
      });
      final a = service.search(area), b = service.search(area);
      expect(identical(a, b), true);
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
      pending.complete(http.Response(payload(['one']), 200));
      expect((await a).stations.single.id, 'one');
    },
  );
}
