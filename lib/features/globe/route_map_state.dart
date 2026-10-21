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

enum RouteMapActionKind { add, select, move, delete }

class RouteMapAction {
  const RouteMapAction(this.kind, {this.id, this.position});
  final RouteMapActionKind kind;
  final int? id;
  final Wgs84Coordinate? position;
}
