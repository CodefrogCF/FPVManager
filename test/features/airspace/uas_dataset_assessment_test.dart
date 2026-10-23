import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/uas_dataset_assessment.dart';
import 'package:fpvmanager/features/airspace/uas_zone_details.dart';

import '../../helpers/uas_zone_fixture.dart';

void main() {
  test('source codes, zero and mixed vertical references are retained', () {
    const zone = UasZoneDetails(
      id: '1',
      name: 'Zone',
      attributes: uasFixtureAttributes,
    );
    expect(zone.value('restriction'), 'REQ_AUTHORISATION.MTOM_ALL');
    expect(zone.heightLimit(upper: false), '0 M · AGL');
    expect(zone.heightLimit(upper: true), '900 M · AMSL');
    expect(zone.value('startTime'), '00:00:00.00+02:00');
    expect(zone.missingFields, isEmpty);
    final report = UasDatasetAssessment.inspect(
      uasFixtureCollection([uasFixtureFeature()]),
    );
    expect(report.issues, isEmpty);
    expect(report.renderedFeatureCount, 1);
  });

  test(
    'temporary dates are required only for an explicitly temporary source zone',
    () {
      final temporary = {
        ...uasFixtureAttributes,
        'permanent': 'NO',
        'restriction': '',
      };
      final zone = UasZoneDetails(id: '1', name: 'Zone', attributes: temporary);
      expect(
        zone.missingFields,
        containsAll(['Restriction code', 'Start date/time', 'End date/time']),
      );
      final report = UasDatasetAssessment.inspect(
        uasFixtureCollection([
          uasFixtureFeature(overrides: temporary),
          uasFixtureFeature(overrides: {'lowerLimit': 0}),
        ]),
      );
      expect(report.featuresMissingDetails, 1);
      expect(report.issues.single, contains('1 displayed features'));
    },
  );

  test(
    'partial geometry is counted and excluded without changing the source',
    () {
      final valid = uasFixtureFeature();
      final source = uasFixtureCollection([
        valid,
        {...uasFixtureFeature(), 'geometry': null},
        {
          ...uasFixtureFeature(),
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [8, 47],
                [8.1, 47],
                [8, 47.1],
                [8.2, 47.2],
              ],
            ],
          },
        },
        {
          ...uasFixtureFeature(),
          'geometry': {
            'type': 'Point',
            'coordinates': [8, double.nan],
          },
        },
        {
          ...uasFixtureFeature(),
          'geometry': {'type': 'UnknownShape', 'coordinates': []},
        },
      ]);
      final report = UasDatasetAssessment.inspect(source);
      expect(report.sourceFeatureCount, 5);
      expect(report.skippedFeatureCount, 4);
      expect(report.geoJson['features'], [valid]);
      expect((source['features'] as List).length, 5);
      expect(report.issues.single, contains('4 of 5'));
    },
  );

  test('empty, paginated and contradictory source counts remain visible', () {
    expect(
      UasDatasetAssessment.inspect(uasFixtureCollection([])).issues.single,
      contains('empty dataset'),
    );
    final report = UasDatasetAssessment.inspect({
      ...uasFixtureCollection([uasFixtureFeature()]),
      'numberMatched': '5',
      'numberReturned': 2,
      'links': [
        {'rel': 'next', 'href': 'https://example.invalid/next'},
      ],
    });
    expect(report.declaredTotal, 5);
    expect(report.hasNextPage, isTrue);
    expect(report.countMismatch, isTrue);
    expect(report.issues, hasLength(3));
    expect(report.issues.join(' '), contains('Only 1 of 5'));
  });

  test(
    'entirely unusable data is rejected rather than replacing prior geometry',
    () {
      expect(
        () => UasDatasetAssessment.inspect(
          uasFixtureCollection([
            {'type': 'Feature', 'geometry': null},
          ]),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'multipolygons, holes and other supported GeoJSON geometry are assessed',
    () {
      final polygon = uasFixtureFeature()['geometry'] as Map;
      final coordinates = polygon['coordinates'] as List;
      final report = UasDatasetAssessment.inspect(
        uasFixtureCollection([
          {
            ...uasFixtureFeature(),
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [coordinates, coordinates],
            },
          },
          {
            ...uasFixtureFeature(),
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                ...coordinates,
                [
                  [8.01, 47.01],
                  [8.02, 47.01],
                  [8.02, 47.02],
                  [8.01, 47.01],
                ],
              ],
            },
          },
          {
            ...uasFixtureFeature(),
            'geometry': {
              'type': 'GeometryCollection',
              'geometries': [
                {
                  'type': 'Point',
                  'coordinates': [8, 47],
                },
                {
                  'type': 'LineString',
                  'coordinates': [
                    [8, 47],
                    [8.1, 47.1],
                  ],
                },
              ],
            },
          },
        ]),
      );
      expect(report.renderedFeatureCount, 3);
      expect(report.hasIssues, isFalse);
    },
  );
}
