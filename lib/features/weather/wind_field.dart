enum WindTimeMode { current, forecast }

class WindLevel {
  const WindLevel(this.agl, this.speedMs, this.fromDegrees);
  final double agl, speedMs, fromDegrees;
  Map<String, dynamic> toJson() => {
    'agl': agl,
    'speedMs': speedMs,
    'fromDegrees': fromDegrees,
  };
}

class WindNode {
  const WindNode({
    required this.latitude,
    required this.longitude,
    required this.levels,
    this.sourceLatitude,
    this.sourceLongitude,
  });
  final double latitude, longitude;
  final double? sourceLatitude, sourceLongitude;
  final List<WindLevel> levels;
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'sourceLatitude': sourceLatitude,
    'sourceLongitude': sourceLongitude,
    'levels': levels.map((l) => l.toJson()).toList(),
  };
}

/// A bounded model snapshot; neither the display grid nor animation is a survey.
class WindFieldSnapshot {
  const WindFieldSnapshot({
    required this.mode,
    required this.validAtUtc,
    required this.retrievedUtc,
    required this.expiresUtc,
    required this.nodes,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
  });
  final WindTimeMode mode;
  final DateTime validAtUtc, retrievedUtc, expiresUtc;
  final List<WindNode> nodes;
  final double centerLatitude, centerLongitude, radiusMeters;
  bool expiredAt(DateTime now) => !now.toUtc().isBefore(expiresUtc);
  int get usableNodes => nodes.where((n) => n.levels.isNotEmpty).length;
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'validAtUtc': validAtUtc.toUtc().toIso8601String(),
    'retrievedUtc': retrievedUtc.toUtc().toIso8601String(),
    'expiresUtc': expiresUtc.toUtc().toIso8601String(),
    'source': 'Open-Meteo · CC BY 4.0 · model wind',
    'centerLatitude': centerLatitude,
    'centerLongitude': centerLongitude,
    'radiusMeters': radiusMeters,
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };
}
