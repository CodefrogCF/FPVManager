import '../geo/geo_coordinate_service.dart';

/// Optional local site observations, never an automatically assumed canopy.
class SurfaceObservation {
  const SurfaceObservation({
    required this.position,
    required this.height,
    required this.radius,
    required this.kind,
    required this.source,
  });
  final Wgs84Coordinate position;
  final double height, radius;
  final String kind, source;
  Map<String, Object> toJson() => {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'height': height,
    'radius': radius,
    'kind': kind,
    'source': source,
  };
  factory SurfaceObservation.fromJson(Map<String, dynamic> j) =>
      SurfaceObservation(
        position: Wgs84Coordinate(
          latitude: (j['latitude'] as num).toDouble(),
          longitude: (j['longitude'] as num).toDouble(),
        ),
        height: (j['height'] as num).toDouble(),
        radius: (j['radius'] as num).toDouble(),
        kind: j['kind'] as String,
        source: j['source'] as String,
      );
}

class SignalSettings {
  const SignalSettings({
    required this.pilot,
    this.antennaHeight = 2,
    this.frequencyMhz = 5800,
    this.clearanceFraction = .6,
    this.useSurfaces = false,
    this.surfaces = const [],
  });
  final Wgs84Coordinate pilot;
  final double antennaHeight, frequencyMhz, clearanceFraction;
  final bool useSurfaces;
  final List<SurfaceObservation> surfaces;
  void validate() {
    void range(double v, double low, double high) {
      if (!v.isFinite || v < low || v > high) {
        throw ArgumentError('Invalid signal analysis settings');
      }
    }

    void position(Wgs84Coordinate p) {
      range(p.latitude, -90, 90);
      range(p.longitude, -180, 180);
    }

    position(pilot);
    range(antennaHeight, .1, 100);
    range(frequencyMhz, 10, 100000);
    range(clearanceFraction, 0, 1);
    if (surfaces.length > 100) {
      throw ArgumentError('Use at most 100 surface observations');
    }
    for (final s in surfaces) {
      position(s.position);
      range(s.height, 0, 1000);
      range(s.radius, 1, 1000);
      if (!['building', 'vegetation', 'other'].contains(s.kind) ||
          s.source.trim().isEmpty ||
          s.source.length > 160) {
        throw ArgumentError('Surface observations need a kind and source');
      }
    }
  }

  Map<String, Object> toJson() {
    validate();
    return {
      'version': 1,
      'latitude': pilot.latitude,
      'longitude': pilot.longitude,
      'antennaHeight': antennaHeight,
      'frequencyMhz': frequencyMhz,
      'clearanceFraction': clearanceFraction,
      'useSurfaces': useSurfaces,
      'surfaces': surfaces.map((s) => s.toJson()).toList(),
    };
  }

  factory SignalSettings.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported signal settings');
    }
    final s = SignalSettings(
      pilot: Wgs84Coordinate(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      ),
      antennaHeight: (j['antennaHeight'] as num).toDouble(),
      frequencyMhz: (j['frequencyMhz'] as num).toDouble(),
      clearanceFraction: (j['clearanceFraction'] as num).toDouble(),
      useSurfaces: j['useSurfaces'] as bool,
      surfaces: List.unmodifiable(
        (j['surfaces'] as List).map(
          (v) => SurfaceObservation.fromJson(v as Map<String, dynamic>),
        ),
      ),
    );
    s.validate();
    return s;
  }
}
