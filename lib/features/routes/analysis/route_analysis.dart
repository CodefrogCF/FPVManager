import 'dart:math' as math;

import '../../../core/geo/geo_coordinate_service.dart';
import '../../../core/models/flight_route.dart';
import '../../../core/models/route_planning_settings.dart';

const _radius = 6371008.8;
double _radians(double degrees) => degrees * math.pi / 180;

double routeDistance(Wgs84Coordinate a, Wgs84Coordinate b) {
  final p = _radians(b.latitude - a.latitude),
      l = _radians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(p / 2), 2) +
      math.cos(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          math.pow(math.sin(l / 2), 2);
  return 2 * _radius * math.asin(math.sqrt(h.clamp(0, 1)));
}

double _bearing(Wgs84Coordinate a, Wgs84Coordinate b) {
  final p = _radians(a.latitude),
      q = _radians(b.latitude),
      dl = _radians(b.longitude - a.longitude);
  return math.atan2(
    math.sin(dl) * math.cos(q),
    math.cos(p) * math.sin(q) - math.sin(p) * math.cos(q) * math.cos(dl),
  );
}

Wgs84Coordinate _interpolate(Wgs84Coordinate a, Wgs84Coordinate b, double t) {
  final angle = routeDistance(a, b) / _radius;
  if (angle < 1e-12) return a;
  final d = _bearing(a, b),
      p = _radians(a.latitude),
      l = _radians(a.longitude),
      step = angle * t;
  final lat = math.asin(
    (math.sin(p) * math.cos(step) + math.cos(p) * math.sin(step) * math.cos(d))
        .clamp(-1, 1),
  );
  final lon =
      l +
      math.atan2(
        math.sin(d) * math.sin(step) * math.cos(p),
        math.cos(step) - math.sin(p) * math.sin(lat),
      );
  return Wgs84Coordinate(
    latitude: lat * 180 / math.pi,
    longitude: ((lon * 180 / math.pi + 540) % 360) - 180,
  );
}

class RouteSample {
  const RouteSample(this.position, this.segment, this.fraction, this.distance);
  final Wgs84Coordinate position;
  final int segment;
  final double fraction, distance;
}

class RouteSamplingPlan {
  RouteSamplingPlan._(this.samples, this.waypointIndices, this.spacing);
  final List<RouteSample> samples;
  final List<int> waypointIndices;
  final double spacing;
  factory RouteSamplingPlan.create(
    List<RouteWaypointInput> points, {
    double spacing = 50,
  }) {
    if (points.length < 2 ||
        points.length > 1000 ||
        !spacing.isFinite ||
        spacing < 5 ||
        spacing > 100) {
      throw ArgumentError('Use 2–1000 waypoints and 5–100 m sampling');
    }
    final samples = <RouteSample>[RouteSample(points.first.position, 0, 0, 0)];
    final indices = <int>[0];
    var distance = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position, b = points[i + 1].position;
      for (final p in [a, b]) {
        if (!p.latitude.isFinite ||
            !p.longitude.isFinite ||
            p.latitude.abs() > 90 ||
            p.longitude.abs() > 180) {
          throw ArgumentError('Invalid route coordinates');
        }
      }
      final length = routeDistance(a, b);
      final count = math.max(1, (length / spacing).ceil());
      if (samples.length + count > 4096) {
        throw ArgumentError(
          'Route exceeds the 4096-sample limit at $spacing m. Split it into shorter routes.',
        );
      }
      for (var step = 1; step <= count; step++) {
        samples.add(
          RouteSample(
            step == count ? b : _interpolate(a, b, step / count),
            i,
            step / count,
            distance + length * step / count,
          ),
        );
      }
      distance += length;
      indices.add(samples.length - 1);
    }
    return RouteSamplingPlan._(
      List.unmodifiable(samples),
      List.unmodifiable(indices),
      spacing,
    );
  }
}

class RouteProfilePoint {
  const RouteProfilePoint(this.sample, this.ground, this.altitude);
  final RouteSample sample;
  final double? ground, altitude;
  double? get clearance =>
      ground == null || altitude == null ? null : altitude! - ground!;
}

class RouteSegmentEstimate {
  const RouteSegmentEstimate({
    required this.index,
    required this.horizontal,
    required this.bearing,
    this.spatial,
    this.heightChange,
    this.seconds,
    this.returnSeconds,
    this.speed,
    this.minimumClearance,
  });
  final int index;
  final double horizontal, bearing;
  final double? spatial,
      heightChange,
      seconds,
      returnSeconds,
      speed,
      minimumClearance;
}

class RouteAnalysis {
  RouteAnalysis._(this.profile, this.segments, this.terrainAvailable);
  final List<RouteProfilePoint> profile;
  final List<RouteSegmentEstimate> segments;
  final bool terrainAvailable;
  double get horizontalDistance => segments.fold(0, (n, s) => n + s.horizontal);
  double? _total(double? Function(RouteSegmentEstimate) read) {
    final values = segments.map(read).toList();
    return values.any((v) => v == null)
        ? null
        : values.fold<double>(0, (n, v) => n + v!);
  }

  double? get spatialDistance => _total((s) => s.spatial);
  double? get seconds => _total((s) => s.seconds);
  double? get climb => _total(
    (s) => s.heightChange == null ? null : math.max(0, s.heightChange!),
  );
  double? get descent => _total(
    (s) => s.heightChange == null ? null : math.max(0, -s.heightChange!),
  );
  bool get completeClearance =>
      terrainAvailable && profile.every((p) => p.clearance != null);
  double? get minimumClearance => !completeClearance
      ? null
      : profile.map((p) => p.clearance!).reduce(math.min);

  factory RouteAnalysis.calculate(
    List<RouteWaypointInput> points,
    RouteSamplingPlan plan,
    List<double>? groundHeights,
    RoutePlanningSettings settings,
  ) {
    settings.validate();
    if (groundHeights != null &&
        (groundHeights.length != plan.samples.length ||
            groundHeights.any((h) => !h.isFinite))) {
      throw ArgumentError('Incomplete terrain heights');
    }
    if (points.length != plan.waypointIndices.length) {
      throw ArgumentError('Sampling plan does not match route');
    }
    for (var i = 0; i < points.length; i++) {
      final p = points[i],
          sample = plan.samples[plan.waypointIndices[i]].position;
      if (p.position.latitude != sample.latitude ||
          p.position.longitude != sample.longitude) {
        throw ArgumentError('Sampling plan does not match route positions');
      }
      final h = p.height, speed = p.speedMetersPerSecond;
      if (h != null &&
          (!h.meters.isFinite ||
              h.meters.abs() > 100000 ||
              (h is AglWaypointHeight && h.meters < 0))) {
        throw ArgumentError('Invalid waypoint height');
      }
      if (speed != null && (!speed.isFinite || speed <= 0 || speed > 200)) {
        throw ArgumentError('Invalid planned airspeed');
      }
    }
    double? ground(int index) => groundHeights?[index];
    final altitudes = <double?>[
      for (var i = 0; i < points.length; i++)
        switch (points[i].height) {
          AglWaypointHeight(:final height) =>
            ground(plan.waypointIndices[i]) == null
                ? null
                : ground(plan.waypointIndices[i])! + height.meters,
          AbsoluteWaypointHeight(:final elevation)
              when elevation.reference == VerticalReference.wgs84Ellipsoid =>
            elevation.meters,
          _ => null,
        },
    ];
    final profile = <RouteProfilePoint>[];
    for (var i = 0; i < plan.samples.length; i++) {
      final s = plan.samples[i],
          a = altitudes[s.segment],
          b = altitudes[s.segment + 1];
      profile.add(
        RouteProfilePoint(
          s,
          ground(i),
          s.fraction == 0
              ? a
              : s.fraction == 1
              ? b
              : a == null || b == null
              ? null
              : a + (b - a) * s.fraction,
        ),
      );
    }
    final segments = <RouteSegmentEstimate>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final horizontal = routeDistance(a.position, b.position),
          bearing = _bearing(a.position, b.position);
      final delta = altitudes[i] == null || altitudes[i + 1] == null
          ? null
          : altitudes[i + 1]! - altitudes[i]!;
      final distance = delta == null
          ? null
          : math.sqrt(horizontal * horizontal + delta * delta);
      final clearance = profile
          .sublist(plan.waypointIndices[i], plan.waypointIndices[i + 1] + 1)
          .map((p) => p.clearance)
          .toList();
      segments.add(
        RouteSegmentEstimate(
          index: i,
          horizontal: horizontal,
          bearing: bearing,
          spatial: distance,
          heightChange: delta,
          speed: a.speedMetersPerSecond,
          seconds: _duration(
            horizontal,
            distance,
            bearing,
            a.speedMetersPerSecond,
            settings,
          ),
          returnSeconds: _duration(
            horizontal,
            distance,
            _bearing(b.position, a.position),
            a.speedMetersPerSecond,
            settings,
          ),
          minimumClearance: clearance.any((v) => v == null)
              ? null
              : clearance.cast<double>().reduce(math.min),
        ),
      );
    }
    return RouteAnalysis._(
      List.unmodifiable(profile),
      List.unmodifiable(segments),
      groundHeights != null,
    );
  }

  /// Steady horizontal wind; speed denotes airspeed along the 3D track.
  /// The air vector compensates crosswind. Impossible tracks stay unknown.
  static double? _duration(
    double horizontal,
    double? spatial,
    double bearing,
    double? speed,
    RoutePlanningSettings settings,
  ) {
    if (spatial == null) return null;
    if (spatial == 0) return 0;
    if (speed == null || !speed.isFinite || speed <= 0) return null;
    if (!settings.useWind || settings.windSpeed == 0) return spatial / speed;
    final along =
        -settings.windSpeed *
        math.cos(_radians(settings.windFromDegrees) - bearing) *
        horizontal /
        spatial;
    final crossSquared = math.max(
      0,
      settings.windSpeed * settings.windSpeed - along * along,
    );
    final available = speed * speed - crossSquared;
    if (available <= 0) return null;
    final groundSpeed = math.sqrt(available) + along;
    return groundSpeed > .01 ? spatial / groundSpeed : null;
  }
}
