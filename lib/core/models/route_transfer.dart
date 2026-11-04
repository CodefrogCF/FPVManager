import 'flight_route.dart';
import 'recorded_route_track.dart';

class ImportedRoute {
  ImportedRoute(
    this.name,
    List<RouteWaypointInput> points, {
    this.recordedTrack,
  }) : points = List.unmodifiable(points);
  final String name;
  final List<RouteWaypointInput> points;
  final RecordedRouteTrack? recordedTrack;
}

class RouteImportPreview {
  RouteImportPreview(List<ImportedRoute> routes, List<String> warnings)
    : routes = List.unmodifiable(routes),
      warnings = List.unmodifiable(warnings);
  final List<ImportedRoute> routes;
  final List<String> warnings;
}

enum RouteFileFormat { geoJson, gpx }
