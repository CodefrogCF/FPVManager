import 'dart:convert';

import '../mobility/road_routing.dart';
import '../../features/data_management/backup_codec.dart'
    show validateBackupJsonText;

enum GroundTravelMode {
  walking('Zu Fuß', 'routed-foot', 'foot'),
  cycling('Velo', 'routed-bike', 'bike');

  const GroundTravelMode(this.label, this.servicePath, this.profile);
  final String label, servicePath, profile;
}

class GroundRoutePlan {
  GroundRoutePlan({
    required this.name,
    required this.mode,
    required Iterable<MobilityPoint> points,
    required this.origin,
    required this.destination,
    required this.source,
    required this.calculatedAtUtc,
    this.distanceMeters,
    this.durationSeconds,
    Iterable<double?>? elevations,
    Map<String, dynamic> attributes = const {},
  }) : points = List.unmodifiable(points),
       elevations = elevations == null ? null : List.unmodifiable(elevations),
       attributes = Map.unmodifiable(attributes);
  final String name, source;
  final GroundTravelMode mode;
  final List<MobilityPoint> points;
  final MobilityPoint origin, destination;
  final DateTime? calculatedAtUtc;
  final double? distanceMeters, durationSeconds;
  final List<double?>? elevations;
  final Map<String, dynamic> attributes;
  GroundRoutePlan withName(String value) => GroundRoutePlan(
    name: value,
    mode: mode,
    points: points,
    origin: origin,
    destination: destination,
    source: source,
    calculatedAtUtc: calculatedAtUtc,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    elevations: elevations,
    attributes: attributes,
  );
  String encode() => jsonEncode({
    'version': 1,
    'name': name,
    'mode': mode.name,
    'points': points.map((p) => p.toJson()).toList(),
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'source': source,
    'calculatedAtUtc': calculatedAtUtc?.toUtc().toIso8601String(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'elevations': elevations,
    'attributes': attributes,
  });
  factory GroundRoutePlan.decode(String text) {
    validateBackupJsonText(text);
    final j = jsonDecode(text);
    if (j is! Map ||
        j['version'] != 1 ||
        j['name'] is! String ||
        (j['name'] as String).trim().isEmpty ||
        (j['name'] as String).length > 120 ||
        j['source'] is! String ||
        (j['source'] as String).isEmpty ||
        (j['source'] as String).length > 500 ||
        !GroundTravelMode.values.any((m) => m.name == j['mode']) ||
        j['points'] is! List ||
        (j['points'] as List).length < 2 ||
        (j['points'] as List).length > 20000 ||
        j['attributes'] is! Map ||
        jsonEncode(j['attributes']).length > 128 * 1024) {
      throw const FormatException('Ungültige Bodenroute oder Version');
    }
    final points = [
      for (final p in j['points'] as List) MobilityPoint.fromJson(p),
    ];
    for (final key in ['distanceMeters', 'durationSeconds']) {
      if (j[key] != null &&
          (j[key] is! num || !(j[key] as num).isFinite || j[key] < 0)) {
        throw const FormatException('Ungültige Routenschätzung');
      }
    }
    DateTime? calculated;
    if (j['calculatedAtUtc'] != null) {
      if (j['calculatedAtUtc'] is! String ||
          !(j['calculatedAtUtc'] as String).endsWith('Z')) {
        throw const FormatException('Ungültige Berechnungszeit');
      }
      calculated = DateTime.tryParse(j['calculatedAtUtc'] as String)?.toUtc();
      if (calculated == null) {
        throw const FormatException('Ungültige Berechnungszeit');
      }
    }
    List<double?>? elevations;
    if (j['elevations'] != null) {
      final raw = j['elevations'];
      if (raw is! List ||
          raw.length != points.length ||
          raw.any(
            (v) => v != null && (v is! num || !v.isFinite || v.abs() > 20000),
          )) {
        throw const FormatException('Ungültige Quellenhöhen');
      }
      elevations = [for (final v in raw) (v as num?)?.toDouble()];
    }
    return GroundRoutePlan(
      name: j['name'] as String,
      mode: GroundTravelMode.values.byName(j['mode'] as String),
      points: points,
      origin: MobilityPoint.fromJson(j['origin']),
      destination: MobilityPoint.fromJson(j['destination']),
      source: j['source'] as String,
      calculatedAtUtc: calculated,
      distanceMeters: (j['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (j['durationSeconds'] as num?)?.toDouble(),
      elevations: elevations,
      attributes: Map<String, dynamic>.from(j['attributes'] as Map),
    );
  }
  Map<String, dynamic> toGlobe() => {
    'id': 'ground-route',
    'visible': true,
    'features': [
      {
        'id': 'planned-ground-route',
        'name': name,
        'detail':
            '${mode.label} · $source\n${calculatedAtUtc?.toIso8601String() ?? "Berechnungszeit unbekannt"}\nGeplante Bodenroute; Zugänglichkeit und Sperrungen separat prüfen.',
        'geometry': {
          'type': 'LineString',
          'coordinates': points.map((p) => p.toJson()).toList(),
        },
      },
    ],
  };
}
