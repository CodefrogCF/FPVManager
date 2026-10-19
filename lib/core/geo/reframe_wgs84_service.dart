import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geo_coordinate_service.dart';
import 'reframe_height_service.dart';

class SwissHeightResult {
  const SwissHeightResult({
    required this.position,
    required this.besselHeight,
    required this.ln02Height,
  });

  final Lv95Coordinate position;
  final ReferencedElevation besselHeight;
  final ReferencedElevation ln02Height;
}

// Combines official swisstopo REFRAME transformations.
//
// WGS84 ellipsoid -> Bessel ellipsoid -> LN02.
//
// Only use this service with a verified WGS84
// ellipsoidal height.
class ReframeWgs84Service {
  ReframeWgs84Service({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null {
    _heightService = ReframeHeightService(client: _client);
  }

  final http.Client _client;
  final bool _ownsClient;

  late final ReframeHeightService _heightService;

  static const _host = 'geodesy.geo.admin.ch';

  Future<SwissHeightResult> toLn02({
    required Wgs84Coordinate coordinate,
    required ReferencedElevation elevation,
  }) async {
    const geoService = GeoCoordinateService();

    if (!geoService.supportsWgs84(coordinate)) {
      throw ArgumentError('Coordinate outside supported Swiss region');
    }

    if (elevation.reference != VerticalReference.wgs84Ellipsoid) {
      throw ArgumentError('Expected a WGS84 ellipsoidal height');
    }

    if (!elevation.meters.isFinite) {
      throw ArgumentError('Invalid elevation');
    }

    // The REFRAME API uses the parameter names
    // easting and northing for longitude/latitude.
    final uri = Uri.https(_host, '/reframe/wgs84tolv95', {
      'easting': coordinate.longitude.toStringAsFixed(8),
      'northing': coordinate.latitude.toStringAsFixed(8),
      'altitude': elevation.meters.toStringAsFixed(4),
      'format': 'json',
    });

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'REFRAME WGS84 request failed: '
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

    final easting = _parseNumber(decoded['easting']);
    final northing = _parseNumber(decoded['northing']);
    final bessel = _parseNumber(decoded['altitude']);

    if (easting == null || northing == null || bessel == null) {
      throw const FormatException('Invalid REFRAME transformation values');
    }

    final position = Lv95Coordinate(easting: easting, northing: northing);

    if (!geoService.supportsLv95(position)) {
      throw const FormatException(
        'REFRAME returned unsupported LV95 coordinates',
      );
    }

    final besselHeight = ReferencedElevation(
      meters: bessel,
      reference: VerticalReference.besselEllipsoid,
    );

    final ln02Height = await _heightService.transform(
      position: position,
      elevation: besselHeight,
      target: VerticalReference.ln02,
    );

    return SwissHeightResult(
      position: position,
      besselHeight: besselHeight,
      ln02Height: ln02Height,
    );
  }

  double? _parseNumber(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };

    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  void dispose() {
    _heightService.dispose();

    if (_ownsClient) {
      _client.close();
    }
  }
}
