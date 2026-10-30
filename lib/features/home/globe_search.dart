import '../../core/geo/geo_coordinate_service.dart';
import '../mobility/destination_search.dart';
import '../mobility/road_routing.dart';

/// Numeric input is parsed locally, including invalid coordinates. It is never
/// sent to the address service. Swiss coordinates use approximate conversion.
RoadDestination? parseGlobeCoordinates(String input) {
  var value = input.trim();
  if (value.length > 200) {
    throw const FormatException('Bitte höchstens 200 Zeichen eingeben.');
  }
  final lv95 = RegExp(r'^LV95\b', caseSensitive: false).hasMatch(value);
  final wgs84 = RegExp(r'^WGS84\b', caseSensitive: false).hasMatch(value);
  value = value.replaceFirst(
    RegExp(r'^(?:LV95|WGS84)\s*:?\s*', caseSensitive: false),
    '',
  );
  if (!lv95 && !wgs84 && !RegExp(r"^[\d\s.,;/+'’−-]+$").hasMatch(value)) {
    return null;
  }
  List<String> parts;
  if (value.contains(';') || value.contains('/')) {
    parts = value.split(RegExp(r'[;/]'));
  } else if (value.contains(',') && value.split(',').length == 2) {
    parts = value.split(',');
  } else {
    parts = value.split(RegExp(r'\s+'));
    if (parts.length == 6 && (lv95 || parts.first == '2')) {
      parts = [parts.take(3).join(), parts.skip(3).join()];
    }
  }
  if (parts.length != 2) {
    throw const FormatException(
      'Koordinatenpaar unklar. WGS84: 46.7, 8.4 · LV95: 2600000 / 1200000',
    );
  }
  double number(String part) =>
      double.tryParse(
        part
            .trim()
            .replaceAll(RegExp(r"[\s'’]"), '')
            .replaceAll(',', '.')
            .replaceAll('−', '-'),
      ) ??
      double.nan;
  final a = number(parts[0]), b = number(parts[1]);
  if (!a.isFinite || !b.isFinite) {
    throw const FormatException('Ungültige Koordinaten.');
  }
  final swiss = lv95 || !wgs84 && a >= 2400000 && b >= 1000000;
  if (swiss) {
    const converter = GeoCoordinateService();
    final coordinate = Lv95Coordinate(easting: a, northing: b);
    if (!converter.supportsLv95(coordinate)) {
      throw const FormatException(
        'LV95 liegt außerhalb des unterstützten Schweizer Bereichs.',
      );
    }
    final wgs = converter.lv95ToWgs84(coordinate);
    return RoadDestination(
      'LV95 · ${a.toStringAsFixed(0)} / ${b.toStringAsFixed(0)} (ca.)',
      MobilityPoint(wgs.latitude, wgs.longitude),
    );
  }
  if (a.abs() > 90 || b.abs() > 180) {
    throw const FormatException(
      'WGS84: Breite −90…90, Länge −180…180. Reihenfolge: Breite, Länge.',
    );
  }
  return RoadDestination(
    'WGS84 · ${a.toStringAsFixed(6)}, ${b.toStringAsFixed(6)}',
    MobilityPoint(a, b),
  );
}

/// Coalesces identical in-flight requests without retaining search history.
class GlobeSearch {
  GlobeSearch({DestinationSearch? destinations})
    : _destinations = destinations ?? DestinationSearch(),
      _owns = destinations == null;
  final DestinationSearch _destinations;
  final bool _owns;
  final Map<String, Future<List<RoadDestination>>> _pending = {};
  bool _disposed = false;
  Future<List<RoadDestination>> search(String input) async {
    if (_disposed) throw StateError('Search disposed');
    final local = parseGlobeCoordinates(input);
    if (local != null) return [local];
    final query = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    final existing = _pending[query];
    if (existing != null) return existing;
    if (_pending.length >= 8) throw StateError('Too many pending searches');
    final operation = _destinations.search(query);
    _pending[query] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_pending[query], operation)) {
        _pending.remove(query);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    if (_owns) _destinations.dispose();
  }
}
