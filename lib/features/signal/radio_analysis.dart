import 'dart:math' as math;

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
import '../../core/models/route_planning_settings.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';

enum RadioPathState {
  unknown,
  obstructed,
  fresnelIntrusion,
  noSampledObstruction,
}

class RadioPathSample {
  const RadioPathSample(
    this.position,
    this.ground,
    this.surface,
    this.lineHeight,
    this.radius,
    this.clearance,
  );
  final Wgs84Coordinate position;
  final double ground, surface, lineHeight, radius, clearance;
}

class RadioPathResult {
  const RadioPathResult({
    required this.target,
    required this.state,
    this.altitude,
    this.minimumClearance,
    this.minimumFresnelClearance,
    this.profile = const [],
  });
  final Wgs84Coordinate target;
  final RadioPathState state;
  final double? altitude, minimumClearance, minimumFresnelClearance;
  final List<RadioPathSample> profile;
}

/// A bounded set of route targets and communication profiles, in WGS84.
class RadioAnalysisPlan {
  RadioAnalysisPlan._(
    this.points,
    this.settings,
    this.route,
    this.positions,
    this.paths,
  );
  final List<RouteWaypointInput> points;
  final SignalSettings settings;
  final RouteSamplingPlan route;
  final List<Wgs84Coordinate> positions;
  final List<List<int>> paths;
  factory RadioAnalysisPlan.create(
    List<RouteWaypointInput> points,
    SignalSettings settings,
  ) {
    settings.validate();
    settings = SignalSettings.fromJson(settings.toJson());
    final route = RouteSamplingPlan.create(points, spacing: 100);
    if (route.samples.length > 128) {
      throw ArgumentError(
        'Signal analysis supports up to 128 route targets at 100 m. Split this route.',
      );
    }
    final positions = <Wgs84Coordinate>[
      settings.pilot,
      ...route.samples.map((s) => s.position),
    ];
    final paths = <List<int>>[];
    for (var i = 0; i < route.samples.length; i++) {
      final target = route.samples[i].position;
      if (routeDistance(settings.pilot, target) > 50000) {
        throw ArgumentError('Communication paths must be shorter than 50 km');
      }
      final path = RouteSamplingPlan.create([
        RouteWaypointInput(position: settings.pilot),
        RouteWaypointInput(position: target),
      ], spacing: 25);
      if (positions.length + path.samples.length - 2 > 16384) {
        throw ArgumentError(
          'Signal analysis exceeds 16384 terrain samples. Split this route.',
        );
      }
      final indices = <int>[0];
      for (final sample in path.samples.skip(1).take(path.samples.length - 2)) {
        indices.add(positions.length);
        positions.add(sample.position);
      }
      indices.add(i + 1);
      paths.add(List.unmodifiable(indices));
    }
    return RadioAnalysisPlan._(
      List.unmodifiable(points),
      settings,
      route,
      List.unmodifiable(positions),
      List.unmodifiable(paths),
    );
  }
  List<RadioPathResult> calculate(List<double> heights) {
    if (heights.length != positions.length ||
        heights.any((h) => !h.isFinite || h.abs() > 100000)) {
      throw ArgumentError('Incomplete terrain profile');
    }
    final routeResult = RouteAnalysis.calculate(
      points,
      route,
      heights.sublist(1, route.samples.length + 1),
      const RoutePlanningSettings(),
    );
    final pilotHeight = heights[0] + settings.antennaHeight;
    return List.unmodifiable([
      for (var i = 0; i < paths.length; i++)
        _calculatePath(
          i,
          heights,
          routeResult.profile[i].altitude,
          pilotHeight,
        ),
    ]);
  }

  RadioPathResult _calculatePath(
    int index,
    List<double> heights,
    double? altitude,
    double pilotHeight,
  ) {
    final target = route.samples[index].position;
    if (altitude == null || routeDistance(settings.pilot, target) < 1) {
      return RadioPathResult(
        target: target,
        altitude: altitude,
        state: RadioPathState.unknown,
      );
    }
    return calculateRadioLink(
      settings: settings,
      target: target,
      altitude: altitude,
      pilotHeight: pilotHeight,
      positions: [for (final i in paths[index]) positions[i]],
      heights: [for (final i in paths[index]) heights[i]],
    );
  }
}

/// Shared single-link kernel for route planning and live simulation.
RadioPathResult calculateRadioLink({
  required SignalSettings settings,
  required Wgs84Coordinate target,
  required double altitude,
  required double pilotHeight,
  required List<Wgs84Coordinate> positions,
  required List<double> heights,
}) {
  settings.validate();
  bool validPosition(Wgs84Coordinate p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180;
  if (!validPosition(target) || positions.any((p) => !validPosition(p))) {
    throw ArgumentError('Invalid radio coordinates');
  }
  if (positions.length < 2 ||
      positions.length != heights.length ||
      positions.length > 4096 ||
      heights.any((h) => !h.isFinite || h.abs() > 100000) ||
      !altitude.isFinite ||
      altitude.abs() > 100000 ||
      !pilotHeight.isFinite ||
      pilotHeight.abs() > 100000) {
    throw ArgumentError('Incomplete radio path');
  }
  if (routeDistance(settings.pilot, target) < 1) {
    return RadioPathResult(
      target: target,
      altitude: altitude,
      state: RadioPathState.unknown,
    );
  }
  final a = _ecef(settings.pilot, pilotHeight),
      b = _ecef(target, altitude),
      delta = b - a,
      length = delta.length,
      direction = delta * (1 / length);
  final samples = <RadioPathSample>[];
  var minimum = double.infinity, fresnelMinimum = double.infinity;
  for (var i = 0; i < positions.length; i++) {
    final t = i / (positions.length - 1), p = positions[i], ground = heights[i];
    var surface = ground;
    if (settings.useSurfaces) {
      for (final s in settings.surfaces) {
        if (routeDistance(p, s.position) <= s.radius) {
          surface = math.max(surface, ground + s.height);
        }
      }
    }
    final up = _up(p), line = a + delta * t;
    final verticalClearance = (line - _ecef(p, surface)).dot(up);
    final perpendicularScale = math.sqrt(
      math.max(0, 1 - math.pow(up.dot(direction), 2)),
    );
    final clearance = verticalClearance * perpendicularScale;
    final radius = fresnelRadius(
      settings.frequencyMhz,
      length * t,
      length * (1 - t),
    );
    minimum = math.min(minimum, clearance);
    fresnelMinimum = math.min(
      fresnelMinimum,
      clearance - settings.clearanceFraction * radius,
    );
    samples.add(
      RadioPathSample(
        p,
        ground,
        surface,
        surface + verticalClearance,
        radius,
        clearance,
      ),
    );
  }
  return RadioPathResult(
    target: target,
    altitude: altitude,
    state: minimum <= 0
        ? RadioPathState.obstructed
        : fresnelMinimum <= 0
        ? RadioPathState.fresnelIntrusion
        : RadioPathState.noSampledObstruction,
    minimumClearance: minimum,
    minimumFresnelClearance: fresnelMinimum,
    profile: List.unmodifiable(samples),
  );
}

List<RadioPathResult> calculateRadioAnalysis(
  (RadioAnalysisPlan, List<double>) request,
) => request.$1.calculate(request.$2);

/// First-zone radius, SI units, ITU-R P.526 Annex 1 equation (2), n=1.
double fresnelRadius(double frequencyMhz, double d1, double d2) {
  if (!frequencyMhz.isFinite ||
      frequencyMhz <= 0 ||
      !d1.isFinite ||
      !d2.isFinite ||
      d1 < 0 ||
      d2 < 0) {
    throw ArgumentError('Invalid Fresnel inputs');
  }
  if (d1 + d2 == 0) return 0;
  return math.sqrt(299792458 / (frequencyMhz * 1000000) * d1 * d2 / (d1 + d2));
}

class _Vector {
  const _Vector(this.x, this.y, this.z);
  final double x, y, z;
  _Vector operator +(_Vector v) => _Vector(x + v.x, y + v.y, z + v.z);
  _Vector operator -(_Vector v) => _Vector(x - v.x, y - v.y, z - v.z);
  _Vector operator *(double s) => _Vector(x * s, y * s, z * s);
  double dot(_Vector v) => x * v.x + y * v.y + z * v.z;
  double get length => math.sqrt(dot(this));
}

_Vector _up(Wgs84Coordinate p) {
  final lat = p.latitude * math.pi / 180, lon = p.longitude * math.pi / 180;
  return _Vector(
    math.cos(lat) * math.cos(lon),
    math.cos(lat) * math.sin(lon),
    math.sin(lat),
  );
}

_Vector _ecef(Wgs84Coordinate p, double height) {
  final lat = p.latitude * math.pi / 180, lon = p.longitude * math.pi / 180;
  const e2 = 6.6943799901413165e-3;
  final n = 6378137 / math.sqrt(1 - e2 * math.pow(math.sin(lat), 2));
  return _Vector(
    (n + height) * math.cos(lat) * math.cos(lon),
    (n + height) * math.cos(lat) * math.sin(lon),
    (n * (1 - e2) + height) * math.sin(lat),
  );
}
