import 'flight_route.dart';

class ImportedRoute {
  ImportedRoute(this.name, List<RouteWaypointInput> points)
    : points = List.unmodifiable(points);
  final String name;
  final List<RouteWaypointInput> points;
}

class RouteImportPreview {
  RouteImportPreview(List<ImportedRoute> routes, List<String> warnings)
    : routes = List.unmodifiable(routes),
      warnings = List.unmodifiable(warnings);
  final List<ImportedRoute> routes;
  final List<String> warnings;
}

enum RouteFileFormat { geoJson, gpx }
