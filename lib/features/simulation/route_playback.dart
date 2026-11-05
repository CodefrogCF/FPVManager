import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
import '../../core/models/route_planning_settings.dart';
import 'simulation_settings.dart';

/// Wire-format for a bounded, virtual-only Cesium flight replay.
/// Height values with an unsupported datum are rejected rather than guessed.
class RoutePlaybackRequest {
  RoutePlaybackRequest(FlightRoute route, SimulationSettings settings)
    : command = _build(route, settings);

  final Map<String, dynamic> command;

  static Map<String, dynamic> _build(
    FlightRoute route,
    SimulationSettings settings,
  ) {
    settings.validate();
    final waypoints = route.waypoints;
    if (waypoints.length < 2 || waypoints.length > 1000) {
      throw const FormatException('Replay requires 2–1000 route points');
    }
    final points = <Map<String, dynamic>>[];
    for (final waypoint in waypoints) {
      final position = waypoint.position;
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() >= 89.9 ||
          position.longitude.abs() > 180) {
        throw const FormatException('Replay contains invalid coordinates');
      }
      final height = waypoint.height;
      String mode = 'unspecified';
      double? meters;
      if (height is AglWaypointHeight) {
        mode = 'agl';
        meters = height.meters;
        if (!meters.isFinite || meters < 0 || meters > 10000) {
          throw const FormatException('Invalid route AGL height');
        }
      } else if (height is AbsoluteWaypointHeight) {
        final elevation = height.elevation;
        if (elevation.reference != VerticalReference.wgs84Ellipsoid) {
          throw const FormatException(
            'Only WGS84 ellipsoid heights can be replayed. Convert this '
            'route explicitly before playback.',
          );
        }
        mode = 'absolute';
        meters = elevation.meters;
        if (!meters.isFinite || meters.abs() > 100000) {
          throw const FormatException('Invalid absolute route height');
        }
      }
      final speed = waypoint.speedMetersPerSecond;
      if (speed != null && (!speed.isFinite || speed < 0 || speed > 200)) {
        throw const FormatException('Invalid planned route speed');
      }
      points.add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heightMode': mode,
        if (meters != null) 'heightMeters': meters,
        if (speed != null) 'speedMetersPerSecond': speed,
      });
    }
    final stored = RoutePlanningSettings.decode(route.plan.planningJson)
        .recordedTrack;
    final recorded = route.recordedTrack;
    if (stored != null && recorded == null) {
      throw const FormatException(
        'Recorded telemetry no longer matches the route waypoints. '
        'Review the route before replay.',
      );
    }
    if (recorded != null) {
      recorded.validate();
    }
    return {
      'type': 'start-route-playback',
      'routeId': route.plan.id,
      'routeName': route.plan.name.length > 120
          ? route.plan.name.substring(0, 120)
          : route.plan.name,
      'settings': settings.toCommand(),
      'defaultSpeedMetersPerSecond': settings.maxSpeed,
      'defaultAglMeters': settings.agl,
      'points': points,
      if (recorded != null)
        'recorded': [
          for (final sample in recorded.samples)
            {
              'seconds': sample.seconds,
              'absoluteElevationMeters': sample.absoluteElevationMeters,
              if (sample.terrainElevationMeters != null)
                'terrainElevationMeters': sample.terrainElevationMeters,
              if (sample.groundSpeedMetersPerSecond != null)
                'groundSpeedMetersPerSecond': sample.groundSpeedMetersPerSecond,
            },
        ],
    };
  }
}
