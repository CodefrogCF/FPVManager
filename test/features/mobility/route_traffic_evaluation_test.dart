import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/route_traffic_evaluation.dart';
import 'package:fpvmanager/features/mobility/traffic_snapshot.dart';
import 'package:fpvmanager/features/mobility/traffic_incident.dart';

import '../../helpers/route_traffic_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  RouteTrafficEvaluation compare(
    List<Map<String, dynamic>> events, {
    List<RoadRoute>? routes,
    Map<String, dynamic>? counterData,
  }) => evaluateRouteTraffic(
    RouteTrafficInput(
      routes ?? [trafficRoute(), trafficRoute(lon: 8.001, seconds: 90)],
      trafficTime,
      traffic: trafficState({'records': events}),
      counters: counterData == null ? null : trafficState(counterData),
    ),
  );

  test('one OSRM request retains alternatives, steps and refs; invalid extras are omitted', () async {
    var requests = 0;
    final router = RoadRouter(
      client: MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['alternatives'], 'true');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              trafficRouteJson(ref: 'A 1; E35'),
              trafficRouteJson(lon: 8.001, seconds: 90),
              {...trafficRouteJson(), 'distance': -1},
              trafficRouteJson(lon: 8.002),
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(router.dispose);
    final route = await router.calculate(
      MobilityPoint(47, 8),
      MobilityPoint(47.002, 8),
    );
    expect(requests, 1);
    expect(route.choices, hasLength(2));
    expect(route.omittedAlternatives, 2);
    expect(route.sections.single.references, {'A1', 'E35'});
    expect(route.alternatives.single.points.first.longitude, 8.001);
    expect(route.maneuvers.single.type, 'depart');
  });
  test('degenerate extra route does not replace a valid route; single-route fallback works', () async {
    final router = RoadRouter(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              trafficRouteJson(),
              {...trafficRouteJson(), 'distance': 0},
            ],
          }),
          200,
        ),
      ),
    );
    addTearDown(router.dispose);
    final route = await router.calculate(
      MobilityPoint(47, 8),
      MobilityPoint(47.002, 8),
    );
    expect(route.choices, hasLength(1));
    expect(route.omittedAlternatives, 1);
    expect(compare([], routes: route.choices).recommendedIndex, 0);
  });
  test('larger alternative geometry is decoded on a worker without changing source coordinates', () async {
    final points = List.generate(3000, (i) => [8.0, 47.0 + i * .002 / 2999]);
    final data = trafficRouteJson();
    data['geometry'] = {'type': 'LineString', 'coordinates': points};
    data['legs'][0]['steps'][0]['geometry'] = data['geometry'];
    final body = jsonEncode({
      'code': 'Ok',
      'routes': [data],
    });
    expect(body.length, greaterThan(64 * 1024));
    final router = RoadRouter(
      client: MockClient((_) async => http.Response(body, 200)),
    );
    addTearDown(router.dispose);
    final route = await router.calculate(
      MobilityPoint(47, 8),
      MobilityPoint(47.002, 8),
    );
    expect(route.points, hasLength(points.length));
    expect(route.sections.single.points.last.toJson(), points.last);
    expect(route.points.last.toJson(), points.last);
  });
  test('current closure and published delay prefer an alternative without changing baseline times', () {
    final closed = compare([
      trafficEvent([trafficPart()]),
    ]);
    expect(closed.recommendedIndex, 1);
    expect(closed.assessments.first.closures, 1);
    expect(closed.assessments.first.route.durationSeconds, 60);
    final delayed = compare([
      trafficEvent([trafficPart(category: 'congestion', delay: 120)]),
    ]);
    expect(delayed.recommendedIndex, 1);
    expect(delayed.assessments.first.reportedDelaySeconds, 120);
    expect(delayed.assessments.last.route.durationSeconds, 90);
  });
  test('duplicate parent closure counted once and delays use maximum rather than sum', () {
    final r = compare([
      trafficEvent([
        trafficPart(id: 'first', delay: 60),
        trafficPart(id: 'second', delay: 120),
        trafficPart(id: 'second', delay: 120),
      ]),
    ]);
    expect(r.assessments.first.closures, 1);
    expect(r.assessments.first.evidence, hasLength(2));
    expect(r.assessments.first.reportedDelaySeconds, 120);
  });
  test('stale, unverified imported and failed snapshots cannot change a recommendation', () {
    for (final state in [
      trafficState({
        'records': [
          trafficEvent([trafficPart()]),
        ],
      }, stale: true),
      trafficState({
        'records': [
          trafficEvent([trafficPart()]),
        ],
      }, imported: true),
      trafficState({
        'records': [
          trafficEvent([trafficPart()]),
        ],
      }, failed: true),
    ]) {
      final r = evaluateRouteTraffic(
        RouteTrafficInput(
          [trafficRoute(), trafficRoute(lon: 8.001)],
          trafficTime,
          traffic: state,
        ),
      );
      expect(r.recommendedIndex, 0);
      expect(r.assessments.first.evidence, isEmpty);
    }
  });
  test('road, direction, source position, carriageway and validity must all support matching', () {
    final mutations = <Map<String, dynamic>>[
      {
        'roadNumbers': ['A2'],
      },
      {'roadNumbers': []},
      {'directionBound': 'southBound'},
      {'directionBound': '', 'directionCode': 'positive'},
      {'geometryAccuracy': 'displayReference'},
      {'geometryAccuracy': 'approximateLine'},
      {
        'point': [8.0005, 47.001],
      },
      {'lane': 'lane1'},
      {'carriageway': 'entrySlipRoad'},
      {'suspended': true},
      {'withdrawn': true},
      {'recurring': true},
      {'validFromUtc': '2026-10-29T11:00:00Z'},
      {'validUntilUtc': '2026-10-29T09:00:00Z'},
      {'timestampUtc': '2026-10-29T11:00:00Z'},
      {'timestampUtc': '2026-10-29T10:00:00'},
      {'validFromUtc': 'invalid'},
    ];
    for (final change in mutations) {
      final r = compare([
        trafficEvent([
          {...trafficPart(), ...change},
        ]),
      ]);
      expect(r.recommendedIndex, 0, reason: '$change');
      expect(r.assessments.first.evidence, isEmpty, reason: '$change');
    }
    expect(
      compare(
        [
          trafficEvent([trafficPart()]),
        ],
        routes: [trafficRoute(link: true), trafficRoute(lon: 8.001)],
      ).assessments.first.evidence,
      isEmpty,
    );
  });
  test('nearby parallel alternatives are not both penalized; ambiguous midpoint is excluded', () {
    final routes = [
      trafficRoute(),
      trafficRoute(lon: 8.00008, seconds: 90),
    ]; // ~6m apart
    final r = compare([
      trafficEvent([trafficPart()]),
    ], routes: routes);
    expect(r.assessments.first.closures, 1);
    expect(r.assessments.last.closures, 0);
    expect(r.recommendedIndex, 1);
    final ambiguous = compare([
      trafficEvent([trafficPart(lon: 8.00004)]),
    ], routes: routes);
    expect(ambiguous.assessments.every((a) => a.evidence.isEmpty), true);
  });
  test('opposite direction excluded; explicit both-directions can affect both carriageways', () {
    final routes = [
      trafficRoute(),
      trafficRoute(lon: 8.00008, reverse: true, seconds: 90),
    ];
    expect(
      compare([
        trafficEvent([trafficPart()]),
      ], routes: routes).assessments.last.closures,
      0,
    );
    final both = compare([
      trafficEvent([
        {
          ...trafficPart(lon: 8.00004),
          'directionBound': '',
          'directionCode': 'both',
        },
      ]),
    ], routes: routes);
    expect(both.assessments.map((a) => a.closures), [1, 1]);
  });
  test('normalization retains per-part evidence and never attaches another part delay to a point', () {
    final parsed = parseTrafficSnapshot(
      trafficXml(
        type: 'AbnormalTraffic',
        effect: '<abnormalTrafficType>queuingTraffic</abnormalTrafficType>',
        extraPart: '<situationRecord id="delay"><situationRecordVersionTime>2026-10-29T10:00:00Z</situationRecordVersionTime><delayTimeValue>600</delayTimeValue></situationRecord>',
      ),
    );
    final record = (parsed['records'] as List).single as Map;
    expect(record['metrics']['delayTimeValue'], 600);
    final parts = record['routingEvidence'] as List;
    expect(parts.first['roadNumbers'], ['A 1']);
    expect(parts.first['directionBound'], 'northBound');
    expect(parts.last['point'], isNull);
    final r = evaluateRouteTraffic(
      RouteTrafficInput(
        [trafficRoute(), trafficRoute(lon: 8.001, seconds: 90)],
        trafficTime,
        traffic: trafficState(parsed),
      ),
    );
    expect(r.assessments.first.evidence, hasLength(1));
    expect(r.assessments.first.reportedDelaySeconds, isNull);
    expect(r.recommendedIndex, 0);
    expect(
      trafficMapFeatures(
        parsed['records'] as List,
        latitude: 47,
        longitude: 8,
        now: trafficTime,
      ).first,
      isNot(contains('routingEvidence')),
    );
  });
  test('only comparable current aggregate speeds have a small effect and never replace ETA', () {
    final routes = [trafficRoute(), trafficRoute(lon: 8.001, seconds: 60)];
    final alone = compare(
      [],
      routes: routes,
      counterData: {
        'features': [speedSite()],
      },
    );
    expect(alone.speedCompared, false);
    expect(alone.recommendedIndex, 0);
    final r = compare(
      [],
      routes: routes,
      counterData: {
        'features': [speedSite(), speedSite(lon: 8.001, speed: 16)],
      },
    );
    expect(r.speedCompared, true);
    expect(r.recommendedIndex, 1);
    expect(r.assessments.last.route.durationSeconds, 60);
    final longer = compare(
      [],
      routes: [trafficRoute(), trafficRoute(lon: 8.001, seconds: 130)],
      counterData: {
        'features': [speedSite(), speedSite(lon: 8.001, speed: 16)],
      },
    );
    expect(longer.recommendedIndex, 0);
  });
  test('counter metadata, units, individual measurement age and scope are enforced', () {
    for (final change in <Map<String, dynamic>>[
      {'unit': 'MilesPerHour'},
      {'error': true},
      {'value': double.nan},
      {'timeUtc': '2026-10-29T09:55:00Z'},
      {'timeUtc': '2026-10-29T10:01:00Z'},
    ]) {
      final site = speedSite();
      site['values'] = [
        {...(site['values'] as List).single as Map, ...change},
      ];
      expect(
        compare(
          [],
          counterData: {
            'features': [site],
          },
        ).assessments.first.evidence,
        isEmpty,
        reason: '$change',
      );
    }
    for (final change in <Map<String, dynamic>>[
      {'vehicle': 'car'},
      {'periodSeconds': null},
      {'periodSeconds': 1000},
    ]) {
      final site = speedSite();
      site['values'] = [
        {...(site['values'] as List).single as Map, ...change},
      ];
      final r = compare(
        [],
        counterData: {
          'features': [site],
        },
      );
      expect(r.assessments.first.evidence, hasLength(1));
      expect(r.assessments.first.speedRatio, isNull);
    }
    final unverified = {...speedSite(), 'metadataVersionVerified': false};
    expect(
      compare(
        [],
        counterData: {
          'features': [unverified],
        },
      ).assessments.first.evidence,
      isEmpty,
    );
  });
  test('no traffic effects preserves OSRM order and bounded incomplete input cannot re-rank', () {
    expect(
      compare(
        [],
        routes: [
          trafficRoute(seconds: 90),
          trafficRoute(lon: 8.001, seconds: 60),
        ],
      ).recommendedIndex,
      0,
    );
    final records = List.generate(
      20001,
      (i) => trafficEvent([trafficPart()], id: 'event-$i'),
    );
    final r = compare(records);
    expect(r.assessments.any((a) => a.incomplete), true);
    expect(r.assessments.first.evidence.length, lessThanOrEqualTo(1000));
    expect(r.recommendedIndex, 0);
    final unknown = compare([
      {'id': 'old-cache-without-evidence'},
    ]);
    expect(unknown.assessments.first.ignored, 1);
  });
}
