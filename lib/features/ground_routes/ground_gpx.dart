import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../mobility/road_routing.dart';
import 'ground_route.dart';

const groundGpxMaxBytes = 4 * 1024 * 1024;
const _namespace = 'https://codefrog.ch/fpvmanager/ground-routes/1';

class GroundGpxPreview {
  GroundGpxPreview(this.routes, this.warnings);
  final List<GroundRoutePlan> routes;
  final List<String> warnings;
}

GroundGpxPreview decodeGroundGpx((Uint8List, GroundTravelMode) input) {
  if (input.$1.isEmpty || input.$1.length > groundGpxMaxBytes) {
    throw const FormatException('GPX-Datei überschreitet 4 MiB');
  }
  final text = utf8.decode(input.$1);
  if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(text)) {
    throw const FormatException(
      'DTD und externe XML-Ressourcen werden nicht unterstützt',
    );
  }
  var depth = 0, events = 0;
  for (final e in parseEvents(text)) {
    if (++events > 180000) {
      throw const FormatException('GPX-Ereignislimit überschritten');
    }
    if (e is XmlStartElementEvent && !e.isSelfClosing && ++depth > 32) {
      throw const FormatException('GPX ist zu tief verschachtelt');
    }
    if (e is XmlEndElementEvent) depth--;
  }
  final root = XmlDocument.parse(text).rootElement;
  if (root.name.local != 'gpx' ||
      ![
        null,
        '',
        'http://www.topografix.com/GPX/1/1',
        'http://www.topografix.com/GPX/1/0',
      ].contains(root.namespaceUri)) {
    throw const FormatException('Nicht unterstütztes GPX-Format');
  }
  if (root.getAttribute('version') != null &&
      !{'1.0', '1.1'}.contains(root.getAttribute('version'))) {
    throw const FormatException('Nicht unterstützte GPX-Version');
  }
  Iterable<XmlElement> children(XmlElement e, String n) => e.childElements
      .where((c) => c.name.local == n && c.namespaceUri == root.namespaceUri);
  String? scalar(XmlElement e, String n) =>
      children(e, n).firstOrNull?.innerText.trim();
  final routes = <GroundRoutePlan>[], warnings = <String>{};
  var total = 0;
  void read(
    XmlElement owner,
    XmlElement part,
    String pointName,
    String suffix,
  ) {
    final nodes = children(part, pointName).toList();
    if (nodes.length < 2) {
      throw const FormatException(
        'Jeder GPX-Abschnitt benötigt mindestens zwei Punkte',
      );
    }
    total += nodes.length;
    if (total > 20000 || routes.length >= 20) {
      throw const FormatException(
        'GPX unterstützt maximal 20 Routen und 20000 Punkte',
      );
    }
    final type = scalar(owner, 'type')?.toLowerCase();
    final mode = switch (type) {
      'walking' || 'hiking' || 'foot' => GroundTravelMode.walking,
      'cycling' || 'bike' || 'bicycle' => GroundTravelMode.cycling,
      _ => input.$2,
    };
    if (!{
      'walking',
      'hiking',
      'foot',
      'cycling',
      'bike',
      'bicycle',
    }.contains(type)) {
      warnings.add(
        'Unbekannter oder fehlender Routentyp: der ausdrücklich gewählte Importmodus ${input.$2.label} wird verwendet.',
      );
    }
    final points = <MobilityPoint>[], elevations = <double?>[];
    var unsupportedPointData = false;
    for (final n in nodes) {
      final lat = double.tryParse(n.getAttribute('lat') ?? ''),
          lon = double.tryParse(n.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        throw const FormatException('GPX-Koordinaten fehlen');
      }
      points.add(MobilityPoint(lat, lon));
      final raw = scalar(n, 'ele'),
          ele = raw == null ? null : double.tryParse(raw);
      if (raw != null && (ele == null || !ele.isFinite || ele.abs() > 20000)) {
        throw const FormatException('Ungültige GPX-Höhe');
      }
      elevations.add(ele);
      if (n.childElements.any((e) => !{'ele'}.contains(e.name.local))) {
        unsupportedPointData = true;
      }
    }
    final extension = children(owner, 'extensions').firstOrNull;
    final config = extension?.childElements
        .where(
          (e) => e.name.local == 'groundRoute' && e.namespaceUri == _namespace,
        )
        .firstOrNull;
    Map<String, dynamic> metadata = {};
    if (config != null) {
      if (config.getAttribute('version') != '1' ||
          config.innerText.length > 150 * 1024) {
        throw const FormatException(
          'Nicht unterstützte Bodenrouten-Erweiterung',
        );
      }
      final raw = jsonDecode(config.innerText);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Ungültige Bodenrouten-Metadaten');
      }
      metadata = raw;
    }
    final name = '${scalar(owner, 'name') ?? 'Importierte Bodenroute'}$suffix';
    final foreign = extension?.childElements
        .where((e) => e != config)
        .map((e) => e.toXmlString())
        .join('\n');
    final attributes = <String, dynamic>{
      'originalGpxType': ?type,
      if (metadata['attributes'] is Map)
        ...Map<String, dynamic>.from(metadata['attributes'] as Map),
      if (scalar(owner, 'desc') != null) 'description': scalar(owner, 'desc'),
      if (foreign != null && foreign.isNotEmpty && foreign.length <= 64000)
        'uninterpretedGpxExtensions': foreign,
    };
    if (elevations.any((e) => e != null) &&
        attributes['elevationReference'] == null) {
      attributes['elevationReference'] =
          'GPX elevation; vertical datum not supplied';
    }
    if (foreign?.isNotEmpty == true) {
      warnings.add(
        'Zusätzliche GPX-Erweiterungen werden nicht ausgewertet; begrenzte Originalangaben bleiben in den Quellenattributen erhalten.',
      );
    }
    if (unsupportedPointData) {
      warnings.add(
        'Zeit-/Sensorangaben und andere GPX-Punktattribute werden nicht als Routenparameter übernommen.',
      );
    }
    final doc = {
      'version': 1,
      'name': name,
      'mode': mode.name,
      'points': points.map((p) => p.toJson()).toList(),
      'origin': metadata['origin'] ?? points.first.toJson(),
      'destination': metadata['destination'] ?? points.last.toJson(),
      'source':
          metadata['source'] ??
          'GPX-Import · ursprüngliche Routingquelle nicht angegeben',
      'calculatedAtUtc': metadata['calculatedAtUtc'],
      'distanceMeters': metadata['distanceMeters'],
      'durationSeconds': metadata['durationSeconds'],
      'elevations': elevations.any((e) => e != null) ? elevations : null,
      'attributes': attributes,
    };
    routes.add(GroundRoutePlan.decode(jsonEncode(doc)));
  }

  for (final route in children(root, 'rte')) {
    read(route, route, 'rtept', '');
  }
  for (final track in children(root, 'trk')) {
    final segments = children(track, 'trkseg').toList();
    for (var i = 0; i < segments.length; i++) {
      read(
        track,
        segments[i],
        'trkpt',
        segments.length > 1 ? ' · Abschnitt ${i + 1}' : '',
      );
    }
    if (segments.length > 1) {
      warnings.add(
        'Getrennte Track-Abschnitte bleiben getrennte Bodenrouten; Lücken werden nicht verbunden.',
      );
    }
  }
  if (routes.isEmpty) {
    throw const FormatException(
      'Keine Bodenroute gefunden. Einzelne Wegpunkte werden nicht automatisch verbunden.',
    );
  }
  return GroundGpxPreview(routes, warnings.toList());
}

Uint8List encodeGroundGpx(GroundRoutePlan route) {
  GroundRoutePlan.decode(route.encode());
  final metadata = Map<String, dynamic>.from(jsonDecode(route.encode()) as Map)
    ..remove('points')
    ..remove('elevations')
    ..remove('name')
    ..remove('mode')
    ..remove('version');
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'gpx',
    attributes: {
      'version': '1.1',
      'creator': 'FPVManager',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
      'xmlns:fpv': _namespace,
    },
    nest: () {
      builder.element(
        'rte',
        nest: () {
          builder.element('name', nest: route.name);
          builder.element('type', nest: route.mode.name);
          builder.element(
            'extensions',
            nest: () {
              builder.element(
                'fpv:groundRoute',
                attributes: {'version': '1'},
                nest: jsonEncode(metadata),
              );
            },
          );
          for (var i = 0; i < route.points.length; i++) {
            final p = route.points[i];
            builder.element(
              'rtept',
              attributes: {'lat': '${p.latitude}', 'lon': '${p.longitude}'},
              nest: () {
                if (route.elevations?[i] case final double height) {
                  builder.element('ele', nest: '$height');
                }
              },
            );
          }
        },
      );
    },
  );
  final bytes = Uint8List.fromList(
    utf8.encode(builder.buildDocument().toXmlString()),
  );
  if (bytes.length > groundGpxMaxBytes) {
    throw const FormatException('GPX-Export überschreitet 4 MiB');
  }
  return bytes;
}
