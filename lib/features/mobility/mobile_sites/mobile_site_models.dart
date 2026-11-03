import 'dart:convert';
import 'dart:math' as math;

import '../../../core/geo/geo_coordinate_service.dart';

const mobileSiteCollectionId = 'ch.bakom.standorte-mobilfunkanlagen';
const mobileSiteSource = 'Bundesamt für Kommunikation BAKOM / geo.admin.ch';

/// The coordinate of the first mast at a *station*, not a measured antenna
/// position or known object height. No mast geometry is inferred.
class MobileSite {
  const MobileSite({
    required this.id,
    required this.station,
    required this.latitude,
    required this.longitude,
    this.sourceEasting,
    this.sourceNorthing,
    this.type,
    this.technology,
    this.powerClass,
    this.adaptive,
  });
  final String id, station;
  final double latitude, longitude;
  final double? sourceEasting, sourceNorthing;
  final String? type, technology, powerClass, adaptive;
  double? get objectHeightMeters => null;

  Map<String, Object?> toJson() => {
    'id': id,
    'station': station,
    'latitude': latitude,
    'longitude': longitude,
    'sourceEasting': sourceEasting,
    'sourceNorthing': sourceNorthing,
    'type': type,
    'technology': technology,
    'powerClass': powerClass,
    'adaptive': adaptive,
  };
  factory MobileSite.fromJson(Map<String, dynamic> j) => MobileSite(
    id: j['id'] as String,
    station: j['station'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    sourceEasting: (j['sourceEasting'] as num?)?.toDouble(),
    sourceNorthing: (j['sourceNorthing'] as num?)?.toDouble(),
    type: j['type'] as String?,
    technology: j['technology'] as String?,
    powerClass: j['powerClass'] as String?,
    adaptive: j['adaptive'] as String?,
  );
  String get description => [
    'Station: $station · BAKOM ID: $id',
    if (type != null) 'Typ: $type',
    if (technology != null) 'Technologie: $technology',
    if (powerClass != null) 'Leistungsklasse: $powerClass',
    if (adaptive != null) 'Adaptiver Betrieb: $adaptive',
    if (sourceEasting != null && sourceNorthing != null)
      'Originalkoordinaten LV95: ${sourceEasting!.toStringAsFixed(0)}, ${sourceNorthing!.toStringAsFixed(0)}',
    'Objekthöhe: unbekannt (keine Hindernisgeometrie)',
    'Quelle: $mobileSiteSource',
  ].join('\n');
}

class MobileSiteArea {
  MobileSiteArea(this.latitude, this.longitude, this.radiusMeters) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 45.5 ||
        latitude > 48.5 ||
        longitude < 5.5 ||
        longitude > 11 ||
        radiusMeters < 250 ||
        radiusMeters > 5000) {
      throw const FormatException(
        'Select a Swiss coordinate and radius 250–5000 m.',
      );
    }
  }
  final double latitude, longitude;
  final int radiusMeters;
  String get key =>
      '${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}:$radiusMeters';
  List<double> get lv95Envelope {
    final center = const GeoCoordinateService().wgs84ToLv95(
      Wgs84Coordinate(latitude: latitude, longitude: longitude),
    );
    return [
      center.easting - radiusMeters,
      center.northing - radiusMeters,
      center.easting + radiusMeters,
      center.northing + radiusMeters,
    ];
  }

  List<double> get wgs84Envelope {
    final degreesLat = radiusMeters / 110574;
    final degreesLon =
        radiusMeters / (111320 * math.cos(latitude * math.pi / 180));
    return [
      longitude - degreesLon,
      latitude - degreesLat,
      longitude + degreesLon,
      latitude + degreesLat,
    ];
  }

  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };
  factory MobileSiteArea.fromJson(Map<String, dynamic> j) => MobileSiteArea(
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
    j['radiusMeters'] as int,
  );
}

class MobileSiteSnapshot {
  const MobileSiteSnapshot({
    required this.area,
    required this.stations,
    required this.fetchedUtc,
    required this.truncated,
    this.sourceUpdatedUtc,
    this.fromCache = false,
    this.refreshFailed = false,
  });
  final MobileSiteArea area;
  final List<MobileSite> stations;
  final DateTime fetchedUtc;
  final DateTime? sourceUpdatedUtc;
  final bool truncated, fromCache, refreshFailed;
  bool isOld(DateTime now) =>
      now.toUtc().difference(fetchedUtc) > const Duration(days: 1);
  MobileSiteSnapshot cached({bool failed = false}) => MobileSiteSnapshot(
    area: area,
    stations: stations,
    fetchedUtc: fetchedUtc,
    sourceUpdatedUtc: sourceUpdatedUtc,
    truncated: truncated,
    fromCache: true,
    refreshFailed: failed,
  );
  String get ageDescription =>
      'STAC-Metadatenstand: ${sourceUpdatedUtc?.toIso8601String() ?? 'unbekannt'} · Datenabruf: ${fetchedUtc.toIso8601String()} UTC';
  Map<String, Object?> toMetadata() => {
    'version': 1,
    'area': area.toJson(),
    'fetchedUtc': fetchedUtc.toIso8601String(),
    'sourceUpdatedUtc': sourceUpdatedUtc?.toIso8601String(),
    'truncated': truncated,
  };
  factory MobileSiteSnapshot.fromMetadata(
    Map<String, dynamic> j,
    List<MobileSite> stations,
  ) {
    if (j['version'] != 1) {
      throw const FormatException('Unknown mobile-site cache version');
    }
    return MobileSiteSnapshot(
      area: MobileSiteArea.fromJson(
        Map<String, dynamic>.from(j['area'] as Map),
      ),
      stations: List.unmodifiable(stations),
      fetchedUtc: DateTime.parse(j['fetchedUtc'] as String).toUtc(),
      sourceUpdatedUtc: j['sourceUpdatedUtc'] == null
          ? null
          : DateTime.parse(j['sourceUpdatedUtc'] as String).toUtc(),
      truncated: j['truncated'] == true,
    );
  }
}

String? _optional(Object? value) {
  final s = value?.toString().trim();
  if (s == null || s.isEmpty || s.toLowerCase() == 'null') {
    return null;
  }
  return s.length > 240 ? s.substring(0, 240) : s;
}

/// Decodes GeoAdmin identify JSON, retaining the official German attributes.
/// The GeoAdmin `koord` field is LV95; the other geometry may be WGS84.
List<MobileSite> parseMobileSites(String text, {int maxResults = 200}) {
  if (text.length > 1800000) {
    throw const FormatException('Mobile-site response too large');
  }
  final decoded = jsonDecode(text);
  if (decoded is! Map || decoded['results'] is! List) {
    throw const FormatException('Unexpected mobile-site response');
  }
  final rows = decoded['results'] as List;
  if (rows.length > maxResults) {
    throw const FormatException('Mobile-site response exceeds limit');
  }
  final result = <String, MobileSite>{};
  for (final raw in rows) {
    if (raw is! Map) {
      continue;
    }
    final row = Map<String, dynamic>.from(raw);
    final attrs = row['attributes'];
    if (attrs is! Map) {
      continue;
    }
    final values = Map<String, dynamic>.from(attrs);
    final id = _optional(row['featureId'] ?? values['id'] ?? row['id']);
    if (id == null || id.length > 120) {
      continue;
    }
    double? east, north;
    final coord = _optional(values['koord']);
    if (coord != null) {
      final parts = coord.split(',');
      if (parts.length == 2) {
        east = double.tryParse(parts[0].trim());
        north = double.tryParse(parts[1].trim());
      }
    }
    Wgs84Coordinate? location;
    if (east != null && north != null) {
      try {
        location = const GeoCoordinateService().lv95ToWgs84(
          Lv95Coordinate(easting: east, northing: north),
        );
      } on ArgumentError {
        continue;
      }
    } else if (row['geometry'] is Map) {
      final geometry = Map<String, dynamic>.from(row['geometry'] as Map);
      Object? x = geometry['x'], y = geometry['y'];
      if (x == null &&
          geometry['type'] == 'Point' &&
          geometry['coordinates'] is List) {
        final p = geometry['coordinates'] as List;
        if (p.length >= 2) {
          x = p[0];
          y = p[1];
        }
      }
      if (x is num && y is num) {
        if (x.toDouble().abs() <= 180 && y.toDouble().abs() <= 90) {
          location = Wgs84Coordinate(
            latitude: y.toDouble(),
            longitude: x.toDouble(),
          );
        } else {
          east = x.toDouble();
          north = y.toDouble();
          try {
            location = const GeoCoordinateService().lv95ToWgs84(
              Lv95Coordinate(easting: east, northing: north),
            );
          } on ArgumentError {
            continue;
          }
        }
      }
    }
    if (location == null ||
        !const GeoCoordinateService().supportsWgs84(location)) {
      continue;
    }
    result.putIfAbsent(
      id,
      () => MobileSite(
        id: id,
        station: _optional(values['station']) ?? 'Mobilfunkstation $id',
        latitude: location!.latitude,
        longitude: location.longitude,
        sourceEasting: east,
        sourceNorthing: north,
        type: _optional(values['typ_de']),
        technology: _optional(values['techno_de']),
        powerClass: _optional(values['power_de']),
        adaptive: _optional(values['adaptiv_de']),
      ),
    );
  }
  return List.unmodifiable(result.values);
}
