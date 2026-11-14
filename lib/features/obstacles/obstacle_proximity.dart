import 'dart:math' as math;

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/user_preferences.dart';
import '../routes/analysis/route_analysis.dart';
import 'obstacle_models.dart';
import 'swiss_obstacle_heights.dart';

class ObstacleProximity {
  const ObstacleProximity(
    this.segment,
    this.obstacle,
    this.horizontalMeters,
    this.spatialMeters,
  );
  final int segment;
  final ObstacleFeature obstacle;
  final double horizontalMeters;

  /// Separation at the closest horizontal approach, not minimum 3D distance.
  /// Always uses source elevations, never the terrain-adjusted display geometry.
  final double? spatialMeters;
}

class ObstacleProximityReport {
  const ObstacleProximityReport(this.hits, this.incomplete, this.comparisons);
  final List<ObstacleProximity> hits;
  final bool incomplete;
  final int comparisons;
}

typedef _XY = ({double x, double y});
_XY _project(List<double> p) {
  final v = const GeoCoordinateService().wgs84ToLv95(
    Wgs84Coordinate(latitude: p[1], longitude: p[0]),
  );
  return (x: v.easting, y: v.northing);
}

double _distance(_XY a, _XY b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
_XY _at(_XY a, _XY b, double t) =>
    (x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);
double _fraction(_XY p, _XY a, _XY b) {
  final x = b.x - a.x, y = b.y - a.y, d = x * x + y * y;
  return d == 0 ? 0 : (((p.x - a.x) * x + (p.y - a.y) * y) / d).clamp(0, 1);
}

/// Closest points of complete, closed segments, including degenerate points.
({double distance, double route, double obstacle}) metricSegmentDistance(
  Lv95Coordinate a0,
  Lv95Coordinate b0,
  Lv95Coordinate c0,
  Lv95Coordinate d0,
) {
  final a = (x: a0.easting, y: a0.northing),
      b = (x: b0.easting, y: b0.northing),
      c = (x: c0.easting, y: c0.northing),
      d = (x: d0.easting, y: d0.northing);
  final rx = b.x - a.x, ry = b.y - a.y, sx = d.x - c.x, sy = d.y - c.y;
  final cross = rx * sy - ry * sx;
  if (cross.abs() > 1e-10) {
    final t = ((c.x - a.x) * sy - (c.y - a.y) * sx) / cross,
        u = ((c.x - a.x) * ry - (c.y - a.y) * rx) / cross;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return (distance: 0, route: t, obstacle: u);
    }
  }
  final candidates = <({double distance, double route, double obstacle})>[];
  for (final t in [0.0, 1.0]) {
    final p = _at(a, b, t), u = _fraction(p, c, d);
    candidates.add((
      distance: _distance(p, _at(c, d, u)),
      route: t,
      obstacle: u,
    ));
  }
  for (final u in [0.0, 1.0]) {
    final p = _at(c, d, u), t = _fraction(p, a, b);
    candidates.add((
      distance: _distance(p, _at(a, b, t)),
      route: t,
      obstacle: u,
    ));
  }
  return candidates.reduce((a, b) => a.distance <= b.distance ? a : b);
}

/// Approximate LV95 metric planning check in the supported Swiss region.
/// Bounded work and event-loop yields keep cancellation and UI responsive.
Future<ObstacleProximityReport> checkObstacleProximity({
  required RouteAnalysis route,
  required List<ObstacleFeature> obstacles,
  required double bufferMeters,
  SwissObstacleHeights? heights,
  bool Function()? cancelled,
  int maxComparisons = 500000,
}) async {
  UserPreferences.validateObstacleBuffer(bufferMeters);
  final hits = <ObstacleProximity>[], profile = route.profile;
  var incomplete = false, comparisons = 0;
  var end = 0;
  Lv95Coordinate xy(_XY p) => Lv95Coordinate(easting: p.x, northing: p.y);
  for (final segment in route.segments) {
    if (cancelled?.call() == true) {
      throw StateError('Proximity check cancelled');
    }
    if (segment.index % 32 == 0) await Future<void>.delayed(Duration.zero);
    final first = profile[end];
    do {
      end++;
    } while (profile[end].sample.fraction < 1);
    final last = profile[end];
    _XY a, b;
    try {
      a = _project([
        first.sample.position.longitude,
        first.sample.position.latitude,
      ]);
      b = _project([
        last.sample.position.longitude,
        last.sample.position.latitude,
      ]);
    } on ArgumentError {
      incomplete = true;
      continue;
    }
    final start = first.sample.position, finish = last.sample.position;
    // Conservative geographic bounds for the supported Swiss LV95 domain.
    // Reject distant features before spending the precise geometry budget.
    final padding = bufferMeters + 2;
    final west = math.min(start.longitude, finish.longitude) - padding / 60000;
    final east = math.max(start.longitude, finish.longitude) + padding / 60000;
    final south = math.min(start.latitude, finish.latitude) - padding / 100000;
    final north = math.max(start.latitude, finish.latitude) + padding / 100000;
    for (final feature in obstacles) {
      if (cancelled?.call() == true) {
        throw StateError('Proximity check cancelled');
      }
      if (feature.parts.any(
        (p) => p.kind != 'Point' && p.kind != 'LineString',
      )) {
        incomplete = true;
      }
      // Long projected chords can depart from their geographic envelope.
      if (segment.horizontal <= 1000 &&
          feature.east - feature.west < .01 &&
          feature.north - feature.south < .01 &&
          (feature.east < west ||
              feature.west > east ||
              feature.north < south ||
              feature.south > north)) {
        continue;
      }
      double best = double.infinity;
      double? spatial;
      final hasShape = feature.parts.any((p) => p.kind != 'Point');
      for (final part in feature.parts) {
        if (hasShape && part.kind == 'Point') continue;
        if (part.kind != 'Point' && part.kind != 'LineString') {
          incomplete = true;
          continue;
        }
        final coordinates = part.coordinates;
        for (var i = 0; i < math.max(1, coordinates.length - 1); i++) {
          if (++comparisons > maxComparisons) {
            return ObstacleProximityReport(
              List.unmodifiable(hits),
              true,
              comparisons,
            );
          }
          if (comparisons % 512 == 0) {
            await Future<void>.delayed(Duration.zero);
            if (cancelled?.call() == true) {
              throw StateError('Proximity check cancelled');
            }
          }
          final c0 = coordinates[i],
              d0 = coordinates[math.min(i + 1, coordinates.length - 1)];
          _XY c, d;
          try {
            c = _project(c0);
            d = _project(d0);
          } on ArgumentError {
            incomplete = true;
            continue;
          }
          if (math.min(c.x, d.x) > math.max(a.x, b.x) + bufferMeters ||
              math.max(c.x, d.x) < math.min(a.x, b.x) - bufferMeters ||
              math.min(c.y, d.y) > math.max(a.y, b.y) + bufferMeters ||
              math.max(c.y, d.y) < math.min(a.y, b.y) - bufferMeters) {
            continue;
          }
          final distance = metricSegmentDistance(xy(a), xy(b), xy(c), xy(d));
          if (distance.distance > bufferMeters + 1e-6 ||
              distance.distance >= best) {
            continue;
          }
          best = distance.distance;
          spatial = null;
          if (first.altitude != null &&
              last.altitude != null &&
              part.mode == 'absolute' &&
              c0.length == 3 &&
              d0.length == 3 &&
              heights != null) {
            final ch = heights.ellipsoidHeight(c0[0], c0[1], c0[2]),
                dh = heights.ellipsoidHeight(d0[0], d0[1], d0[2]);
            if (ch != null && dh != null) {
              final rh =
                      first.altitude! +
                      (last.altitude! - first.altitude!) * distance.route,
                  oh = ch + (dh - ch) * distance.obstacle;
              spatial = math.sqrt(best * best + (rh - oh) * (rh - oh));
            }
          }
        }
      }
      if (best.isFinite) {
        hits.add(ObstacleProximity(segment.index, feature, best, spatial));
      }
      if (hits.length >= 1000) {
        return ObstacleProximityReport(
          List.unmodifiable(hits),
          true,
          comparisons,
        );
      }
    }
  }
  return ObstacleProximityReport(
    List.unmodifiable(hits),
    incomplete,
    comparisons,
  );
}
