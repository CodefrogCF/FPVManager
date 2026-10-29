import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/core/osint/osint_dataset_store.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';
import 'package:fpvmanager/features/mobility/tmc_repository.dart';

import '../../helpers/tmc_fixture.dart';
import '../../helpers/route_traffic_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  JsonOsintDatasetStore storage(OsintCacheDatabase db) => JsonOsintDatasetStore(
    database: () => db,
    storageTerms: Uri.parse('https://opentransportdata.swiss/de/tac-fedro/'),
    retention: const Duration(days: 3650),
  );
  test('official public redirect sends no token or coordinates; parsed reference survives file-backed restart independently of live data', () async {
    final dir = await Directory.systemTemp.createTemp('fpvmanager-tmc-');
    addTearDown(() async {
      expect(
        dir.absolute.path.startsWith(Directory.systemTemp.absolute.path),
        true,
      );
      await dir.delete(recursive: true);
    });
    final db = OsintCacheDatabase(
      NativeDatabase(File('${dir.path}/cache.sqlite')),
    );
    var dbClosed = false;
    addTearDown(() async {
      if (!dbClosed) await db.close();
    });
    final requests = <Uri>[];
    final client = MockClient((r) async {
      requests.add(r.url);
      expect(r.followRedirects, false);
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      return requests.length == 1
          ? http.Response(
              '',
              302,
              headers: {
                'location': 'https://83025b28472d6aa2bf5ae59f3724aa78.eu.r2.cloudflarestorage.com/dx-omd-prod/resources/fixture/tmc.zip',
              },
            )
          : http.Response.bytes(tmcZip(), 200);
    });
    final first = TmcRepository(
      storage: storage(db),
      client: client,
      now: () => trafficTime,
    );
    await first.download('7.5');
    expect(requests, hasLength(2));
    expect(requests.first, tmcDownloadUri('7.5'));
    expect(first.snapshots['7.5']!.imported, false);
    final hash = first.snapshots['7.5']!.table.sha256sum;
    first.dispose();
    await db.close();
    dbClosed = true;
    final reopened = OsintCacheDatabase(
      NativeDatabase(File('${dir.path}/cache.sqlite')),
    );
    var reopenedClosed = false;
    addTearDown(() async {
      if (!reopenedClosed) await reopened.close();
    });
    final second = TmcRepository(
      storage: storage(reopened),
      client: MockClient((_) async => throw StateError('offline')),
      now: () => trafficTime.add(const Duration(days: 30)),
    );
    await second.restore(['7.5']);
    expect(second.snapshots['7.5']!.table.sha256sum, hash);
    expect(second.snapshots['7.5']!.retrievedUtc, trafficTime);
    expect(second.snapshots['7.5']!.table.nodes[1]!.name, 'Zürich');
    second.dispose();
    await reopened.close();
    reopenedClosed = true;
    client.close();
  });
  test('failed, corrupted and wrong-version replacements retain both prior memory and atomic cache snapshot', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var mode = 'valid';
    final repo = TmcRepository(
      storage: storage(db),
      now: () => trafficTime,
      client: MockClient(
        (_) async => switch (mode) {
          'valid' => http.Response.bytes(tmcZip(), 200),
          'wrong' => http.Response.bytes(tmcZip(version: '7.3'), 200),
          'corrupt' => http.Response('not a zip', 200),
          _ => http.Response('', 503),
        },
      ),
    );
    addTearDown(repo.dispose);
    await repo.download('7.5');
    final previous = repo.snapshots['7.5'];
    for (final m in ['wrong', 'corrupt', 'failed']) {
      mode = m;
      await expectLater(repo.download('7.5'), throwsException);
      expect(repo.snapshots['7.5'], same(previous));
      expect(repo.error, isNotNull);
      final saved = (await storage(db).read(tmcSource('7.5'), trafficTime))!;
      expect(saved.data['sha256'], previous!.table.sha256sum);
    }
    mode = 'valid';
    await repo.download('7.5');
    expect(repo.error, isNull);
  });
  test('unrecognized redirect targets and unsupported versions are explicit and never receive another request', () async {
    for (final target in [
      'https://unrelated.example/file',
      'http://data.opentransportdata.swiss/file',
      'https://data.opentransportdata.swiss:444/file',
    ]) {
      var requests = 0;
      final repo = TmcRepository(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 302, headers: {'location': target});
        }),
      );
      await expectLater(repo.download('7.5'), throwsFormatException);
      expect(requests, 1);
      await expectLater(repo.download('7.6'), throwsFormatException);
      expect(requests, 1);
      repo.dispose();
    }
  });
  test('manual imports retain unverified provenance across cache reopening and deletion', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TmcRepository(storage: storage(db), now: () => trafficTime);
    addTearDown(repo.dispose);
    await repo.importZip(tmcZip(), version: '7.5');
    expect(repo.snapshots['7.5']!.imported, true);
    final reopened = TmcRepository(
      storage: storage(db),
      now: () => trafficTime,
    );
    addTearDown(reopened.dispose);
    await reopened.restore(['7.5']);
    expect(reopened.snapshots['7.5']!.imported, true);
    await reopened.remove('7.5');
    expect(reopened.snapshots, isEmpty);
    expect(await storage(db).read(tmcSource('7.5'), trafficTime), isNull);
  });
  test('concurrent download is rejected and clear drains a late response without repopulating the cache', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final reply = Completer<http.Response>();
    var requests = 0;
    final repo = TmcRepository(
      storage: storage(db),
      client: MockClient((_) {
        requests++;
        return reply.future;
      }),
    );
    addTearDown(repo.dispose);
    final download = repo.download('7.5');
    final rejected = expectLater(download, throwsException);
    await expectLater(repo.download('7.4'), throwsStateError);
    final clear = repo.remove('7.5');
    reply.complete(http.Response.bytes(tmcZip(), 200));
    await rejected;
    await clear;
    expect(requests, 1);
    expect(repo.snapshots, isEmpty);
    expect(await storage(db).read(tmcSource('7.5'), trafficTime), isNull);
  });
  test('late table availability resolves existing traffic without another live request or changing its publication/retrieval time; failures retain warnings', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = trafficTime, fail = false, requests = 0;
    final repo = TmcRepository(
      storage: storage(db),
      now: () => now,
      client: MockClient((_) async => http.Response.bytes(tmcZip(), 200)),
    );
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      tmc: repo,
      readTrafficKey: () async => 'fixture',
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return fail ? http.Response('', 503) : http.Response(tmcXml(), 200);
      }),
    );
    addTearDown(() {
      provider.dispose();
      repo.dispose();
    });
    await repo.restore(['7.5']);
    final source = await provider.fetch();
    await provider.tmcSettled;
    expect(provider.status.dataset!.data['unlocated'], 1);
    await repo.download('7.5');
    await provider.tmcSettled;
    expect(provider.status.dataset!.data['tmcResolved'], 1);
    expect(provider.status.dataset!.data['unlocated'], 0);
    expect(provider.status.dataset!.fetchedAtUtc, source.fetchedAtUtc);
    expect(provider.status.dataset!.publishedAtUtc, source.publishedAtUtc);
    expect(provider.status.dataset!.persistable, false);
    expect(requests, 1);
    now = now.add(const Duration(minutes: 1));
    fail = true;
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(provider.status.dataState, OsintDataState.refreshFailed);
    expect(provider.status.dataset!.data['tmcResolved'], 1);
    await repo.remove('7.5');
    await provider.tmcSettled;
    expect(provider.status.dataset!.data['unlocated'], 1);
  });
  test('a newer traffic snapshot supersedes pending TMC resolution instead of inheriting the previous version', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TmcRepository(
      storage: storage(db),
      now: () => trafficTime,
      client: MockClient((_) async => http.Response.bytes(tmcZip(), 200)),
    );
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      tmc: repo,
      now: () => trafficTime,
      readTrafficKey: () async => 'fixture',
      client: MockClient((_) async => http.Response(tmcXml(), 200)),
    );
    addTearDown(() {
      provider.dispose();
      repo.dispose();
    });
    await repo.download('7.5');
    await provider.fetch();
    await provider.importText(tmcXml(version: '7.3'));
    await repo.restore(['7.3']);
    await provider.tmcSettled;
    final data = provider.status.dataset!.data;
    expect(data['records'].single['tmcVersion'], '7.3');
    expect(data['tmcResolved'], 0);
    expect(data['unlocated'], 1);
    expect(provider.status.dataset!.requiresRevalidation, true);
  });
}
