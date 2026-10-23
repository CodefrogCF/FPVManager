import '../database/fpv_database.dart' show FlightPlan, Battery;
import 'drone_profile.dart';
import '../geo/altitude_service.dart';
import '../geo/geo_coordinate_service.dart';

/// Absolute datum heights and terrain-relative AGL offsets are different inputs.
sealed class WaypointHeight {
  const WaypointHeight();

  double get meters;
}

final class AbsoluteWaypointHeight extends WaypointHeight {
  const AbsoluteWaypointHeight(this.elevation);

  final ReferencedElevation elevation;

  @override
  double get meters => elevation.meters;
}

final class AglWaypointHeight extends WaypointHeight {
  const AglWaypointHeight(this.height);

  final AboveGroundHeight height;

  @override
  double get meters => height.meters;
}

/// A point without height remains position-only; no datum or zero is inferred.
class RouteWaypointInput {
  const RouteWaypointInput({
    required this.position,
    this.height,
    this.speedMetersPerSecond,
  });

  final Wgs84Coordinate position;
  final WaypointHeight? height;

  /// Planned airspeed for the segment leaving this waypoint. Null is unknown.
  final double? speedMetersPerSecond;
}

class RouteWaypoint {
  const RouteWaypoint({
    required this.id,
    required this.planId,
    required this.sequenceNumber,
    required this.position,
    required this.height,
    this.speedMetersPerSecond,
  });

  final int id;
  final int planId;
  final int sequenceNumber;
  final Wgs84Coordinate position;
  final WaypointHeight? height;
  final double? speedMetersPerSecond;
}

/// One immutable snapshot of route metadata and its ordered waypoints.
class FlightRoute {
  FlightRoute({
    required this.plan,
    required List<RouteWaypoint> waypoints,
    Set<int> batteryIds = const {},
  }) : waypoints = List.unmodifiable(waypoints),
       batteryIds = Set.unmodifiable(batteryIds);

  final FlightPlan plan;
  final List<RouteWaypoint> waypoints;

  /// Alternative packs for this flight; capacities must not be added together.
  final Set<int> batteryIds;
}

class RouteEquipmentOptions {
  const RouteEquipmentOptions({required this.drones, required this.batteries});
  final List<DroneProfile> drones;
  final List<Battery> batteries;
}
