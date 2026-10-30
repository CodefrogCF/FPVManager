import 'dart:math' as math;

import '../mobility/road_routing.dart';

DateTime observationUtc(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Messzeit ohne Zeitzone');
  }
  final time = DateTime.tryParse(value);
  if (time == null) throw const FormatException('Ungültige Messzeit');
  return time.toUtc();
}

class StationReading {
  const StationReading({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.atUtc,
    required this.quality,
    this.intervalMinutes,
  });
  final String parameter, unit, quality;
  final double value;
  final DateTime atUtc;
  final int? intervalMinutes;
  bool outdated(DateTime now, Duration maxAge) =>
      now.toUtc().difference(atUtc) > maxAge ||
      atUtc.isAfter(now.toUtc().add(const Duration(minutes: 2)));
  Map<String, dynamic> toJson() => {
    'parameter': parameter,
    'value': value,
    'unit': unit,
    'atUtc': atUtc.toIso8601String(),
    'quality': quality,
    'intervalMinutes': intervalMinutes,
  };
  factory StationReading.fromJson(Map<String, dynamic> value) {
    if (value['value'] is! num ||
        !(value['value'] as num).isFinite ||
        value['unit'] is! String ||
        (value['unit'] as String).length > 80 ||
        value['parameter'] is! String ||
        (value['parameter'] as String).length > 80 ||
        value['quality'] is! String ||
        (value['quality'] as String).length > 200 ||
        (value['intervalMinutes'] != null &&
            (value['intervalMinutes'] is! int ||
                value['intervalMinutes'] < 1 ||
                value['intervalMinutes'] > 1440))) {
      throw const FormatException('Ungültiger Messwert');
    }
    return StationReading(
      parameter: value['parameter'] as String,
      value: (value['value'] as num).toDouble(),
      unit: value['unit'] as String,
      atUtc: observationUtc(value['atUtc']),
      quality: value['quality'] as String,
      intervalMinutes: value['intervalMinutes'] as int?,
    );
  }
}

class ObservationStation {
  ObservationStation({
    required this.id,
    required this.name,
    required this.position,
    this.elevation,
    required this.readings,
    required this.metadata,
  });
  final String id, name;
  final MobilityPoint position;
  final double? elevation;
  final List<StationReading> readings;
  final Map<String, dynamic> metadata;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position.toJson(),
    'elevation': elevation,
    'readings': readings.map((r) => r.toJson()).toList(),
    'metadata': metadata,
  };
  factory ObservationStation.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        (value['id'] as String).length > 80 ||
        value['name'] is! String ||
        (value['name'] as String).length > 200 ||
        value['readings'] is! List ||
        (value['readings'] as List).length > 12 ||
        value['metadata'] is! Map ||
        (value['elevation'] != null &&
            (value['elevation'] is! num ||
                !(value['elevation'] as num).isFinite))) {
      throw const FormatException('Ungültige Messstation');
    }
    return ObservationStation(
      id: value['id'] as String,
      name: value['name'] as String,
      position: MobilityPoint.fromJson(value['position']),
      elevation: (value['elevation'] as num?)?.toDouble(),
      readings: [
        for (final r in value['readings'] as List)
          StationReading.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
      metadata: Map<String, dynamic>.from(value['metadata'] as Map),
    );
  }
  String detail(DateTime now, Duration age) =>
      '$name · $id\n${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}\nHöhe: ${elevation == null ? "nicht verfügbar" : "$elevation m ü. M. (Quellenreferenz)"}\n${readings.isEmpty ? "Keine unterstützten Messwerte verfügbar" : readings.map((r) => '${r.parameter}: ${r.value} ${r.unit}${r.intervalMinutes == null ? "" : " / ${r.intervalMinutes} min"}\n${r.atUtc.toIso8601String()} · ${r.quality}${r.outdated(now, age) ? " · veraltet / Zeit prüfen" : ""}').join('\n')}';
}

List<ObservationStation> readStations(Map<String, dynamic> data) {
  final raw = data['stations'];
  if (raw is! List || raw.length > 1000) {
    throw const FormatException('Messstationslimit überschritten');
  }
  final ids = <String>{};
  return [
    for (final value in raw)
      (() {
        final station = ObservationStation.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (!ids.add(station.id)) {
          throw const FormatException('Doppelte Messstation');
        }
        return station;
      })(),
  ];
}

double stationDistance(MobilityPoint a, MobilityPoint b) {
  final lat = (b.latitude - a.latitude) * math.pi / 180,
      lon = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.pow(math.sin(lat / 2), 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.pow(math.sin(lon / 2), 2);
  return 12742000 * math.asin(math.sqrt(h.clamp(0, 1)));
}

List<ObservationStation> nearbyStations(
  List<ObservationStation> stations,
  List<MobilityPoint> path, {
  int limit = 30,
  double radiusMeters = 50000,
}) {
  if (path.isEmpty || path.length > 20000) {
    throw const FormatException('Ungültiger Bezug für Messstationen');
  }
  final sampled = [
    for (var i = 0; i < path.length; i += math.max(1, path.length ~/ 100))
      path[i],
    path.last,
  ];
  final distances = <String, double>{
    for (final s in stations)
      s.id: sampled.map((p) => stationDistance(s.position, p)).reduce(math.min),
  };
  return (stations.where((s) => distances[s.id]! <= radiusMeters).toList()
        ..sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!)))
      .take(limit)
      .toList();
}

Map<String, dynamic> stationFeatures(
  List<ObservationStation> stations, {
  required DateTime now,
  required Duration maxAge,
  required String attribution,
}) => {
  'visible': true,
  'features': [
    for (final s in stations.take(200))
      {
        'id': s.id,
        'name': s.name,
        'detail': '${s.detail(now, maxAge)}\n$attribution'.substring(
          0,
          math.min(1200, '${s.detail(now, maxAge)}\n$attribution'.length),
        ),
        'geometry': {'type': 'Point', 'coordinates': s.position.toJson()},
      },
  ],
};
