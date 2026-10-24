import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/obstacles/obstacle_models.dart';
import 'package:fpvmanager/features/obstacles/obstacle_proximity.dart';
import 'package:fpvmanager/features/obstacles/swiss_obstacle_heights.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const geo = GeoCoordinateService();
  Lv95Coordinate xy(double x, double y) =>
      Lv95Coordinate(easting: x, northing: y);
  Wgs84Coordinate at(double x, double y) =>
      geo.lv95ToWgs84(xy(2600000 + x, 1200000 + y));
  List<double> coordinate(double x, double y) {
    final p = at(x, y);
    return [p.longitude, p.latitude];
  }

  RouteAnalysis route() {
    final points = [
      for (final x in [0.0, 200.0]) RouteWaypointInput(position: at(x, 0)),
    ];
    return RouteAnalysis.calculate(
      points,
      RouteSamplingPlan.create(points),
      null,
      const RoutePlanningSettings(),
    );
  }

  ObstacleFeature obstacle(
    String id,
    String kind,
    List<List<double>> coordinates,
  ) => ObstacleFeature(
    id: id,
    name: id,
    attributes: {},
    parts: [ObstaclePart(kind, 'clampToGround', coordinates)],
  );
  test(
    'metric point, crossing, collinear, degenerate and boundary distances',
    () {
      final point = metricSegmentDistance(
        xy(0, 0),
        xy(200, 0),
        xy(100, 30),
        xy(100, 30),
      );
      expect(point.distance, 30);
      expect(point.route, .5);
      expect(
        metricSegmentDistance(
          xy(0, 0),
          xy(200, 0),
          xy(100, -100),
          xy(100, 100),
        ).distance,
        0,
      );
      expect(
        metricSegmentDistance(
          xy(0, 0),
          xy(200, 0),
          xy(50, 0),
          xy(250, 0),
        ).distance,
        0,
      );
      expect(
        metricSegmentDistance(xy(0, 0), xy(0, 0), xy(3, 4), xy(3, 4)).distance,
        5,
      );
    },
  );
  test('complete segments detect a crossing between waypoints; heights stay unknown', () async {
    final report = await checkObstacleProximity(
      route: route(),
      obstacles: [
        obstacle('crossing', 'LineString', [
          coordinate(100, -50),
          coordinate(100, 50),
        ]),
        obstacle('point', 'Point', [coordinate(100, 20)]),
        obstacle('far', 'Point', [coordinate(100, 60)]),
      ],
      bufferMeters: 30,
    );
    expect(report.hits.map((h) => h.obstacle.id), ['crossing', 'point']);
    expect(report.hits.first.horizontalMeters, closeTo(0, .01));
    expect(report.hits.last.horizontalMeters, closeTo(20, .2));
    expect(report.hits.every((h) => h.spatialMeters == null), isTrue);
    expect(report.incomplete, isFalse);
  });
  test('3D separation uses compatible source heights and never the display fallback', () async {
    final heightGrid = await SwissObstacleHeights.load();
    final p = [
      for (final x in [0.0, 200.0])
        RouteWaypointInput(
          position: at(x, 0),
          height: const AbsoluteWaypointHeight(
            ReferencedElevation(
              meters: 700,
              reference: VerticalReference.wgs84Ellipsoid,
            ),
          ),
        ),
    ];
    final known = RouteAnalysis.calculate(
      p,
      RouteSamplingPlan.create(p),
      null,
      const RoutePlanningSettings(),
    );
    final position = coordinate(100, 0);
    final source = ObstacleFeature(
      id: 'height',
      name: 'height',
      attributes: {},
      parts: [
        ObstaclePart('Point', 'absolute', [
          [...position, 600],
        ]),
      ],
    );
    final report = await checkObstacleProximity(
      route: known,
      obstacles: [source],
      bufferMeters: 30,
      heights: heightGrid,
    );
    final top = heightGrid.ellipsoidHeight(position[0], position[1], 600)!;
    expect(report.hits.single.spatialMeters, closeTo(700 - top, .01));
    final unknown = await checkObstacleProximity(
      route: route(),
      obstacles: [source],
      bufferMeters: 30,
      heights: heightGrid,
    );
    expect(unknown.hits.single.spatialMeters, isNull);
  });
  test(
    'zero buffer includes crossings without using KML label points',
    () async {
      final feature = ObstacleFeature(
        id: 'label',
        name: 'label',
        attributes: {},
        parts: [
          ObstaclePart('LineString', 'clampToGround', [
            coordinate(100, 50),
            coordinate(120, 50),
          ]),
          ObstaclePart('Point', 'absolute', [coordinate(100, 0)]),
        ],
      );
      final report = await checkObstacleProximity(
        route: route(),
        obstacles: [
          feature,
          obstacle('crossing', 'LineString', [
            coordinate(100, -50),
            coordinate(100, 50),
          ]),
        ],
        bufferMeters: 0,
      );
      expect(report.hits.map((h) => h.obstacle.id), ['crossing']);
    },
  );
  test(
    'bounded and cancelled checks cannot return complete-looking results',
    () async {
      final features = [
        obstacle('a', 'Point', [coordinate(100, 0)]),
        obstacle('b', 'Point', [coordinate(120, 0)]),
      ];
      final limited = await checkObstacleProximity(
        route: route(),
        obstacles: features,
        bufferMeters: 30,
        maxComparisons: 1,
      );
      expect(limited.incomplete, isTrue);
      await expectLater(
        checkObstacleProximity(
          route: route(),
          obstacles: features,
          bufferMeters: 30,
          cancelled: () => true,
        ),
        throwsStateError,
      );
      for (final buffer in [-1.0, double.nan, double.infinity, 1001.0]) {
        await expectLater(
          checkObstacleProximity(
            route: route(),
            obstacles: features,
            bufferMeters: buffer,
          ),
          throwsArgumentError,
        );
      }
    },
  );
}
