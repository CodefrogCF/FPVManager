import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/traffic_snapshot.dart';
import 'package:fpvmanager/features/mobility/tmc_traffic_resolution.dart';
import 'package:fpvmanager/features/mobility/route_traffic_evaluation.dart';

import '../../helpers/tmc_fixture.dart';
import '../../helpers/route_traffic_fixtures.dart';

void main() {
  Map<String, dynamic> resolve(String xml, {bool verified = true}) =>
      resolveTrafficTmc(
        TmcTrafficInput(
          parseTrafficSnapshot(xml),
          {'7.5': fixtureTmcTable()},
          {
            '7.5': {
              'verified': verified,
              'retrievedUtc': trafficTime.toIso8601String(),
              'publication': '29/10/2026',
            },
          },
        ),
      );
  RouteTrafficEvaluation evaluate(
    Map<String, dynamic> data, {
    List<RoadRoute>? routes,
  }) => evaluateRouteTraffic(
    RouteTrafficInput(
      routes ?? [trafficRoute(), trafficRoute(lon: 8.001, seconds: 90)],
      trafficTime,
      traffic: trafficState(data),
    ),
  );

  test('resolved source anchors become labelled map geometry, with no forged coordinates for the physical road or timestamp refresh', () {
    final data = resolve(tmcXml());
    expect(data['unlocated'], 0);
    expect(data['tmcResolved'], 1);
    final f = data['features'].single;
    expect(f['geometryAccuracy'], 'tmcAnchors');
    expect(f['geometry']['coordinates'], hasLength(3));
    expect(f['timestampUtc'], trafficTime.toIso8601String());
    expect(f['tmcStatus'], contains('Zürich'));
    final offset = resolve(tmcXml(primaryOffset: 20));
    expect(offset['features'].single['geometry']['type'], 'Point');
    expect(offset['features'].single['geometryAccuracy'], 'tmcReference');
  });
  test('current resolved closure influences only the road with matching anchor order and offsets; baseline ETA stays unchanged', () {
    final data = resolve(tmcXml(primaryOffset: 20, secondaryOffset: 30));
    final r = evaluate(data);
    expect(r.recommendedIndex, 1);
    expect(r.assessments.first.closures, 1);
    expect(r.assessments.last.closures, 0);
    expect(r.assessments.first.route.durationSeconds, 60);
    expect(
      evaluate(
        data,
        routes: [trafficRoute(reverse: true), trafficRoute(lon: 8.001)],
      ).assessments.first.closures,
      0,
    );
    final negative = resolve(
      tmcXml(
        direction: 'negative',
        primary: 1,
        secondary: 3,
        primaryOffset: 20,
      ),
    );
    expect(
      evaluate(
        negative,
        routes: [trafficRoute(reverse: true), trafficRoute(lon: 8.001)],
      ).recommendedIndex,
      1,
    );
    final both = resolve(tmcXml(direction: 'both'));
    expect(
      evaluate(
        both,
        routes: [trafficRoute(reverse: true), trafficRoute(lon: 8.001)],
      ).recommendedIndex,
      1,
    );
  });
  test('offsets outside the matched road, unknown versions, unverified tables and missing anchors never change recommendation', () {
    for (final data in [
      resolve(tmcXml(primaryOffset: 1000)),
      resolve(tmcXml(version: '7.3')),
      resolve(tmcXml(), verified: false),
    ]) {
      expect(evaluate(data).recommendedIndex, 0);
      expect(evaluate(data).assessments.first.closures, 0);
    }
    final short = trafficRoute();
    final partial = RoadRoute(
      distanceMeters: 100,
      durationSeconds: 60,
      points: short.points,
      retrievedUtc: trafficTime,
      sections: [
        RoadSection(
          points: [MobilityPoint(47.0005, 8), MobilityPoint(47.0015, 8)],
          references: {'A1'},
          durationSeconds: 60,
          distanceMeters: 100,
        ),
      ],
    );
    expect(
      evaluate(
        resolve(tmcXml()),
        routes: [partial, trafficRoute(lon: 8.001)],
      ).assessments.first.closures,
      0,
    );
  });
  test('nearby parallel road and unsupported intermediate road identity cannot inherit an incident through a straight TMC chord', () {
    final data = resolve(tmcXml());
    final parallel = evaluate(
      data,
      routes: [trafficRoute(), trafficRoute(lon: 8.00008, seconds: 90)],
    );
    expect(parallel.assessments.first.closures, 1);
    expect(parallel.assessments.last.closures, 0);
    final route = RoadRoute(
      distanceMeters: 300,
      durationSeconds: 60,
      points: trafficRoute().points,
      retrievedUtc: trafficTime,
      sections: [
        RoadSection(
          points: [MobilityPoint(47, 8), MobilityPoint(47.0006, 8)],
          references: {'A1'},
          durationSeconds: 20,
          distanceMeters: 60,
        ),
        RoadSection(
          points: [MobilityPoint(47.0006, 8), MobilityPoint(47.0009, 8)],
          references: {'A2'},
          durationSeconds: 20,
          distanceMeters: 30,
        ),
        RoadSection(
          points: [MobilityPoint(47.0009, 8), MobilityPoint(47.002, 8)],
          references: {'A1'},
          durationSeconds: 20,
          distanceMeters: 120,
        ),
      ],
    );
    expect(
      evaluate(
        data,
        routes: [route, trafficRoute(lon: 8.001)],
      ).assessments.first.closures,
      0,
    );
  });
  test('method 4 point offsets and both-direction offsets use the route length in their reference direction', () {
    final point = resolve(tmcXml(linear: false, primaryOffset: 120));
    expect(point['features'].single['geometry']['type'], 'Point');
    expect(evaluate(point).assessments.first.closures, 1);
    final both = resolve(
      tmcXml(direction: 'both', primaryOffset: 25, secondaryOffset: 30),
    );
    expect(
      evaluate(
        both,
        routes: [trafficRoute(reverse: true), trafficRoute(lon: 8.001)],
      ).assessments.first.closures,
      1,
    );
    final impossible = resolve(
      tmcXml(primaryOffset: 150, secondaryOffset: 150),
    );
    expect(evaluate(impossible).assessments.first.closures, 0);
  });
}
