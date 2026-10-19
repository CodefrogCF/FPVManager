import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/osint/osint_dataset.dart';
import '../../../core/osint/osint_provider.dart';

class SwissUasProvider implements OsintProvider<Map<String, dynamic>> {
  SwissUasProvider({
    http.Client? client,
    this.cacheDuration = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _now = now ?? DateTime.now;

  static final Uri datasetUri = Uri.parse(
    'https://data.geo.admin.ch/'
    'ch.bazl.einschraenkungen-drohnen/'
    'einschraenkungen-drohnen/'
    'einschraenkungen-drohnen_4326.geojson',
  );

  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;

  final Duration cacheDuration;

  OsintDataset<Map<String, dynamic>>? _cached;
  Future<OsintDataset<Map<String, dynamic>>>? _inFlight;

  @override
  String get id => 'ch.bazl.uas-zones';

  @override
  Uri get sourceUri => datasetUri;

  OsintDataset<Map<String, dynamic>>? get cached => _cached;

  @override
  Future<OsintDataset<Map<String, dynamic>>> fetch({
    bool forceRefresh = false,
  }) {
    final pending = _inFlight;

    if (pending != null) {
      return pending;
    }

    final cached = _cached;

    if (!forceRefresh && cached != null) {
      final age = _now().toUtc().difference(cached.fetchedAtUtc);

      if (!age.isNegative && age < cacheDuration) {
        return Future.value(cached);
      }
    }

    final request = _download();

    _inFlight = request;

    return request.whenComplete(() {
      _inFlight = null;
    });
  }

  Future<OsintDataset<Map<String, dynamic>>> _download() async {
    final response = await _client
        .get(
          sourceUri,
          headers: {'Accept': 'application/geo+json, application/json'},
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw StateError(
        'Swiss UAS request failed: '
        'HTTP ${response.statusCode}',
      );
    }

    // Avoid unexpectedly processing very large responses.
    const maxBytes = 60 * 1024 * 1024;

    if (response.bodyBytes.length > maxBytes) {
      throw const FormatException('Swiss UAS dataset exceeds supported size');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Swiss UAS dataset must be a JSON object');
    }

    if (decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }

    final features = decoded['features'];

    if (features is! List || features.any((feature) => feature is! Map)) {
      throw const FormatException('Invalid GeoJSON features array');
    }

    final dataset = OsintDataset<Map<String, dynamic>>(
      providerId: id,
      sourceUrl: sourceUri,
      data: decoded,
      fetchedAtUtc: _now().toUtc(),
      httpLastModified: response.headers['last-modified'],
    );

    _cached = dataset;

    return dataset;
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
