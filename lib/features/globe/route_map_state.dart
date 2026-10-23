import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';

class RouteMapPoint {
  const RouteMapPoint(
    this.id,
    this.position, {
    this.height,
    this.critical = false,
  });
  final int id;
  final Wgs84Coordinate position;
  final WaypointHeight? height;
  final bool critical;
  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': position.latitude,
    'longitude': position.longitude,
    if (height != null)
      'height': {
        'meters': height!.meters,
        'reference': switch (height!) {
          AglWaypointHeight() => 'aboveGroundLevel',
          AbsoluteWaypointHeight(:final elevation) => elevation.reference.name,
        },
      },
    if (critical) 'critical': true,
  };
}

/// Configured heights are shown where compatible with the terrain reference.
class VisibleMapRoute {
  VisibleMapRoute({
    required this.id,
    required this.name,
    required List<RouteMapPoint> points,
  }) : points = List.unmodifiable(points);
  final int id;
  final String name;
  final List<RouteMapPoint> points;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'waypoints': points.map((p) => p.toJson()).toList(),
  };
}

enum RouteMapActionKind { add, select, move, delete }

class RouteMapAction {
  const RouteMapAction(this.kind, {this.id, this.position});
  final RouteMapActionKind kind;
  final int? id;
  final Wgs84Coordinate? position;
}
