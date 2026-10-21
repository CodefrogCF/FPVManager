import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/polygon_intersections.dart';

Wgs84Coordinate p(double x, double y) =>
    Wgs84Coordinate(longitude: x, latitude: y);

List<List<double>> box(double x, double y, double right, double top) => [
  [x, y],
  [right, y],
  [right, top],
  [x, top],
  [x, y],
];

Map<String, dynamic> polygon(List<Object?> rings) => {
  'type': 'Polygon',
  'coordinates': rings,
};

PolygonIntersectionIndex index(List<Object?> geometries) =>
    PolygonIntersectionIndex.fromGeoJson({
      'type': 'FeatureCollection',
      'features': [
        for (final geometry in geometries)
          {'type': 'Feature', 'geometry': geometry},
      ],
    });

void main() {
  final outer = box(8, 46, 10, 48);
  final hole = box(8.5, 46.5, 9.5, 47.5);
  final subject = index([
    polygon([outer, hole]),
  ]);

  for (final example in <(String, Wgs84Coordinate, bool)>[
    ('inside shell', p(8.25, 47), true),
    ('outside shell', p(7, 47), false),
    ('inside hole', p(9, 47), false),
    ('left outer edge', p(8, 47), true),
    ('right outer edge', p(10, 47), true),
    ('bottom outer edge', p(9, 46), true),
    ('top outer edge', p(9, 48), true),
    ('outer vertex', p(8, 46), true),
    ('hole edge', p(8.5, 47), true),
    ('hole vertex', p(8.5, 46.5), true),
    ('near but outside edge', p(8 - 1e-7, 47), false),
  ]) {
    test('point: ${example.$1}', () {
      final hits = subject.check([example.$2]);
      expect(hits.isNotEmpty, example.$3);
      if (hits.isNotEmpty) {
        expect(hits.single.pointIndices, {0});
        expect(hits.single.segmentIndices, isEmpty);
      }
    });
  }

  for (final example in <(String, List<Wgs84Coordinate>, bool)>[
    ('crossing with both endpoints outside', [p(7, 47), p(11, 47)], true),
    ('entirely inside shell', [p(8.1, 46.2), p(9, 46.2)], true),
    ('entirely inside hole', [p(8.7, 47), p(9.2, 47)], false),
    ('hole exit', [p(9, 47), p(9.8, 47)], true),
    ('outside, overlapping bounding boxes', [p(7, 47.5), p(8.5, 49)], false),
    ('tangent outer corner', [p(7, 47), p(9, 49)], true),
    ('collinear outer edge overlap', [p(7, 46), p(11, 46)], true),
    ('touching only an endpoint', [p(7, 46), p(8, 46)], true),
    ('on a hole edge', [p(8.7, 46.5), p(9.2, 46.5)], true),
    ('duplicate interior points', [p(8.2, 47), p(8.2, 47)], true),
    ('duplicate hole points', [p(9, 47), p(9, 47)], false),
    ('near but outside parallel', [p(7, 46 - 1e-7), p(11, 46 - 1e-7)], false),
  ]) {
    test('route: ${example.$1}', () {
      final hits = subject.check(example.$2);
      expect(hits.isNotEmpty, example.$3);
      if (hits.isNotEmpty) expect(hits.single.segmentIndices, {0});
    });
  }

  test('crossing between outside waypoints reports the affected segment', () {
    final hit = subject.check([p(6, 45), p(7, 47), p(11, 47)]).single;
    expect(hit.pointIndices, isEmpty);
    expect(hit.segmentIndices, {1});
  });

  test('reversed winding preserves shell, hole and boundary semantics', () {
    final reversed = index([
      polygon([outer.reversed.toList(), hole.reversed.toList()]),
    ]);
    expect(reversed.check([p(9, 47)]), isEmpty);
    expect(reversed.check([p(8.5, 47)]), hasLength(1));
    expect(reversed.check([p(8.2, 47)]), hasLength(1));
  });

  test(
    'concave polygon excludes its notch without relying on bounds alone',
    () {
      final concave = index([
        polygon([
          [
            [8, 46],
            [10, 46],
            [10, 48],
            [9, 47],
            [8, 48],
            [8, 46],
          ],
        ]),
      ]);
      expect(concave.check([p(9, 47.8)]), isEmpty);
      expect(concave.check([p(9, 46.5)]), hasLength(1));
      expect(concave.check([p(8.5, 47.8), p(9.5, 47.8)]), isEmpty);
    },
  );

  test(
    'MultiPolygon is reported once while overlapping features remain separate',
    () {
      final multi = index([
        {
          'type': 'MultiPolygon',
          'coordinates': [
            [outer, hole],
            [box(11, 46, 12, 48)],
          ],
        },
        polygon([box(8.1, 46.1, 8.4, 47.4)]),
      ]);
      final hits = multi.check([p(8.2, 47), p(11.5, 47)]);
      expect(hits.map((h) => h.featureIndex), [0, 1]);
      expect(hits.first.pointIndices, {0, 1});
      expect(hits.first.segmentIndices, {0});
      expect(hits.last.pointIndices, {0});
    },
  );

  test(
    'collection polygons are checked and unsupported components stay explicit',
    () {
      final mixed = index([
        {
          'type': 'GeometryCollection',
          'geometries': [
            polygon([outer]),
            {
              'type': 'Point',
              'coordinates': [8, 47],
            },
          ],
        },
        {
          'type': 'LineString',
          'coordinates': [
            [8, 47],
            [9, 47],
          ],
        },
      ]);
      expect(mixed.assessedFeatureCount, 1);
      expect(mixed.unassessedFeatureCount, 2);
      expect(mixed.check([p(9, 47)]).single.featureIndex, 0);
    },
  );

  test(
    'malformed and degenerate polygons are not silently treated as checked',
    () {
      final malformed = index([
        polygon([]),
        polygon([
          [
            [8, 46],
            [10, 46],
            [10, 48],
          ],
        ]),
        polygon([
          [
            [8, 46],
            [9, 46],
            [10, 46],
            [8, 46],
          ],
        ]),
        polygon([
          [
            [8, 46],
            [double.nan, 47],
            [10, 48],
            [8, 46],
          ],
        ]),
        polygon([
          [
            [181, 46],
            [182, 46],
            [182, 47],
            [181, 46],
          ],
        ]),
      ]);
      expect(malformed.assessedFeatureCount, 0);
      expect(malformed.unassessedFeatureCount, 5);
    },
  );

  test(
    'unclosed or antimeridian-crossing input is explicit, not a false clear',
    () {
      final dateline = index([
        polygon([box(179, 0, -179, 2)]),
      ]);
      expect(dateline.unassessedFeatureCount, 1);
      expect(() => subject.check([p(179, 1), p(-179, 1)]), throwsArgumentError);
    },
  );

  test('query validates finite coordinates and path bounds', () {
    for (final points in <List<Wgs84Coordinate>>[
      [],
      [p(double.nan, 47)],
      [p(8, double.infinity)],
      [p(181, 47)],
      [p(8, 91)],
      List.filled(1001, p(8, 47)),
    ]) {
      expect(() => subject.check(points), throwsArgumentError);
    }
    expect(subject.check(List.filled(1000, p(7, 45))), isEmpty);
  });

  test('query results are immutable snapshots', () {
    final hits = subject.check([p(8.2, 47)]);
    expect(() => hits.clear(), throwsUnsupportedError);
    expect(() => hits.single.pointIndices.clear(), throwsUnsupportedError);
  });
}
