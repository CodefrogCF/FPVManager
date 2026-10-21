import 'dart:math' as math;

import 'geo_coordinate_service.dart';

/// Horizontal GeoJSON intersections. Ring edges and route segments are straight
/// in WGS84 longitude/latitude, not geodesics. All ring boundaries count as hits.
class PolygonIntersectionIndex {
  PolygonIntersectionIndex._(this._features, this.unassessedFeatureCount);

  factory PolygonIntersectionIndex.fromGeoJson(Map<String, dynamic> data) {
    final features = data['features'];
    if (data['type'] != 'FeatureCollection' || features is! List) {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }
    final indexed = <_Feature>[];
    var unassessed = 0;
    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final polygons = <_Polygon>[];
      var complete = true;
      void read(Object? geometry, int depth) {
        if (geometry is! Map || depth > 4) {
          complete = false;
          return;
        }
        final coordinates = geometry['coordinates'];
        try {
          switch (geometry['type']) {
            case 'Polygon':
              polygons.add(_Polygon.read(coordinates));
            case 'MultiPolygon':
              if (coordinates is! List || coordinates.isEmpty) {
                throw const FormatException('Empty MultiPolygon');
              }
              for (final polygon in coordinates) {
                polygons.add(_Polygon.read(polygon));
              }
            case 'GeometryCollection':
              final children = geometry['geometries'];
              if (children is! List || children.isEmpty) {
                throw const FormatException('Empty GeometryCollection');
              }
              for (final child in children) {
                read(child, depth + 1);
              }
            default:
              complete = false;
          }
        } on FormatException {
          complete = false;
        }
      }

      if (feature is Map && feature['type'] == 'Feature') {
        read(feature['geometry'], 0);
      } else {
        complete = false;
      }
      if (!complete) unassessed++;
      if (polygons.isNotEmpty) indexed.add(_Feature(i, polygons));
    }
    return PolygonIntersectionIndex._(List.unmodifiable(indexed), unassessed);
  }

  final List<_Feature> _features;
  final int unassessedFeatureCount;
  int get assessedFeatureCount => _features.length;

  static void validatePath(List<Wgs84Coordinate> path) {
    if (path.isEmpty || path.length > 1000) {
      throw ArgumentError('A check requires 1 to 1000 positions');
    }
    for (var i = 0; i < path.length; i++) {
      final point = path[i];
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        throw ArgumentError('Invalid WGS84 position');
      }
      if (i > 0 && (point.longitude - path[i - 1].longitude).abs() > 180) {
        throw ArgumentError('Split antimeridian-crossing route segments first');
      }
    }
  }

  List<PolygonIntersection> check(List<Wgs84Coordinate> path) {
    validatePath(path);
    final points = [for (final p in path) _Point(p.longitude, p.latitude)];
    final segmentBounds = [
      for (var i = 0; i + 1 < points.length; i++)
        _Bounds([points[i], points[i + 1]]),
    ];
    final hits = <PolygonIntersection>[];
    for (final feature in _features) {
      final pointIndices = <int>{};
      final segmentIndices = <int>{};
      for (var i = 0; i < points.length; i++) {
        if (feature.polygons.any((polygon) => polygon.contains(points[i]))) {
          pointIndices.add(i);
        }
      }
      for (var i = 0; i + 1 < points.length; i++) {
        if (pointIndices.contains(i) ||
            pointIndices.contains(i + 1) ||
            feature.polygons.any(
              (polygon) => polygon.crossesBoundary(
                points[i],
                points[i + 1],
                segmentBounds[i],
              ),
            )) {
          segmentIndices.add(i);
        }
      }
      if (pointIndices.isNotEmpty || segmentIndices.isNotEmpty) {
        hits.add(
          PolygonIntersection(feature.index, pointIndices, segmentIndices),
        );
      }
    }
    return List.unmodifiable(hits);
  }
}

class PolygonIntersection {
  PolygonIntersection(this.featureIndex, Set<int> points, Set<int> segments)
    : pointIndices = Set.unmodifiable(points),
      segmentIndices = Set.unmodifiable(segments);

  final int featureIndex;

  /// Zero-based indices into the checked path.
  final Set<int> pointIndices;

  /// A segment at index i connects positions i and i + 1.
  final Set<int> segmentIndices;
}

class _Feature {
  const _Feature(this.index, this.polygons);
  final int index;
  final List<_Polygon> polygons;
}

class _Point {
  const _Point(this.x, this.y);
  final double x, y;
}

// About 0.01 mm in latitude: numerical tolerance, not a safety buffer.
const _epsilon = 1e-10;

class _Bounds {
  _Bounds(List<_Point> points)
    : minX = points.map((p) => p.x).reduce(math.min),
      maxX = points.map((p) => p.x).reduce(math.max),
      minY = points.map((p) => p.y).reduce(math.min),
      maxY = points.map((p) => p.y).reduce(math.max);
  final double minX, maxX, minY, maxY;

  bool contains(_Point p) =>
      p.x >= minX - _epsilon &&
      p.x <= maxX + _epsilon &&
      p.y >= minY - _epsilon &&
      p.y <= maxY + _epsilon;

  bool intersects(_Bounds other) =>
      maxX + _epsilon >= other.minX &&
      other.maxX + _epsilon >= minX &&
      maxY + _epsilon >= other.minY &&
      other.maxY + _epsilon >= minY;
}

class _Ring {
  _Ring(this.points) : bounds = _Bounds(points);
  factory _Ring.read(Object? value) {
    if (value is! List || value.length < 4) {
      throw const FormatException('Invalid polygon ring');
    }
    final points = <_Point>[];
    for (final coordinate in value) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num ||
          !(coordinate[0] as num).isFinite ||
          !(coordinate[1] as num).isFinite ||
          (coordinate[0] as num).abs() > 180 ||
          (coordinate[1] as num).abs() > 90) {
        throw const FormatException('Invalid polygon coordinate');
      }
      points.add(_Point(coordinate[0].toDouble(), coordinate[1].toDouble()));
    }
    if (points.first.x != points.last.x || points.first.y != points.last.y) {
      throw const FormatException('Unclosed polygon ring');
    }
    var area = 0.0;
    for (var i = 0; i + 1 < points.length; i++) {
      if ((points[i].x - points[i + 1].x).abs() > 180) {
        throw const FormatException(
          'Split antimeridian-crossing polygons first',
        );
      }
      area += _cross(points.first, points[i], points[i + 1]);
    }
    if (area == 0) throw const FormatException('Degenerate polygon ring');
    return _Ring(points);
  }
  final List<_Point> points;
  final _Bounds bounds;

  // 0 outside, 1 inside, 2 boundary; independent of winding direction.
  int locate(_Point p) {
    if (!bounds.contains(p)) return 0;
    var inside = false;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      if (_onSegment(p, a, b)) return 2;
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside ? 1 : 0;
  }

  bool intersects(_Point a, _Point b, _Bounds segmentBounds) {
    if (!bounds.intersects(segmentBounds)) return false;
    for (var i = 0; i + 1 < points.length; i++) {
      if (_segmentsIntersect(a, b, points[i], points[i + 1])) return true;
    }
    return false;
  }
}

class _Polygon {
  _Polygon(this.rings);
  factory _Polygon.read(Object? coordinates) {
    if (coordinates is! List || coordinates.isEmpty) {
      throw const FormatException('Invalid Polygon');
    }
    return _Polygon(coordinates.map(_Ring.read).toList());
  }
  final List<_Ring> rings;
  bool contains(_Point p) {
    final outer = rings.first.locate(p);
    if (outer == 0) return false;
    if (outer == 2) return true;
    var inHole = false;
    for (final hole in rings.skip(1)) {
      final location = hole.locate(p);
      if (location == 2) return true;
      if (location == 1) inHole = true;
    }
    return !inHole;
  }

  bool crossesBoundary(_Point a, _Point b, _Bounds bounds) {
    return rings.first.bounds.intersects(bounds) &&
        rings.any((ring) => ring.intersects(a, b, bounds));
  }
}

double _cross(_Point a, _Point b, _Point p) =>
    (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);

bool _onSegment(_Point p, _Point a, _Point b) =>
    p.x >= math.min(a.x, b.x) - _epsilon &&
    p.x <= math.max(a.x, b.x) + _epsilon &&
    p.y >= math.min(a.y, b.y) - _epsilon &&
    p.y <= math.max(a.y, b.y) + _epsilon &&
    _cross(a, b, p).abs() <= _epsilon * ((b.x - a.x).abs() + (b.y - a.y).abs());

bool _segmentsIntersect(_Point a, _Point b, _Point c, _Point d) {
  if (_onSegment(a, c, d) ||
      _onSegment(b, c, d) ||
      _onSegment(c, a, b) ||
      _onSegment(d, a, b)) {
    return true;
  }
  final abC = _cross(a, b, c), abD = _cross(a, b, d);
  final cdA = _cross(c, d, a), cdB = _cross(c, d, b);
  return ((abC > 0 && abD < 0) || (abC < 0 && abD > 0)) &&
      ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0));
}
