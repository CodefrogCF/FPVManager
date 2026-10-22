import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/airspace/uas_airspace_checker.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';

import '../../helpers/uas_zone_fixture.dart';

void main() {
  late Map<String, dynamic> data;
  late SwissUasProvider provider;
  late MockClient client;
  var downloads = 0, status = 200;
  const point = Wgs84Coordinate(latitude: 47.02, longitude: 8.08);
  setUp(() {
    downloads = 0;
    status = 200;
    data = uasFixtureCollection([uasFixtureFeature()]);
    client = MockClient((_) async {
      downloads++;
      return http.Response(jsonEncode(data), status);
    });
    provider = SwissUasProvider(client: client);
  });
  tearDown(() {
    provider.dispose();
    client.close();
  });

  test('point report retains restrictions and provenance without renderer or visibility changes', () async {
    final globe = GlobeController(uasProvider: provider);
    addTearDown(globe.dispose);
    final report = await globe.checkAirspace([point]);
    expect(
      report.intersections.single.zone.value('restriction'),
      'REQ_AUTHORISATION',
    );
    expect(
      report.intersections.single.zone.heightLimit(upper: true),
      '900 M · AMSL',
    );
    expect(report.source, same(provider.source));
    expect(report.fetchedAtUtc, provider.status.dataset!.fetchedAtUtc);
    expect(report.checkedFeatureCount, 1);
    expect(report.limitations, isEmpty);
    expect(globe.uasDisplayedDataset, isNull);
    expect(globe.uasZonesVisible, isFalse);
    await globe.checkAirspace([point]);
    expect(downloads, 1);
  });

  test('all overlaps remain even with duplicate source identifiers', () async {
    data = uasFixtureCollection([
      uasFixtureFeature(overrides: {'restriction': 'A'}),
      uasFixtureFeature(overrides: {'restriction': 'B'}),
    ]);
    final result = await UasAirspaceChecker(provider).check([point]);
    expect(result.intersections.map((h) => h.zone.value('restriction')), [
      'A',
      'B',
    ]);
  });

  test(
    'route segment crossing is checked even if every waypoint is outside',
    () async {
      final result = await UasAirspaceChecker(provider).check([
        const Wgs84Coordinate(latitude: 47.02, longitude: 7.9),
        const Wgs84Coordinate(latitude: 47.02, longitude: 8.2),
      ]);
      expect(result.intersections.single.geometry.pointIndices, isEmpty);
      expect(result.intersections.single.geometry.segmentIndices, {0});
    },
  );

  test(
    'empty, partial and unsupported data never lose their limitations',
    () async {
      data = {
        ...uasFixtureCollection([
          uasFixtureFeature(),
          {'type': 'Feature', 'geometry': null},
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [8, 47],
            },
          },
        ]),
        'numberMatched': 10,
        'links': [
          {'rel': 'next', 'href': 'https://example.invalid/never-follow'},
        ],
      };
      final checker = UasAirspaceChecker(provider);
      final report = await checker.check([point]);
      expect(report.intersections, hasLength(1));
      expect(report.limitations.join(' '), contains('1 of 3'));
      expect(report.limitations.join(' '), contains('3 of 10'));
      expect(report.limitations.join(' '), contains('another page'));
      expect(
        report.limitations.join(' '),
        contains('1 features could not be fully checked'),
      );
      expect(downloads, 1);
      data = uasFixtureCollection([]);
      final empty = await checker.check([point], forceRefresh: true);
      expect(empty.checkedFeatureCount, 0);
      expect(empty.intersections, isEmpty);
      expect(empty.limitations.single, contains('empty dataset'));
    },
  );

  test(
    'failed refresh is a failure and explicit retry can replace the snapshot',
    () async {
      final checker = UasAirspaceChecker(provider);
      final first = await checker.check([point]);
      status = 503;
      await expectLater(
        checker.check([point], forceRefresh: true),
        throwsException,
      );
      expect(provider.status.dataset!.fetchedAtUtc, first.fetchedAtUtc);
      final cached = await checker.check([point]);
      expect(
        cached.limitations,
        contains('The latest source refresh failed; cached data was checked.'),
      );
      status = 200;
      data = uasFixtureCollection([
        uasFixtureFeature(overrides: {'restriction': 'UPDATED'}),
      ]);
      final fresh = await checker.check([point], forceRefresh: true);
      expect(fresh.intersections.single.zone.value('restriction'), 'UPDATED');
      expect(downloads, 3);
    },
  );

  test('invalid input is rejected before fetching and unusable data fails explicitly', () async {
    final checker = UasAirspaceChecker(provider);
    await expectLater(checker.check([]), throwsArgumentError);
    expect(downloads, 0);
    data = uasFixtureCollection([
      {'type': 'Feature', 'geometry': null},
    ]);
    await expectLater(
      checker.check([point]),
      throwsA(
        isA<OsintProviderException>().having(
          (e) => e.kind,
          'kind',
          OsintFailureKind.invalidData,
        ),
      ),
    );
  });

  test('source detail conversion bounds raw fields and retains zero, false and null text', () {
    final zone = UasZoneDetails.fromFeature({
      'type': 'Feature',
      'properties': {
        'extra': 'x' * 9000,
        'zero': 0,
        'false': false,
        'empty': '',
        'null': null,
        ...uasFixtureAttributes,
        for (var i = 0; i < 140; i++) 'property-$i': 'value',
      },
    }, fallbackId: 'fallback');
    expect(zone.name, 'Fixture zone');
    expect(zone.attributes['zero'], '0');
    expect(zone.attributes['false'], 'false');
    expect(zone.attributes['empty'], '');
    expect(zone.attributes['null'], 'null');
    expect(zone.attributes['extra']!.length, 8000);
    expect(zone.truncatedAttributes, contains('extra'));
    expect(zone.attributes.length, 128);
    expect(zone.omittedAttributeCount, greaterThan(0));
    expect(zone.value('restriction'), 'REQ_AUTHORISATION');
  });
}
