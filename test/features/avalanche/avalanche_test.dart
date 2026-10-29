import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/core/osint/osint_dataset_store.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/avalanche/avalanche_bulletin.dart';
import 'package:fpvmanager/features/avalanche/avalanche_layers_section.dart';
import 'package:fpvmanager/features/avalanche/avalanche_map_controller.dart';
import 'package:fpvmanager/features/avalanche/avalanche_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

final instant = DateTime.utc(2026, 10, 29, 12);
http.Response response(Object data, {Map<String, String> headers = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), 200, headers: headers);
Map<String, dynamic> bulletin() => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [8, 47],
            [8.2, 47],
            [8.2, 47.2],
            [8, 47.2],
            [8, 47],
          ],
          [
            [8.05, 47.05],
            [8.05, 47.1],
            [8.1, 47.1],
            [8.1, 47.05],
            [8.05, 47.05],
          ],
        ],
      },
      'properties': {
        'bulletinID': 'synthetic-warning',
        'publicationTime': '2026-10-29T10:00:00Z',
        'validTime': {
          'startTime': '2026-10-29T11:00:00Z',
          'endTime': '2026-10-30T10:00:00Z',
        },
        'regions': [
          {'regionID': 'CH-test', 'name': 'Testregion'},
        ],
        'dangerRatings': [
          {'mainValue': 'moderate', 'validTimePeriod': 'earlier'},
          {
            'mainValue': 'considerable',
            'validTimePeriod': 'later',
            'customData': {
              'CH': {'subdivision': 'plus'},
            },
          },
        ],
        'avalancheProblems': [
          {
            'problemType': 'wind_slab',
            'dangerRatingValue': 'considerable',
            'validTimePeriod': 'all_day',
            'elevation': {'lowerBound': '2400'},
            'aspects': ['N', 'NE'],
            'comment': 'Erste Zeile<br/>Zweite &amp; dritte',
            'customData': {
              'CH': {'coreZoneText': 'Steile Nordhänge'},
            },
          },
        ],
        'snowpackStructure': {'comment': '<p>Schneedecke</p>'},
      },
    },
  ],
};
Map<String, dynamic> properties(Map<String, dynamic> b) =>
    b['features'][0]['properties'];

void main() {
  test('immediate manual refresh reuses data without changing freshness, timestamps or failure state', () async {
    var now = instant, calls = 0;
    final provider = AvalancheProvider(
      now: () => now,
      client: MockClient((_) async {
        calls++;
        return response(bulletin());
      }),
    );
    final first = provider.fetch(),
        coalesced = provider.fetch(forceRefresh: true);
    expect(coalesced, same(first));
    final dataset = await first;
    expect(provider.retryAfterSeconds, 30);
    expect(await provider.fetch(forceRefresh: true), same(dataset));
    expect(provider.status.error, isNull);
    expect(provider.status.dataState, OsintDataState.fresh);
    expect(provider.cached!.lastCheckedAtUtc, instant);
    expect(calls, 1);
    now = now.add(const Duration(seconds: 29));
    expect(provider.retryAfterSeconds, 1);
    expect(await provider.fetch(forceRefresh: true), same(dataset));
    now = now.add(const Duration(seconds: 1));
    await provider.fetch(forceRefresh: true);
    expect(calls, 2);
    expect(provider.status.error, isNull);
    provider.dispose();
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
  });
  test('retry cooldown after a real failure does not create a source validation failure', () async {
    var now = instant, calls = 0;
    final provider = AvalancheProvider(
      now: () => now,
      client: MockClient((_) async {
        calls++;
        return http.Response('', 503);
      }),
    );
    addTearDown(provider.dispose);
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    final error = provider.status.error;
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<AvalancheRefreshCooldown>()),
    );
    expect(provider.status.error, same(error));
    expect(calls, 1);
    now = now.add(const Duration(seconds: 30));
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(calls, 2);
  });
  testWidgets(
    'enabling SLF then refreshing immediately shows a countdown and recovers without automatic polling',
    (tester) async {
      var now = instant, calls = 0;
      final globe = GlobeController(
        avalancheProvider: AvalancheProvider(
          now: () => now,
          client: MockClient((_) async {
            calls++;
            return response(bulletin());
          }),
        ),
      );
      await globe.avalanche.options(enabled: true);
      await globe.avalanche.refresh();
      expect(calls, 1);
      expect(globe.avalanche.error, isNull);
      expect(globe.avalanche.status.error, isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AvalancheLayersSection(globe: globe),
            ),
          ),
        ),
      );
      expect(find.text('Erneut aktualisieren in 30 s'), findsOneWidget);
      final disabled = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Erneut aktualisieren in 30 s'),
      );
      expect(disabled.onPressed, isNull);
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      final enabled = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'SLF-Bulletin aktualisieren'),
      );
      expect(enabled.onPressed, isNotNull);
      expect(calls, 1);
      await tester.tap(find.text('SLF-Bulletin aktualisieren'));
      await tester.pump();
      expect(calls, 2);
      expect(globe.avalanche.error, isNull);
      expect(globe.avalanche.status.error, isNull);
      await tester.pumpWidget(const SizedBox());
      globe.dispose();
    },
  );
  test('SLF semantics retain holes, periods, height bands, aspects and descriptions', () {
    final data = parseAvalancheBulletin(jsonEncode(bulletin()));
    final all = avalancheFeatures(data, stale: false, period: 'all').single;
    expect(all['level'], 3);
    expect(all['geometry']['coordinates'], hasLength(2));
    expect(all['detail'], contains('2400 m'));
    expect(all['detail'], contains('N, NE'));
    expect(all['detail'], contains('Erste Zeile\nZweite & dritte'));
    expect(all['detail'], contains('(3+)'));
    expect(all['detail'], contains('Steile Nordhänge'));
    expect(all['detail'], isNot(contains('<p>')));
    expect(
      avalancheFeatures(data, stale: false, period: 'earlier').single['level'],
      2,
    );
    expect(
      avalancheFeatures(data, stale: false, period: 'later').single['level'],
      3,
    );
    expect(
      avalancheFeatures(data, stale: true, period: 'all').single['level'],
      0,
    );
  });

  test('empty is no active bulletin; unknown ratings and periods never become low danger', () {
    final empty = parseAvalancheBulletin(
      '{"type":"FeatureCollection","features":[]}',
    );
    expect(empty['empty'], true);
    expect(avalancheFeatures(empty, stale: false, period: 'all'), isEmpty);
    for (final rating in [
      {'mainValue': 'future_enum', 'validTimePeriod': 'all_day'},
      {'mainValue': 'high', 'validTimePeriod': 'future_period'},
      <String, dynamic>{},
    ]) {
      final b = bulletin();
      properties(b)['dangerRatings'] = [rating];
      final feature = avalancheFeatures(
        parseAvalancheBulletin(jsonEncode(b)),
        stale: false,
        period: 'earlier',
      ).single;
      expect(feature['level'], 0);
      expect(
        (feature['detail'] as String).toLowerCase(),
        contains('unbekannt'),
      );
    }
  });

  test('malformed areas reject the complete replacement; multipart geometry survives', () {
    final b = bulletin(), geometry = bulletin()['features'][0]['geometry'];
    b['features'][0]['geometry'] = {
      'type': 'MultiPolygon',
      'coordinates': [geometry['coordinates'], geometry['coordinates']],
    };
    expect(
      parseAvalancheBulletin(
        jsonEncode(b),
      )['areas'][0]['geometry']['coordinates'],
      hasLength(2),
    );
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (b) => b['features'].add(b['features'][0]),
      (b) => properties(b)['validTime']['endTime'] = '2026-10-29T11:00:00Z',
      (b) => properties(b)['publicationTime'] = '2026-10-29T10:00:00',
      (b) => b['features'][0]['geometry']['coordinates'][0][0] = [180, 47],
      (b) => b['features'][0]['geometry']['coordinates'][0].removeLast(),
    ]) {
      final b = bulletin();
      mutate(b);
      expect(
        () => parseAvalancheBulletin(jsonEncode(b)),
        throwsFormatException,
      );
    }
  });

  test('conditional refresh preserves publication and retrieval times; failed updates retain data', () async {
    var now = instant, requestCount = 0;
    final provider = AvalancheProvider(
      now: () => now,
      client: MockClient((r) async {
        expect(
          r.url.toString(),
          AvalancheProvider.defaultSource.dataUri.toString(),
        );
        expect(r.url.query, isEmpty);
        requestCount++;
        if (requestCount == 1) {
          return response(bulletin(), headers: {'etag': '"test"'});
        }
        expect(r.headers['If-None-Match'], '"test"');
        return http.Response('', requestCount == 2 ? 304 : 503);
      }),
    );
    addTearDown(provider.dispose);
    final original = await provider.fetch();
    expect(original.publishedAtUtc, DateTime.utc(2026, 10, 29, 10));
    now = now.add(const Duration(minutes: 31));
    final checked = await provider.fetch(forceRefresh: true);
    expect(checked.fetchedAtUtc, original.fetchedAtUtc);
    expect(checked.lastCheckedAtUtc, now);
    expect(checked.data, same(original.data));
    now = now.add(const Duration(minutes: 1));
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(provider.cached, same(checked));
    expect(provider.status.dataState, OsintDataState.refreshFailed);
  });

  test(
    'HTTP age bounds cache lifetime and 304 retains a no-store policy',
    () async {
      for (final policy in ['public, max-age=120', 'no-store']) {
        var now = instant, calls = 0;
        final source = AvalancheProvider(
          now: () => now,
          client: MockClient((_) async {
            if (++calls == 1) {
              return response(
                bulletin(),
                headers: {'cache-control': policy, 'age': '60', 'etag': '"v"'},
              );
            }
            return http.Response('', 304);
          }),
        );
        final original = await source.fetch();
        expect(
          original.cacheExpiresAtUtc,
          now.add(Duration(seconds: policy == 'no-store' ? 0 : 60)),
        );
        now = now.add(const Duration(seconds: 31));
        final updated = await source.fetch(forceRefresh: true);
        expect(updated.persistable, policy != 'no-store');
        expect(updated.requiresRevalidation, policy == 'no-store');
        expect(
          updated.cacheExpiresAtUtc,
          now.add(Duration(seconds: policy == 'no-store' ? 0 : 60)),
        );
        source.dispose();
      }
    },
  );

  test('persistent restart retains source validity; no-store removes a previous disk snapshot', () async {
    var now = instant, noStore = false;
    final database = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = JsonOsintDatasetStore(
      database: () => database,
      storageTerms: AvalancheProvider.defaultSource.licenseUri!,
    );
    AvalancheProvider create() => AvalancheProvider(
      now: () => now,
      persistentCache: store,
      client: MockClient(
        (_) async => response(
          bulletin(),
          headers: {'cache-control': noStore ? 'no-store' : 'public'},
        ),
      ),
    );
    final first = create();
    await first.fetch();
    first.dispose();
    await first.settled;
    now = now.add(const Duration(minutes: 40));
    final restarted = create();
    addTearDown(restarted.dispose);
    await restarted.loadCached();
    expect(restarted.cached, isNotNull);
    expect(restarted.status.dataState, OsintDataState.stale);
    expect(restarted.cached!.publishedAtUtc, DateTime.utc(2026, 10, 29, 10));
    noStore = true;
    await restarted.fetch(forceRefresh: true);
    expect(restarted.cached!.persistable, false);
    expect(await store.read(AvalancheProvider.defaultSource, now), isNull);
  });

  test('map state persists options, handles expired and empty publications, and retires late updates', () async {
    var now = instant, empty = false, requests = 0;
    var preferences = const UserPreferences();
    final commands = <Map<String, dynamic>>[];
    final provider = AvalancheProvider(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return response(
          empty ? {'type': 'FeatureCollection', 'features': []} : bulletin(),
        );
      }),
    );
    final layer = AvalancheMapController(
      provider: provider,
      now: () => now,
      send: (c) async => commands.add(c),
      preferences: () => preferences,
      savePreferences: (p) async => preferences = p,
    );
    await layer.options(enabled: true, alpha: .6, selectedPeriod: 'earlier');
    expect(requests, 1);
    expect(preferences.avalancheVisible, true);
    expect(preferences.avalancheOpacity, .6);
    expect(commands.last['features'][0]['level'], 2);
    now = DateTime.utc(2026, 10, 30, 11);
    expect(layer.dataState, OsintDataState.expired);
    expect(layer.command()['features'][0]['level'], 0);
    expect(layer.message, contains('abgelaufen'));
    empty = true;
    await layer.refresh();
    expect(layer.message, contains('Kein aktives Bulletin'));
    expect(layer.command()['features'], isEmpty);
    layer.dispose();
    await provider.settled;

    final gate = Completer<http.Response>();
    final late = AvalancheProvider(
      now: () => instant,
      client: MockClient((_) => gate.future),
    );
    final lateLayer = AvalancheMapController(
      provider: late,
      send: (c) async => commands.add(c),
      preferences: () => preferences,
      savePreferences: (_) async {},
    );
    final pending = lateLayer.refresh();
    await Future<void>.delayed(Duration.zero);
    lateLayer.dispose();
    final count = commands.length;
    gate.complete(response(bulletin()));
    await pending;
    await late.settled;
    expect(commands, hasLength(count));
  });

  test('renderer reload and map style changes restore live freshness and full selection', () async {
    final globe = GlobeController(
      avalancheProvider: AvalancheProvider(
        now: () => instant,
        client: MockClient((_) async => response(bulletin())),
      ),
    );
    addTearDown(globe.dispose);
    final commands = <Map<String, dynamic>>[],
        renderer = FakeGlobeRenderer(globe, commands: commands);
    renderer.attach();
    renderer.ready();
    await Future<void>.delayed(Duration.zero);
    await globe.avalanche.options(enabled: true, alpha: .5);
    expect(commands.lastWhere((c) => c['id'] == 'avalanche')['opacity'], .5);
    await globe.setMapStyle(GlobeMapStyle.relief);
    renderer.sessionId = 'renderer-2';
    renderer.sequence = 0;
    renderer.ready();
    await Future<void>.delayed(Duration.zero);
    final restored = commands.lastWhere((c) => c['id'] == 'avalanche');
    expect(restored['visible'], true);
    expect(restored['features'], hasLength(1));
    final detail = 'Full SLF text ${'x'.padLeft(2000, 'x')}';
    renderer.emit({
      'type': 'situational-selected',
      'id': 'avalanche',
      'name': 'Warning',
      'detail': detail,
    });
    expect(globe.situationalSelection!.detail, detail);
    await globe.avalanche.options(enabled: false);
    expect(commands.lastWhere((c) => c['id'] == 'avalanche')['visible'], false);
  });

  testWidgets(
    'compact controls remain scrollable at phone and landscape widths',
    (tester) async {
      final globe = GlobeController(
        avalancheProvider: AvalancheProvider(
          now: () => instant,
          client: MockClient((_) async => response(bulletin())),
        ),
      );
      await globe.avalanche.restore(true, .4);
      await globe.avalanche.refresh();
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AvalancheLayersSection(globe: globe),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Lawinenbulletin · SLF'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      globe.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
