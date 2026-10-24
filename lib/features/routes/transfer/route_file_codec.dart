import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../../../core/geo/altitude_service.dart';
import '../../../core/geo/geo_coordinate_service.dart';
import '../../../core/models/flight_route.dart';
import '../../../core/models/route_transfer.dart';

const routeFileMaxBytes = 4 * 1024 * 1024;
const _namespace = 'https://codefrog.ch/fpvmanager/routes/1';

double _number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Expected a finite number');
  }
  return value.toDouble();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an object');
  }
  return value;
}

String _name(Object? value, int index) {
  final name = value is String && value.trim().isNotEmpty
      ? value.trim()
      : 'Imported route $index';
  if (name.length > 120) {
    throw const FormatException('Route names support at most 120 characters');
  }
  return name;
}

Map<String, dynamic> _pointMetadata(RouteWaypointInput p) => {
  if (p.height != null)
    'height': {
      'meters': p.height!.meters,
      'reference': switch (p.height!) {
        AglWaypointHeight() => 'aboveGroundLevel',
        AbsoluteWaypointHeight(:final elevation) => elevation.reference.name,
      },
    },
  if (p.speedMetersPerSecond != null)
    'airspeedMetersPerSecond': p.speedMetersPerSecond,
};
RouteWaypointInput _point(
  double lon,
  double lat,
  double? elevation,
  Map<String, dynamic>? metadata, {
  required bool geoJson,
}) {
  if (elevation != null && (!elevation.isFinite || elevation.abs() > 100000)) {
    throw const FormatException('Invalid elevation');
  }
  if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90) {
    throw const FormatException('Invalid WGS84 coordinates');
  }
  WaypointHeight? height;
  if (metadata?['height'] case final Object value) {
    final j = _map(value),
        meters = _number(j['meters']),
        reference = j['reference'];
    if (meters.abs() > 100000) {
      throw const FormatException('Invalid height in metres');
    }
    if (reference == 'aboveGroundLevel') {
      if (meters < 0) {
        throw const FormatException('AGL height must be nonnegative');
      }
      height = AglWaypointHeight(AboveGroundHeight(meters));
    } else {
      final ref = VerticalReference.values
          .where((v) => v.name == reference)
          .firstOrNull;
      if (ref == null) {
        throw const FormatException('Unsupported height reference');
      }
      height = AbsoluteWaypointHeight(
        ReferencedElevation(meters: meters, reference: ref),
      );
    }
    if (geoJson &&
        elevation != null &&
        (height is! AbsoluteWaypointHeight ||
            height.elevation.reference != VerticalReference.wgs84Ellipsoid ||
            (height.meters - elevation).abs() > 1e-6)) {
      throw const FormatException(
        'GeoJSON ellipsoid height conflicts with waypoint metadata',
      );
    }
  } else if (elevation != null) {
    if (!elevation.isFinite || elevation.abs() > 100000) {
      throw const FormatException('Invalid elevation');
    }
    height = AbsoluteWaypointHeight(
      ReferencedElevation(
        meters: elevation,
        reference: geoJson
            ? VerticalReference.wgs84Ellipsoid
            : VerticalReference.unverified,
      ),
    );
  }
  final speed = metadata?['airspeedMetersPerSecond'] == null
      ? null
      : _number(metadata!['airspeedMetersPerSecond']);
  if (speed != null && (speed <= 0 || speed > 200)) {
    throw const FormatException('Invalid airspeed in metres per second');
  }
  return RouteWaypointInput(
    position: Wgs84Coordinate(latitude: lat, longitude: lon),
    height: height,
    speedMetersPerSecond: speed,
  );
}

/// Parse only embedded route data, never external resources or executable KML.
RouteImportPreview decodeRouteFile(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > routeFileMaxBytes) {
    throw const FormatException('Choose a route file up to 4 MiB');
  }
  final text = utf8.decode(bytes).replaceFirst('\uFEFF', '').trimLeft();
  final warnings = <String>{};
  final routes = <ImportedRoute>[];
  void add(String name, List<RouteWaypointInput> points) {
    if (points.length < 2 ||
        points.length > 1000 ||
        routes.length >= 20 ||
        routes.fold<int>(0, (n, r) => n + r.points.length) + points.length >
            10000) {
      throw const FormatException(
        'Use up to 20 routes, 2–1000 points each, and 10000 points per file',
      );
    }
    routes.add(ImportedRoute(name, points));
  }

  if (text.startsWith('{')) {
    // Bound nesting before the JSON decoder allocates nested structures.
    var depth = 0, inString = false, escaped = false;
    for (final c in text.codeUnits) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          inString = false;
        }
      } else if (c == 34) {
        inString = true;
      } else if (c == 123 || c == 91) {
        if (++depth > 64) {
          throw const FormatException('GeoJSON nesting limit exceeded');
        }
      } else if (c == 125 || c == 93) {
        depth--;
      }
    }
    final root = _map(jsonDecode(text));
    if (root.containsKey('crs')) {
      throw const FormatException(
        'Legacy GeoJSON CRS is unsupported; convert to WGS84 RFC 7946',
      );
    }
    final features = root['type'] == 'FeatureCollection'
        ? root['features']
        : [root];
    if (features is! List || features.isEmpty || features.length > 20) {
      throw const FormatException('Expected at most 20 route features');
    }
    for (final item in features) {
      final feature = _map(item);
      if (feature.containsKey('crs')) {
        throw const FormatException('Legacy CRS is unsupported');
      }
      final geometry = feature['type'] == 'Feature'
          ? _map(feature['geometry'])
          : feature;
      if (geometry.containsKey('crs')) {
        throw const FormatException('Legacy CRS is unsupported');
      }
      final properties = feature['properties'] == null
          ? <String, dynamic>{}
          : _map(feature['properties']);
      final rawMeta = properties['fpvmanager'];
      final meta = rawMeta == null ? null : _map(rawMeta);
      if (meta != null && meta['version'] != 1) {
        throw const FormatException('Unsupported FPVManager route metadata');
      }
      final lines = geometry['type'] == 'LineString'
          ? [geometry['coordinates']]
          : geometry['type'] == 'MultiLineString'
          ? geometry['coordinates']
          : null;
      if (lines is! List || lines.length > 20) {
        throw const FormatException(
          'Only LineString and MultiLineString routes are supported',
        );
      }
      if (meta != null && geometry['type'] != 'LineString') {
        throw const FormatException(
          'Waypoint metadata requires a single LineString',
        );
      }
      for (final line in lines) {
        if (line is! List || line.length < 2 || line.length > 1000) {
          throw const FormatException('Invalid route point count');
        }
        final entries = meta?['waypoints'];
        if (meta != null &&
            (entries is! List || entries.length != line.length)) {
          throw const FormatException('Waypoint metadata count mismatch');
        }
        final points = <RouteWaypointInput>[];
        for (var i = 0; i < line.length; i++) {
          final p = line[i];
          if (p is! List || p.length < 2 || p.length > 3) {
            throw const FormatException(
              'Expected [longitude, latitude, optional ellipsoid metres]',
            );
          }
          points.add(
            _point(
              _number(p[0]),
              _number(p[1]),
              p.length == 3 ? _number(p[2]) : null,
              entries == null ? null : _map(entries[i]),
              geoJson: true,
            ),
          );
        }
        add(_name(properties['name'], routes.length + 1), points);
      }
    }
  } else if (text.startsWith('<')) {
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(text)) {
      throw const FormatException(
        'XML declarations and external entities are unsupported',
      );
    }
    var depth = 0, events = 0;
    for (final event in parseEvents(text)) {
      if (++events > 100000) {
        throw const FormatException('XML event limit exceeded');
      }
      if (event is XmlStartElementEvent &&
          !event.isSelfClosing &&
          ++depth > 64) {
        throw const FormatException('XML nesting limit exceeded');
      }
      if (event is XmlEndElementEvent) depth--;
    }
    final root = XmlDocument.parse(text).rootElement;
    const gpxNamespace = 'http://www.topografix.com/GPX/1/1';
    if (root.name.local != 'gpx' ||
        ![
          null,
          '',
          gpxNamespace,
          'http://www.topografix.com/GPX/1/0',
        ].contains(root.namespaceUri)) {
      throw const FormatException(
        'Only GPX is supported. KML has different altitude semantics; convert it with an explicit height reference.',
      );
    }
    Iterable<XmlElement> children(XmlElement e, String name) =>
        e.childElements.where(
          (c) => c.name.local == name && c.namespaceUri == root.namespaceUri,
        );
    String? scalar(XmlElement e, String name) =>
        children(e, name).firstOrNull?.innerText.trim();
    void parsePoints(XmlElement parent, String pointName, String name) {
      final nodes = children(parent, pointName).toList();
      if (nodes.length > 1000) {
        throw const FormatException('A route supports at most 1000 points');
      }
      if (nodes.isEmpty) return;
      final points = <RouteWaypointInput>[];
      for (final node in nodes) {
        final lat = double.tryParse(node.getAttribute('lat') ?? ''),
            lon = double.tryParse(node.getAttribute('lon') ?? '');
        if (lat == null || lon == null) {
          throw const FormatException('Missing GPX coordinates');
        }
        final ele = scalar(node, 'ele'),
            elevation = ele == null ? null : double.tryParse(ele);
        if (ele != null && elevation == null) {
          throw const FormatException('Invalid GPX elevation');
        }
        final extensions = children(node, 'extensions').firstOrNull;
        final fpv = extensions?.childElements
            .where(
              (e) => e.name.local == 'waypoint' && e.namespaceUri == _namespace,
            )
            .firstOrNull;
        Map<String, dynamic>? metadata;
        if (fpv != null) {
          if (fpv.getAttribute('version') != '1') {
            throw const FormatException('Unsupported GPX waypoint metadata');
          }
          final height = fpv.getAttribute('heightMeters'),
              ref = fpv.getAttribute('heightReference'),
              speed = fpv.getAttribute('airspeedMetersPerSecond');
          if (speed != null && double.tryParse(speed) == null) {
            throw const FormatException('Invalid GPX airspeed');
          }
          if ((height == null) != (ref == null)) {
            throw const FormatException('Incomplete height reference');
          }
          metadata = {
            if (height != null)
              'height': {'meters': double.tryParse(height), 'reference': ref},
            if (speed != null)
              'airspeedMetersPerSecond': double.tryParse(speed),
          };
        }
        final p = _point(lon, lat, elevation, metadata, geoJson: false);
        if (p.height case AbsoluteWaypointHeight(:final elevation)
            when elevation.reference == VerticalReference.unverified) {
          warnings.add(
            'GPX elevation has no verified vertical datum; it remains unverified.',
          );
        }
        points.add(p);
      }
      add(name, points);
    }

    for (final rte in children(root, 'rte')) {
      parsePoints(rte, 'rtept', _name(scalar(rte, 'name'), routes.length + 1));
    }
    for (final trk in children(root, 'trk')) {
      for (final seg in children(trk, 'trkseg')) {
        parsePoints(
          seg,
          'trkpt',
          _name(scalar(trk, 'name'), routes.length + 1),
        );
      }
    }
    warnings.add(
      'Disconnected tracks are imported as separate routes. GPX measurements use metres.',
    );
  } else {
    throw const FormatException('Choose GeoJSON or GPX route data');
  }
  if (routes.isEmpty) {
    throw const FormatException('No route with at least two points found');
  }
  if (routes.any((r) => r.points.any((p) => p.height == null))) {
    warnings.add(
      'Some waypoints have no flight height. The 30 m preview is not an imported altitude.',
    );
  }
  return RouteImportPreview(routes, warnings.toList());
}

Uint8List encodeRouteFile(ImportedRoute route, RouteFileFormat format) {
  if (route.points.length < 2 || route.points.length > 1000) {
    throw const FormatException('Export requires 2–1000 waypoints');
  }
  final name = _name(route.name, 1);
  for (final p in route.points) {
    _point(
      p.position.longitude,
      p.position.latitude,
      null,
      _pointMetadata(p),
      geoJson: false,
    );
  }
  String text;
  if (format == RouteFileFormat.geoJson) {
    text = const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'name': name,
            'fpvmanager': {
              'version': 1,
              'waypoints': route.points.map(_pointMetadata).toList(),
            },
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in route.points)
                [
                  p.position.longitude,
                  p.position.latitude,
                  if (p.height case AbsoluteWaypointHeight(:final elevation)
                      when elevation.reference ==
                          VerticalReference.wgs84Ellipsoid)
                    elevation.meters,
                ],
            ],
          },
        },
      ],
    });
  } else {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      namespaceUris: {
        '': 'http://www.topografix.com/GPX/1/1',
        'fpv': _namespace,
      },
      attributes: {'version': '1.1', 'creator': 'FPVManager'},
      nest: () {
        builder.element(
          'rte',
          nest: () {
            builder.element('name', nest: name);
            for (final p in route.points) {
              builder.element(
                'rtept',
                attributes: {
                  'lat': '${p.position.latitude}',
                  'lon': '${p.position.longitude}',
                },
                nest: () {
                  // Only an unspecified datum is emitted as generic GPX elevation.
                  // Explicit datums/AGL remain in extensions instead of being mislabeled.
                  if (p.height case AbsoluteWaypointHeight(:final elevation)
                      when elevation.reference ==
                          VerticalReference.unverified) {
                    builder.element('ele', nest: '${elevation.meters}');
                  }
                  builder.element(
                    'extensions',
                    nest: () {
                      builder.element(
                        'waypoint',
                        namespaceUri: _namespace,
                        attributes: {
                          'version': '1',
                          if (p.height != null)
                            'heightMeters': '${p.height!.meters}',
                          if (p.height != null)
                            'heightReference': switch (p.height!) {
                              AglWaypointHeight() => 'aboveGroundLevel',
                              AbsoluteWaypointHeight(:final elevation) =>
                                elevation.reference.name,
                            },
                          if (p.speedMetersPerSecond != null)
                            'airspeedMetersPerSecond':
                                '${p.speedMetersPerSecond}',
                        },
                      );
                    },
                  );
                },
              );
            }
          },
        );
      },
    );
    text = builder.buildDocument().toXmlString(pretty: true);
  }
  final bytes = Uint8List.fromList(utf8.encode(text));
  if (bytes.length > routeFileMaxBytes) {
    throw const FormatException('Export exceeds 4 MiB');
  }
  return bytes;
}
