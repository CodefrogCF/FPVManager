import '../database/fpv_database.dart' show FlightPlan;
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
  const RouteWaypointInput({required this.position, this.height});

  final Wgs84Coordinate position;
  final WaypointHeight? height;
}

class RouteWaypoint {
  const RouteWaypoint({
    required this.id,
    required this.planId,
    required this.sequenceNumber,
    required this.position,
    required this.height,
  });

  final int id;
  final int planId;
  final int sequenceNumber;
  final Wgs84Coordinate position;
  final WaypointHeight? height;
}

/// One immutable snapshot of route metadata and its ordered waypoints.
class FlightRoute {
  FlightRoute({required this.plan, required List<RouteWaypoint> waypoints})
    : waypoints = List.unmodifiable(waypoints);

  final FlightPlan plan;
  final List<RouteWaypoint> waypoints;
}
