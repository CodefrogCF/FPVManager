import '../../core/geo/geo_coordinate_service.dart';

class RouteMapPoint {
  const RouteMapPoint(this.id, this.position);
  final int id;
  final Wgs84Coordinate position;
  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': position.latitude,
    'longitude': position.longitude,
  };
}

/// Display-only terrain-relative geometry; stored route heights stay separate.
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
