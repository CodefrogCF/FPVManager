import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geo_coordinate_service.dart';

// Official swisstopo REFRAME height transformations.
//
// Requires an internet connection.
// Never silently assumes an elevation reference.
class ReframeHeightService {
  ReframeHeightService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const _host = 'geodesy.geo.admin.ch';

  String _endpoint(VerticalReference from, VerticalReference to) {
    return switch ((from, to)) {
      (VerticalReference.ln02, VerticalReference.lhn95) => 'ln02tolhn95',
      (VerticalReference.lhn95, VerticalReference.ln02) => 'lhn95toln02',
      (VerticalReference.ln02, VerticalReference.besselEllipsoid) =>
        'ln02tobessel',
      (VerticalReference.besselEllipsoid, VerticalReference.ln02) =>
        'besseltoln02',
      (VerticalReference.lhn95, VerticalReference.besselEllipsoid) =>
        'lhn95tobessel',
      (VerticalReference.besselEllipsoid, VerticalReference.lhn95) =>
        'besseltolhn95',
      _ => throw UnsupportedError(
        'Unsupported height transformation: '
        '${from.name} -> ${to.name}',
      ),
    };
  }

  Future<ReferencedElevation> transform({
    required Lv95Coordinate position,
    required ReferencedElevation elevation,
    required VerticalReference target,
  }) async {
    const geoService = GeoCoordinateService();

    if (!geoService.supportsLv95(position)) {
      throw ArgumentError('Position outside supported LV95 region');
    }

    if (!elevation.meters.isFinite) {
      throw ArgumentError('Invalid elevation');
    }
    if (elevation.reference == VerticalReference.unverified ||
        target == VerticalReference.unverified) {
      throw ArgumentError('Cannot transform an unverified height');
    }

    if (elevation.reference == target) {
      return elevation;
    }

    final endpoint = _endpoint(elevation.reference, target);

    final uri = Uri.https(_host, '/reframe/$endpoint', {
      'easting': position.easting.toStringAsFixed(3),
      'northing': position.northing.toStringAsFixed(3),
      'altitude': elevation.meters.toStringAsFixed(4),
      'format': 'json',
    });

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'REFRAME request failed: '
        'HTTP ${response.statusCode}',
      );
    }

    if (response.bodyBytes.length > 65536) {
      throw const FormatException('Unexpected REFRAME response size');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid REFRAME response');
    }

    final rawAltitude = decoded['altitude'];

    final double? transformed = switch (rawAltitude) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };

    if (transformed == null || !transformed.isFinite) {
      throw const FormatException('Invalid transformed altitude');
    }
    double? number(Object? value) => switch (value) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    final easting = number(decoded['easting']);
    final northing = number(decoded['northing']);
    // Height-only transformations must echo the requested horizontal position.
    if (easting == null ||
        northing == null ||
        !easting.isFinite ||
        !northing.isFinite ||
        (easting - position.easting).abs() > 0.01 ||
        (northing - position.northing).abs() > 0.01) {
      throw const FormatException('REFRAME returned a different position');
    }

    return ReferencedElevation(meters: transformed, reference: target);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
