import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/mobility_preferences.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

String datex({
  bool located = true,
  String comment = 'Roadworks',
  String validity = 'active',
}) =>
    '''
<d2LogicalModel xmlns="http://datex2.eu/schema/2/2_0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><payloadPublication>
<publicationTime>2026-10-24T10:00:00Z</publicationTime><situation><situationRecord id="road-1" xsi:type="Roadworks">
<situationRecordVersionTime>2026-10-24T09:59:00Z</situationRecordVersionTime><validity><validityStatus>$validity</validityStatus>
<overallStartTime>2026-10-24T09:00:00Z</overallStartTime><overallEndTime>2026-10-24T12:00:00Z</overallEndTime></validity>
<generalPublicComment><value>$comment</value></generalPublicComment><nonGeneralPublicComment>private-note</nonGeneralPublicComment>
<groupOfLocations>${located ? '<pointCoordinates><latitude>47.3</latitude><longitude>8.5</longitude></pointCoordinates>' : '<alertCLocationTableVersion>7.3</alertCLocationTableVersion><specificLocation>10432</specificLocation>'}</groupOfLocations>
</situationRecord></situation></payloadPublication></d2LogicalModel>''';

String aircraft() => jsonEncode({
  'now': DateTime.utc(2026, 10, 24, 10).millisecondsSinceEpoch,
  'ac': [
    {
      'hex': 'abcdef',
      'flight': ' TEST123 ',
      'lat': 47.3,
      'lon': 8.5,
      'seen_pos': 2,
      'alt_baro': 10000,
      'alt_geom': 11000,
      'type': 'adsb_icao',
    },
    {
      'hex': '123456',
      'lat': 47.2,
      'lon': 8.4,
      'seen_pos': 50,
      'alt_baro': 'ground',
    },
    {'hex': '234567', 'seen_pos': 1},
  ],
});
final routeBody = jsonEncode({
  'code': 'Ok',
  'routes': [
    {
      'distance': 1234.5,
      'duration': 321,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [8.5, 47.3],
          [8.6, 47.4],
        ],
      },
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('road route validates geometry and preserves service distance/time; duplicate requests share one transfer', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    late Uri uri;
    var time = DateTime.utc(2026, 10, 24);
    final router = RoadRouter(
      client: MockClient((request) {
        requests++;
        uri = request.url;
        return response.future;
      }),
      now: () => time,
    );
    addTearDown(router.dispose);
    final a = MobilityPoint(47.3, 8.5), b = MobilityPoint(47.4, 8.6);
    final first = router.calculate(a, b), second = router.calculate(a, b);
    expect(identical(first, second), isTrue);
    response.complete(http.Response(routeBody, 200));
    final route = await first;
    expect(requests, 1);
    expect(route.distanceMeters, 1234.5);
    expect(route.durationSeconds, 321);
    expect(route.points.last.latitude, 47.4);
    expect(uri.host, 'routing.openstreetmap.de');
    expect(uri.path, contains('8.5,47.3;8.6,47.4'));
    expect(route.overlay['features'], hasLength(1));
    await expectLater(router.calculate(a, b), throwsStateError);
    time = time.add(const Duration(seconds: 2));
    await router.calculate(a, b);
    expect(requests, 2);
  });
  test(
    'invalid and unavailable road results never become a drawable route',
    () async {
      for (final body in [
        '{"code":"NoRoute"}',
        routeBody.replaceFirst('1234.5', '-1'),
        routeBody.replaceFirst('8.5,47.3', '8.5,147.3'),
      ]) {
        final router = RoadRouter(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(router.dispose);
        await expectLater(
          router.calculate(MobilityPoint(47, 8), MobilityPoint(47.1, 8.1)),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );
  test('parking/access persistence survives a repository restart and is removed atomically with the spot', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final spots = SpotRepository(db);
    final id = await spots.createSpot(name: 'Spot', latitude: 47, longitude: 8);
    await MobilityPreferences(db).saveAccess(
      id,
      SpotAccess(
        parking: MobilityPoint(47.1, 8.1),
        access: MobilityPoint(47.2, 8.2),
      ),
    );
    final restored = await MobilityPreferences(db).loadAccess(id);
    expect(restored.parking!.latitude, 47.1);
    expect(restored.access!.longitude, 8.2);
    await spots.deleteSpot(id);
    expect((await MobilityPreferences(db).loadAccess(id)).parking, isNull);
    await expectLater(
      MobilityPreferences(db).saveAccess(id, const SpotAccess()),
      throwsStateError,
    );
  });
  test('DATEX dates and explicit coordinates are normalized; TMC-only records remain unlocated and public', () {
    final data = parseTrafficSnapshot(datex());
    final f = (data['features'] as List).single as Map;
    expect(f['geometry']['coordinates'], [8.5, 47.3]);
    expect(f['validUntilUtc'], '2026-10-24T12:00:00.000Z');
    expect(f['detail'], isNot(contains('private-note')));
    expect(
      parseTrafficSnapshot(datex(validity: 'revoked'))['features'],
      isEmpty,
    );
    expect(
      parseTrafficSnapshot(datex(comment: 'Aufgehoben: Roadworks'))['features'],
      isEmpty,
    );
    expect(
      parseTrafficSnapshot(
        datex().replaceFirst(
          '</situationRecord>',
          '<management><lifeCycleManagement><cancel>true</cancel></lifeCycleManagement></management></situationRecord>',
        ),
      )['features'],
      isEmpty,
    );
    final tmc = parseTrafficSnapshot(datex(located: false));
    expect(tmc['features'], isEmpty);
    expect(tmc['unlocated'], 1);
    expect((tmc['unlocatedRecords'] as List).single['detail'], contains('7.3'));
    expect(
      (tmc['unlocatedRecords'] as List).single['detail'],
      contains('2026-10-24T12:00:00.000Z'),
    );
    expect(
      () => parseTrafficSnapshot(
        '<!DOCTYPE x SYSTEM "https://bad.example"><d2LogicalModel/>',
      ),
      throwsFormatException,
    );
    expect(
      () => parseTrafficSnapshot('<soap><Fault>unauthorized</Fault></soap>'),
      throwsFormatException,
    );
  });
  test('aircraft positions preserve source age and altitude references without inventing terrain heights', () {
    final data = parseAircraftSnapshot(aircraft());
    final features = data['features'] as List;
    expect(features, hasLength(2));
    expect(data['unlocated'], 1);
    expect(features.first['name'], 'TEST123');
    expect(features.first['timestampUtc'], '2026-10-24T09:59:58.000Z');
    expect(features.first['detail'], contains('3048 m / 10000 ft'));
    expect(features[1]['detail'], contains('ground'));
    expect(features.first['geometry']['coordinates'], [8.5, 47.3]);
    expect(
      () => parseAircraftSnapshot('{"ac":[],"now":1}'),
      throwsFormatException,
    );
  });
  test('DATEX latest versions replace positioned and unlocated records regardless of source order', () {
    String combine(String older, String newer) {
      final start = newer.indexOf('<situationRecord ');
      final end =
          newer.indexOf('</situationRecord>') + '</situationRecord>'.length;
      // Deliberately put the latest update first in the source document.
      return older.replaceFirst(
        '<situation>',
        '<situation>${newer.substring(start, end)}',
      );
    }

    final older = datex().replaceFirst('09:59:00Z', '09:58:00Z');
    final unlocated = parseTrafficSnapshot(
      combine(older, datex(located: false)),
    );
    expect(unlocated['features'], isEmpty);
    expect(unlocated['unlocated'], 1);
    final restored = parseTrafficSnapshot(
      combine(
        older.replaceFirst(
          '<pointCoordinates><latitude>47.3</latitude><longitude>8.5</longitude></pointCoordinates>',
          '<specificLocation>10432</specificLocation>',
        ),
        datex(),
      ),
    );
    expect(restored['features'], hasLength(1));
    expect(restored['unlocated'], 0);
    final revoked = parseTrafficSnapshot(
      combine(older, datex(comment: 'Aufgehoben: Roadworks')),
    );
    expect(revoked['features'], isEmpty);
    expect(revoked['unlocated'], 0);
  });
  test('registered ASTRA transport is exact-origin and header-only; failed refresh retains the last valid snapshot', () async {
    var fail = false;
    var now = DateTime.utc(2026, 10, 24, 10);
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      readTrafficKey: () async => 'secret-test-key',
      now: () => now,
      client: MockClient((request) async {
        expect(request.url.toString(), SituationalProvider.trafficUrl);
        expect(request.headers['Authorization'], 'Bearer secret-test-key');
        expect(request.body, isNot(contains('secret-test-key')));
        expect(request.followRedirects, isFalse);
        return http.Response(fail ? 'unavailable' : datex(), fail ? 503 : 200);
      }),
    );
    addTearDown(provider.dispose);
    final first = await provider.fetch();
    expect(first.persistable, isFalse);
    expect(first.publishedAtUtc, now);
    fail = true;
    now = now.add(const Duration(seconds: 6));
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(identical(provider.status.dataset, first), isTrue);
    expect(provider.status.dataState, OsintDataState.refreshFailed);
    expect(first.data.toString(), isNot(contains('secret-test-key')));
  });
  test('local snapshots stay explicitly stale and do not make provider network requests', () async {
    final provider = SituationalProvider(
      kind: SituationalKind.aircraft,
      center: MobilityPoint(47, 8),
      now: () => DateTime.utc(2026, 10, 24, 10),
      client: MockClient(
        (_) async => throw StateError('No network for import'),
      ),
    );
    addTearDown(provider.dispose);
    final snapshot = await provider.importText(aircraft());
    expect(snapshot.requiresRevalidation, isTrue);
    expect(provider.status.dataState, OsintDataState.stale);
    expect(snapshot.data['transport'], contains('Imported'));
    await expectLater(
      provider.importText('{"invalid":true}'),
      throwsA(isA<OsintProviderException>()),
    );
    expect(identical(provider.cached, snapshot), isTrue);
  });
  test('manual source refresh is rate limited without another HTTP request and recovers', () async {
    var requests = 0;
    var now = DateTime.utc(2026, 10, 24, 10);
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      readTrafficKey: () async => 'test-key',
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return http.Response(datex(), 200);
      }),
    );
    addTearDown(provider.dispose);
    await provider.fetch(forceRefresh: true);
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(requests, 1);
    now = now.add(const Duration(seconds: 5));
    await provider.fetch(forceRefresh: true);
    expect(requests, 2);
    expect(provider.status.dataState, OsintDataState.fresh);
  });
  test('independent overlays replay after a renderer reload; selection remains bounded', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await globe.showSituationalOverlay({
      'id': 'wildfire',
      'visible': true,
      'opacity': .4,
    });
    await globe.showSituationalOverlay({
      'id': 'heliports',
      'visible': true,
      'opacity': .7,
    });
    peer.emit({
      'type': 'situational-selected',
      'name': 'Aircraft',
      'detail': 'Source age and height reference',
    });
    expect(globe.situationalSelection!.name, 'Aircraft');
    peer.emit({
      'type': 'simulation-state',
      'active': true,
      'pending': false,
      'cameraTiltDegrees': 35,
    });
    expect(globe.simulationCameraTiltDegrees, 35);
    peer.sessionId = 'renderer-2';
    peer.sequence = 0;
    peer.ready();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final overlays = peer.commands.where(
      (c) => c['type'] == 'set-situational-overlay',
    );
    expect(
      overlays.where((c) => c['id'] == 'wildfire').length,
      greaterThanOrEqualTo(2),
    );
    await globe.showSituationalOverlay({'id': 'wildfire', 'visible': false});
    expect(globe.situationalVisible('wildfire'), isFalse);
    expect(globe.situationalVisible('heliports'), isTrue);
  });
}
