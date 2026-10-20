import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_osint_provider.dart';
import 'osint_dataset.dart';
import 'osint_provider_state.dart';
import 'osint_source.dart';

/// Adapter for GeoJSON FeatureCollections already normalized to WGS84.
class GeoJsonOsintProvider extends CachedOsintProvider<Map<String, dynamic>> {
  GeoJsonOsintProvider({
    required this.source,
    http.Client? client,
    super.cacheDuration,
    super.now,
    this.requestTimeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (source.coordinateReference != 'EPSG:4326') {
      throw ArgumentError('GeoJSON adapter requires EPSG:4326 data');
    }
    if (requestTimeout <= Duration.zero) throw ArgumentError('Invalid timeout');
  }

  @override
  final OsintSource source;
  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    late http.Response response;
    try {
      response = await _client
          .get(
            sourceUri,
            headers: {'Accept': 'application/geo+json, application/json'},
          )
          .timeout(requestTimeout);
    } on http.ClientException {
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.network,
        message: 'Unable to reach data source',
      );
    }
    if (response.statusCode != 200) {
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.http,
        httpStatus: response.statusCode,
        message: 'Data request failed: HTTP ${response.statusCode}',
      );
    }
    const maxBytes = 60 * 1024 * 1024;
    if (response.bodyBytes.length > maxBytes) {
      throw const FormatException('GeoJSON dataset exceeds supported size');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }
    final features = decoded['features'];
    final crs = decoded['crs'];
    if (crs != null &&
        (crs is! Map ||
            crs['type'] != 'name' ||
            crs['properties'] is! Map ||
            !const {
              'urn:ogc:def:crs:OGC:1.3:CRS84',
              'EPSG:4326',
              'urn:ogc:def:crs:EPSG::4326',
            }.contains(crs['properties']['name']))) {
      throw const FormatException('GeoJSON must use WGS84 longitude/latitude');
    }
    if (features is! List || features.any((feature) => feature is! Map)) {
      throw const FormatException('Invalid GeoJSON features array');
    }
    final fetchedAt = nowUtc;
    return OsintDataset(
      source: source,
      data: decoded,
      fetchedAtUtc: fetchedAt,
      cacheExpiresAtUtc: fetchedAt.add(cacheDuration),
      httpLastModified: response.headers['last-modified'],
    );
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
