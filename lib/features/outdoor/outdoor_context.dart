import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/geo/polygon_intersections.dart';
import '../../core/models/outdoor_layer.dart';
import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_source.dart';
import '../mobility/road_routing.dart';
import '../observations/station_observation.dart';

enum NatureProtection { statutory, recommended, unknown }

NatureProtection natureProtection(Map<String, dynamic> attributes) =>
    switch ((attributes['schutzs_de'] ?? '').toString().trim().toLowerCase()) {
      'rechtsverbindlich' => NatureProtection.statutory,
      'empfohlen' || 'empfehlung' => NatureProtection.recommended,
      _ => NatureProtection.unknown,
    };

DateTime swissCivilDate(DateTime now) {
  final utc = now.toUtc();
  DateTime change(int month) {
    final last = DateTime.utc(utc.year, month + 1, 0);
    return DateTime.utc(utc.year, month, last.day - (last.weekday % 7), 1);
  }

  return utc.add(
    Duration(
      hours: !utc.isBefore(change(3)) && utc.isBefore(change(10)) ? 2 : 1,
    ),
  );
}

String outdoorValidity(
  Map<String, dynamic> attributes,
  DateTime now, {
  bool wildlife = false,
}) {
  final civil = swissCivilDate(now);
  if (wildlife) {
    final raw = '${attributes['schutzzeit'] ?? ''}';
    final match = RegExp(
      r'^\s*(\d{1,2})\.(\d{1,2})\.\s*[-–]\s*(\d{1,2})\.(\d{1,2})\.\s*$',
    ).firstMatch(raw);
    if (match == null) return 'Saison nicht auswertbar · Originalangabe prüfen';
    final a = int.parse(match[2]!) * 100 + int.parse(match[1]!),
        b = int.parse(match[4]!) * 100 + int.parse(match[3]!),
        day = civil.month * 100 + civil.day;
    for (final pair in [
      (int.parse(match[1]!), int.parse(match[2]!)),
      (int.parse(match[3]!), int.parse(match[4]!)),
    ]) {
      final d = DateTime.utc(2000, pair.$2, pair.$1);
      if (d.day != pair.$1 || d.month != pair.$2) {
        return 'Saison nicht auswertbar · Originalangabe prüfen';
      }
    }
    final within = a <= b ? day >= a && day <= b : day >= a || day <= b;
    return within
        ? 'Innerhalb der angegebenen Schutzzeit'
        : 'Außerhalb der angegebenen Schutzzeit · weitere Regeln prüfen';
  }
  final text = '${attributes['duration_de'] ?? ''}';
  final dates = RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b')
      .allMatches(text)
      .toList();
  if (dates.length != 2) return 'Undatiert / Gültigkeit nicht eindeutig';
  final values = <DateTime>[];
  for (final m in dates) {
    final y = int.parse(m[3]!),
        month = int.parse(m[2]!),
        day = int.parse(m[1]!);
    final d = DateTime.utc(y, month, day);
    if (d.year != y || d.month != month || d.day != day) {
      return 'Ungültige Datumsangabe · Original prüfen';
    }
    values.add(d);
  }
  if (values.last.isBefore(values.first)) {
    return 'Ungültiger Gültigkeitszeitraum';
  }
  final date = DateTime.utc(civil.year, civil.month, civil.day);
  return date.isBefore(values.first)
      ? 'Zukünftig'
      : date.isAfter(values.last)
      ? 'Abgelaufen'
      : 'Innerhalb des angegebenen Datumsbereichs';
}

bool _segmentsCross(List a, List b, List c, List d) {
  double side(List p, List q, List r) =>
      (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]);
  bool within(List p, List q, List r) =>
      r[0] >= math.min(p[0], q[0]) - 1e-10 &&
      r[0] <= math.max(p[0], q[0]) + 1e-10 &&
      r[1] >= math.min(p[1], q[1]) - 1e-10 &&
      r[1] <= math.max(p[1], q[1]) + 1e-10;
  final x = side(a, b, c),
      y = side(a, b, d),
      z = side(c, d, a),
      w = side(c, d, b);
  return ((x > 0 && y < 0 || x < 0 && y > 0) &&
          (z > 0 && w < 0 || z < 0 && w > 0)) ||
      (x.abs() < 1e-10 && within(a, b, c)) ||
      (y.abs() < 1e-10 && within(a, b, d)) ||
      (z.abs() < 1e-10 && within(c, d, a)) ||
      (w.abs() < 1e-10 && within(c, d, b));
}

double _pointSegmentDistance(MobilityPoint p, List a, List b) {
  final scale = math.cos(p.latitude * math.pi / 180),
      ax = (a[0] - p.longitude) * scale,
      ay = a[1] - p.latitude,
      bx = (b[0] - p.longitude) * scale,
      by = b[1] - p.latitude,
      dx = bx - ax,
      dy = by - ay;
  final t = (dx * dx + dy * dy) == 0
      ? 0.0
      : (-(ax * dx + ay * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
  return math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2)) *
      111320;
}

String outdoorRelation(
  Map<String, dynamic>? geometry,
  List<MobilityPoint> path,
) {
  if (geometry == null || path.isEmpty || path.length > 1000) {
    return 'Geometrischer Abgleich nicht durchgeführt';
  }
  final type = geometry['type'], coords = geometry['coordinates'];
  if (type == 'Polygon' || type == 'MultiPolygon') {
    final index = PolygonIntersectionIndex.fromGeoJson({
      'type': 'FeatureCollection',
      'features': [
        {'type': 'Feature', 'geometry': geometry},
      ],
    });
    if (index.unassessedFeatureCount > 0) {
      return 'Geometrie nicht vollständig auswertbar';
    }
    return index
            .check(
              path
                  .map(
                    (p) => Wgs84Coordinate(
                      latitude: p.latitude,
                      longitude: p.longitude,
                    ),
                  )
                  .toList(),
            )
            .isEmpty
        ? 'Im angefragten Umfeld · keine geometrische Schneidung'
        : 'Geometrische Schneidung';
  }
  final lines = type == 'LineString'
      ? [coords]
      : type == 'MultiLineString'
      ? coords
      : null;
  if (lines is List) {
    for (final line in lines) {
      if (line is! List) continue;
      for (var i = 0; i + 1 < line.length; i++) {
        for (var j = 0; j + 1 < path.length; j++) {
          if (_segmentsCross(
            line[i] as List,
            line[i + 1] as List,
            path[j].toJson(),
            path[j + 1].toJson(),
          )) {
            return 'Geometrische Schneidung · Wegzuordnung prüfen';
          }
        }
      }
    }
    for (final p in path) {
      for (final line in lines) {
        if (line is! List) continue;
        for (var k = 0; k + 1 < line.length; k++) {
          if (_pointSegmentDistance(p, line[k] as List, line[k + 1] as List) <
              25) {
            return 'In unmittelbarer Nähe · Wegzuordnung nicht bestätigt';
          }
        }
      }
    }
    return 'Im angefragten Umfeld · keine bestätigte Wegzuordnung';
  }
  if (type == 'Point' && coords is List) {
    return path.any(
          (p) => stationDistance(p, MobilityPoint.fromJson(coords)) < 50,
        )
        ? 'In unmittelbarer Nähe'
        : 'Im angefragten Umfeld';
  }
  return 'Geometrischer Abgleich nicht unterstützt';
}

Map<String, dynamic> parseOutdoorContext(
  (String, List<MobilityPoint>, DateTime) input,
) {
  if (input.$1.length > 2 * 1024 * 1024) {
    throw const FormatException('Outdoor-Auszug ist zu groß');
  }
  final raw = jsonDecode(input.$1);
  if (raw is! Map ||
      raw['results'] is! List ||
      (raw['results'] as List).length > 300) {
    throw const FormatException('Nicht unterstützter Outdoor-Auszug');
  }
  final output = <Map<String, dynamic>>[], ids = <String>{};
  var vertices = 0;
  var spatialBudget = 2000000;
  var limitedChecks = false;
  void validateGeometry(Object? node, int depth) {
    if (depth > 7 || node is! List || node.isEmpty) {
      throw const FormatException('Ungültige Outdoor-Geometrie');
    }
    if (node.isNotEmpty && node.first is num) {
      if (node.length != 2 ||
          node.any((v) => v is! num || !v.isFinite) ||
          (node[0] as num).abs() > 180 ||
          (node[1] as num).abs() > 90 ||
          ++vertices > 20000) {
        throw const FormatException('Outdoor-Geometrielimit überschritten');
      }
    } else {
      if (node.length > 20000) {
        throw const FormatException('Outdoor-Geometrielimit überschritten');
      }
      for (final n in node) {
        validateGeometry(n, depth + 1);
      }
    }
  }

  for (final record in raw['results'] as List) {
    if (record is! Map || record['properties'] is! Map) {
      throw const FormatException('Outdoor-Attribute fehlen');
    }
    final layer = OutdoorLayer.values
        .where((l) => l.serviceLayer == record['layerBodId'])
        .firstOrNull;
    if (layer == null) {
      throw const FormatException('Nicht angefragte Outdoor-Quelle');
    }
    final attributes = Map<String, dynamic>.from(record['properties'] as Map);
    if (jsonEncode(attributes).length > 64000) {
      throw const FormatException('Outdoor-Attribute sind zu groß');
    }
    final id = '${layer.name}:${record['featureId']}';
    if (id.length > 120 || !ids.add(id)) {
      throw const FormatException('Doppelte Outdoor-Kennung');
    }
    final geometry = record['geometry'] is Map
        ? Map<String, dynamic>.from(record['geometry'] as Map)
        : null;
    final startVertices = vertices;
    if (geometry != null) {
      if (!{
        'Point',
        'LineString',
        'MultiLineString',
        'Polygon',
        'MultiPolygon',
      }.contains(geometry['type'])) {
        throw const FormatException('Nicht unterstützte Outdoor-Geometrie');
      }
      validateGeometry(geometry['coordinates'], 0);
    }
    final cost = (vertices - startVertices) * input.$2.length;
    final canCheck = cost <= spatialBudget && input.$2.length <= 1000;
    if (canCheck) {
      spatialBudget -= cost;
    } else {
      limitedChecks = true;
    }
    output.add({
      'id': id,
      'layer': layer.name,
      'name': '${attributes['wrz_name'] ?? attributes['title_de'] ?? attributes['label'] ?? layer.label}'
          .substring(
            0,
            math.min(
              200,
              '${attributes['wrz_name'] ?? attributes['title_de'] ?? attributes['label'] ?? layer.label}'
                  .length,
            ),
          ),
      'classification': layer == OutdoorLayer.wildlife
          ? natureProtection(attributes).name
          : '${attributes['sperrungen_type_de'] ?? attributes['sperrungen_type'] ?? 'unbekannt'}',
      'validity': outdoorValidity(
        attributes,
        input.$3,
        wildlife: layer == OutdoorLayer.wildlife,
      ),
      'relation': canCheck ? outdoorRelation(geometry, input.$2) : 'Geometrischer Abgleich wegen Größenlimit nicht durchgeführt · kürzeren Abschnitt wählen',
      'attributes': attributes,
      'geometry': geometry,
      'reference':
          '${attributes['url_kanton'] ?? attributes['url1_link_de'] ?? layer.legend}',
    });
  }
  return {
    'records': output,
    'incomplete': true,
    'atLimit': output.length >= 100,
    'coverage': 'Räumlich begrenzter amtlicher Auszug. Nicht alle Kantone, Zustände oder Wege sind vollständig enthalten. Keine Treffer bestätigen keine freie oder sichere Route.',
    'preciseRouteCheck': !limitedChecks,
  };
}

class OutdoorContextProvider extends CachedOsintProvider<Map<String, dynamic>> {
  OutdoorContextProvider({
    required Iterable<MobilityPoint> path,
    required Iterable<OutdoorLayer> layers,
    http.Client? client,
    super.now,
  }) : path = List.unmodifiable(path),
       layers = List.unmodifiable(layers),
       transport = MobilityHttp(client: client),
       super(cacheDuration: const Duration(minutes: 30)) {
    if (this.path.isEmpty ||
        this.path.length > 20000 ||
        this.layers.isEmpty ||
        this.layers.length > 10) {
      throw ArgumentError('Ungültiger Outdoor-Bezug');
    }
  }
  final List<MobilityPoint> path;
  final List<OutdoorLayer> layers;
  final MobilityHttp transport;
  @override
  OsintSource get source => OsintSource(
    id: 'outdoor-context',
    name: 'Amtlicher Outdoor-Kontext',
    publisher: 'BAFU / ASTRA / Kantone',
    dataUri: Uri.parse(
      'https://api3.geo.admin.ch/rest/services/all/MapServer/identify',
    ),
    metadataUri: Uri.parse('https://api3.geo.admin.ch/'),
    attribution: 'BAFU / ASTRA / Kantone · geo.admin.ch',
    coordinateReference:
        'EPSG:4326; begrenzter Auszug, keine schweizweite Vollständigkeit',
  );
  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final time = nowUtc;
    final west = path.map((p) => p.longitude).reduce(math.min) - .003,
        east = path.map((p) => p.longitude).reduce(math.max) + .003,
        south = path.map((p) => p.latitude).reduce(math.min) - .003,
        north = path.map((p) => p.latitude).reduce(math.max) + .003;
    if (east - west > .6 || north - south > .4) {
      throw const FormatException(
        'Detailabgleich ist auf etwa 45 km pro Ausschnitt begrenzt. Bitte einen kürzeren Abschnitt oder Kartenpunkt wählen.',
      );
    }
    final extent = '$west,$south,$east,$north';
    final body = await transport.text(
      sourceUri.replace(
        queryParameters: {
          'geometryType': 'esriGeometryEnvelope',
          'geometry': extent,
          'sr': '4326',
          'layers': 'all:${layers.map((l) => l.serviceLayer).join(',')}',
          'tolerance': '0',
          'mapExtent': extent,
          'imageDisplay': '1000,1000,96',
          'returnGeometry': 'true',
          'geometryFormat': 'geojson',
          'lang': 'de',
          'limit': '100',
        },
      ),
      maxBytes: 2 * 1024 * 1024,
    );
    final data = await compute(parseOutdoorContext, (body, path, time));
    return OsintDataset(
      source: source,
      data: data,
      fetchedAtUtc: time,
      lastCheckedAtUtc: time,
      cacheExpiresAtUtc: time.add(cacheDuration),
      persistable: false,
    );
  }

  @override
  void dispose() {
    transport.dispose();
    super.dispose();
  }
}
