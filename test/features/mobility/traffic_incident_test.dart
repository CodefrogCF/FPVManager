import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';
import 'package:fpvmanager/features/mobility/traffic_snapshot.dart'
    show readTrafficSnapshot;
import 'package:fpvmanager/features/mobility/traffic_incident.dart';

String trafficGroup({
  String id = 'event-1',
  String time = '2026-10-25T10:00:00Z',
  bool revoked = false,
  bool extra = true,
  bool located = true,
}) =>
    '''
<d2LogicalModel xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><payloadPublication>
<publicationTime>$time</publicationTime><situation id="$id">
<situationRecord id="$id-main" xsi:type="AbnormalTraffic"><situationRecordVersionTime>$time</situationRecordVersionTime>
<validity><overallStartTime>2026-10-25T09:00:00Z</overallStartTime></validity>
<generalPublicComment><comment><values>
<value lang="fr-CH">Texte français</value><value lang="de-CH">${revoked ? 'Aufgehoben: ' : ''}A1 Zürich Richtung Bern, stockender Verkehr</value>
</values></comment></generalPublicComment><nonGeneralPublicComment><value>private-no-export</value></nonGeneralPublicComment>
<abnormalTrafficType>queuingTraffic</abnormalTrafficType><queueLength>2500</queueLength>
<groupOfLocations>${located ? '<pointCoordinates><latitude>broken</latitude></pointCoordinates><pointCoordinates><latitude>47.3</latitude><longitude>8.5</longitude></pointCoordinates>' : '<alertCLocationTableVersion>7.3</alertCLocationTableVersion><specificLocation>10432</specificLocation>'}</groupOfLocations>
</situationRecord>${extra ? '<situationRecord id="$id-lanes" xsi:type="RoadOrCarriagewayOrLaneManagement"><situationRecordVersionTime>$time</situationRecordVersionTime><numberOfLanesRestricted>1</numberOfLanesRestricted><delayTimeValue>600</delayTimeValue></situationRecord>' : ''}
</situation></payloadPublication></d2LogicalModel>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('official multi-part structure becomes one public German event with supported metrics; bad coordinates do not discard later valid positions', () {
    final data = parseTrafficSnapshot(trafficGroup());
    expect(data['records'], hasLength(1));
    final r = data['features'].single as Map<String, dynamic>;
    expect(r['id'], 'event-1');
    expect(r['parts'], 2);
    expect(r['category'], 'congestion');
    expect(r['metrics']['queueLength'], 2500);
    expect(r['metrics']['delayTimeValue'], 600);
    expect(r['geometry']['coordinates'], [8.5, 47.3]);
    expect(r['description'], contains('A1 Zürich'));
    expect(r.toString(), isNot(contains('Texte français')));
    expect(r.toString(), isNot(contains('private-no-export')));
    final tmc = parseTrafficSnapshot(trafficGroup(located: false));
    expect(tmc['unlocated'], 1);
    expect(
      tmc['unlocatedRecords'].single['description'],
      contains('A1 Zürich'),
    );
    expect(
      parseTrafficSnapshot(trafficGroup(revoked: true))['records'],
      isEmpty,
    );
  });
  test('changes replace the complete situation, drop obsolete parts and withdraw the whole event; older overlap cannot revive it', () {
    final initial = readTrafficSnapshot(trafficGroup());
    final updated = initial.merge(
      readTrafficSnapshot(
        trafficGroup(time: '2026-10-25T10:01:00Z', extra: false),
      ),
    );
    expect(updated.data()['records'].single['parts'], 1);
    expect(
      updated.data()['records'].single['metrics'],
      isNot(contains('delayTimeValue')),
    );
    final revoked = updated.merge(
      readTrafficSnapshot(
        trafficGroup(time: '2026-10-25T10:02:00Z', revoked: true),
      ),
    );
    expect(revoked.data()['records'], isEmpty);
    expect(revoked.merge(initial).data()['records'], isEmpty);
  });
  test('provider uses bounded change windows, preserves data on malformed changes/304 and restarts full synchronization after a gap', () async {
    var now = DateTime.utc(2026, 10, 25, 10), step = 0;
    final headers = <String?>[];
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      now: () => now,
      readTrafficKey: () async => 'fixture-only',
      client: MockClient((request) async {
        headers.add(request.headers['If-Modified-Since']);
        return switch (step++) {
          0 => http.Response(
            trafficGroup(),
            200,
            headers: {'content-type': 'text/xml; charset=utf-8'},
          ),
          1 => http.Response(
            trafficGroup(id: 'second', time: '2026-10-25T10:01:00Z'),
            200,
            headers: {'content-type': 'text/xml; charset=utf-8'},
          ),
          2 => http.Response('<d2LogicalModel>', 200),
          3 => http.Response('', 304),
          4 => http.Response(
            trafficGroup(time: '2026-10-25T10:03:00Z', revoked: true),
            200,
            headers: {'content-type': 'text/xml; charset=utf-8'},
          ),
          _ => http.Response(
            trafficGroup(id: 'new-full', time: now.toIso8601String()),
            200,
            headers: {'content-type': 'text/xml; charset=utf-8'},
          ),
        };
      }),
    );
    addTearDown(provider.dispose);
    await provider.fetch();
    now = now.add(const Duration(minutes: 1));
    final second = await provider.fetch(forceRefresh: true);
    expect(second.data['records'], hasLength(2));
    expect(headers.first, isNull);
    expect(headers[1], isNotNull);
    now = now.add(const Duration(seconds: 20));
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(identical(provider.cached, second), true);
    now = now.add(const Duration(seconds: 20));
    final unchanged = await provider.fetch(forceRefresh: true);
    expect(unchanged.data['records'], hasLength(2));
    expect(headers[3], headers[2]);
    now = now.add(const Duration(minutes: 1));
    final revoked = await provider.fetch(forceRefresh: true);
    expect(revoked.data['records'].single['id'], 'second');
    now = now.add(const Duration(minutes: 5));
    final full = await provider.fetch(forceRefresh: true);
    expect(headers.last, isNull);
    expect(full.data['records'].single['id'], 'new-full');
  });
  test('map limits apply after ranking and validity checks, retaining nearby incidents even beyond 1000 national records', () {
    final records = List.generate(
      1200,
      (i) => {
        'id': 'far-$i',
        'name': 'far',
        'detail': '',
        'geometry': {
          'type': 'Point',
          'coordinates': [10.0, 46.0],
        },
      },
    );
    records.add({
      'id': 'near',
      'name': 'near',
      'detail': '',
      'geometry': {
        'type': 'Point',
        'coordinates': [8.0, 47.0],
      },
    });
    final map = trafficMapFeatures(records, latitude: 47, longitude: 8);
    expect(map, hasLength(1000));
    expect(map.first['id'], 'near');
    expect(records, hasLength(1201));
    expect(
      TrafficIncident({'validFromUtc': '2030-01-01T00:00:00Z'})
          .state(DateTime.utc(2026)),
      'Geplant',
    );
  });
}
