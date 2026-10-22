import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show compute;

import 'geojson_performance.dart';

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
    super.persistentCache,
    this.requestTimeout = const Duration(seconds: 45),
    this.conditionalRequests = true,
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
  final bool conditionalRequests;
  Completer<void>? _abort;

  GeoJsonDownloadMetrics? lastDownloadMetrics;

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final abort = _abort = Completer<void>();
    try {
      return await _download(abort.future).timeout(requestTimeout);
    } on http.ClientException {
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.network,
        message: 'Unable to reach data source',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      if (identical(_abort, abort)) _abort = null;
    }
  }

  static String? _validator(String? value) =>
      value != null &&
          value.length <= 1024 &&
          !value.contains(RegExp(r'[\r\n]'))
      ? value
      : null;

  Future<OsintDataset<Map<String, dynamic>>> _download(
    Future<void> abort,
  ) async {
    final overallTimer = Stopwatch()..start();
    final networkTimer = Stopwatch()..start();
    final previous = cached;
    final request = http.AbortableRequest(
      'GET',
      sourceUri,
      abortTrigger: abort,
    );
    request.headers['Accept'] = 'application/geo+json, application/json';
    final etag = conditionalRequests ? _validator(previous?.httpEtag) : null;
    final modified = conditionalRequests
        ? _validator(previous?.httpLastModified)
        : null;
    if (etag != null) {
      request.headers['If-None-Match'] = etag;
    } else if (modified != null) {
      request.headers['If-Modified-Since'] = modified;
    }
    final response = await _client.send(request);
    final control = (response.headers['cache-control'] ?? '').toLowerCase();
    final noStore = control.split(',').any((part) => part.trim() == 'no-store');
    final mustCheck =
        noStore ||
        control.split(',').any((part) => part.trim() == 'no-cache') ||
        response.statusCode == 304 &&
            !response.headers.containsKey('cache-control') &&
            previous?.requiresRevalidation == true;
    final checked = nowUtc;
    final expires = checked.add(mustCheck ? Duration.zero : cacheDuration);
    if (response.statusCode == 304 &&
        previous != null &&
        (etag != null || modified != null)) {
      await response.stream.listen((_) {}).cancel();
      return OsintDataset(
        source: previous.source,
        data: previous.data,
        fetchedAtUtc: previous.fetchedAtUtc,
        lastCheckedAtUtc: checked,
        cacheExpiresAtUtc: expires,
        publishedAtUtc: previous.publishedAtUtc,
        validity: previous.validity,
        httpEtag: _validator(response.headers['etag']) ?? previous.httpEtag,
        httpLastModified:
            _validator(response.headers['last-modified']) ??
            previous.httpLastModified,
        persistable: previous.persistable && !noStore,
        requiresRevalidation: mustCheck,
      );
    }
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.http,
        httpStatus: response.statusCode,
        message: 'Data request failed: HTTP ${response.statusCode}',
      );
    }
    const maxBytes = 60 * 1024 * 1024;
    if ((response.contentLength ?? 0) > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('GeoJSON dataset exceeds supported size');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('GeoJSON dataset exceeds supported size');
      }
      bytes.add(chunk);
    }
    networkTimer.stop();
    final size = bytes.length;
    final parseTimer = Stopwatch()..start();
    // compute runs on a worker isolate on native Flutter targets. Flutter Web
    // executes synchronously; the benchmark exposes its remaining parse cost.
    final payload = bytes.takeBytes();
    final decoded = size >= 256 * 1024
        ? await compute(_parseGeoJsonBytes, payload)
        : _parseGeoJsonBytes(payload);
    parseTimer.stop();
    overallTimer.stop();
    lastDownloadMetrics = GeoJsonDownloadMetrics(
      responseBytes: size,
      downloadTime: networkTimer.elapsed,
      parseTime: parseTimer.elapsed,
      totalTime: overallTimer.elapsed,
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }
    return OsintDataset(
      source: source,
      data: decoded,
      fetchedAtUtc: nowUtc,
      lastCheckedAtUtc: nowUtc,
      cacheExpiresAtUtc: nowUtc.add(mustCheck ? Duration.zero : cacheDuration),
      httpLastModified: _validator(response.headers['last-modified']),
      httpEtag: _validator(response.headers['etag']),
      persistable: !noStore,
      requiresRevalidation: mustCheck,
    );
  }

  @override
  void validateData(Map<String, dynamic> data) {
    if (data['type'] != 'FeatureCollection') {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }
    final features = data['features'];
    final crs = data['crs'];
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
  }

  @override
  void dispose() {
    if (_abort?.isCompleted == false) _abort!.complete();
    if (_ownsClient) _client.close();
    super.dispose();
  }
}

Object? _parseGeoJsonBytes(Uint8List bytes) => jsonDecode(utf8.decode(bytes));
