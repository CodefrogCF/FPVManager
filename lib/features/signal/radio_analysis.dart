import 'dart:math' as math;

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
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

const radioMapPageSize = 128;
const radioMaximumPathMeters = 50000;

RouteSamplingPlan? _radioLinkPlan(
  SignalSettings settings,
  RouteProfilePoint target,
) {
  if (target.altitude == null) return null;
  final distance = routeDistance(settings.pilot, target.sample.position);
  if (distance < 1 || distance > radioMaximumPathMeters) return null;
  return RouteSamplingPlan.create([
    RouteWaypointInput(position: settings.pilot),
    RouteWaypointInput(position: target.sample.position),
  ], spacing: 25);
}

/// Bound peak terrain and isolate memory independently of route waypoint count.
class RadioAnalysisBatch {
  const RadioAnalysisBatch._(this.targets, this.positions, this.offsets);

  final List<RouteProfilePoint> targets;
  final List<Wgs84Coordinate> positions;
  final List<int> offsets;

  static Iterable<RadioAnalysisBatch> forRoute(
    List<RouteProfilePoint> route,
    SignalSettings settings,
  ) sync* {
    var targets = <RouteProfilePoint>[];
    var positions = <Wgs84Coordinate>[];
    var offsets = <int>[0];
    for (final target in route) {
      final path = _radioLinkPlan(settings, target);
      final count = path == null ? 0 : path.samples.length - 2;
      if (targets.length == radioMapPageSize ||
          positions.length + count > 16384) {
        yield RadioAnalysisBatch._(targets, positions, offsets);
        targets = [];
        positions = [];
        offsets = [0];
      }
      targets.add(target);
      if (path != null) {
        positions.addAll(
          path.samples.skip(1).take(count).map((p) => p.position),
        );
      }
      offsets.add(positions.length);
    }
    if (targets.isNotEmpty) {
      yield RadioAnalysisBatch._(targets, positions, offsets);
    }
  }

  List<RadioPathResult> calculate(
    SignalSettings settings,
    double pilotGround,
    List<double> heights, {
    bool includeProfiles = false,
  }) {
    if (positions.length != heights.length) {
      throw ArgumentError('Incomplete terrain profile');
    }
    final results = <RadioPathResult>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i], position = target.sample.position;
      final distance = routeDistance(settings.pilot, position);
      if (target.altitude == null ||
          distance < 1 ||
          distance > radioMaximumPathMeters) {
        results.add(
          RadioPathResult(
            target: position,
            altitude: target.altitude,
            state: RadioPathState.unknown,
          ),
        );
        continue;
      }
      results.add(
        calculateRadioLink(
          settings: settings,
          target: position,
          altitude: target.altitude!,
          pilotHeight: pilotGround + settings.antennaHeight,
          positions: [
            settings.pilot,
            ...positions.getRange(offsets[i], offsets[i + 1]),
            position,
          ],
          heights: [
            pilotGround,
            ...heights.getRange(offsets[i], offsets[i + 1]),
            target.ground!,
          ],
          includeProfile: includeProfiles,
        ),
      );
    }
    return results;
  }
}

List<RadioPathResult> calculateRadioBatch(
  (RadioAnalysisBatch, SignalSettings, double, List<double>, bool) request,
) => request.$1.calculate(
  request.$2,
  request.$3,
  request.$4,
  includeProfiles: request.$5,
);

/// Shared single-link kernel for route planning and live simulation.
RadioPathResult calculateRadioLink({
  required SignalSettings settings,
  required Wgs84Coordinate target,
  required double altitude,
  required double pilotHeight,
  required List<Wgs84Coordinate> positions,
  required List<double> heights,
  bool includeProfile = true,
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
    if (includeProfile) {
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
