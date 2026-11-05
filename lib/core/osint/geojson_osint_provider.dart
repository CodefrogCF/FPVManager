import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:http/http.dart' as http;

import 'cached_osint_provider.dart';
import 'geojson_performance.dart';
import 'osint_dataset.dart';
import 'osint_provider_state.dart';
import 'osint_source.dart';

/// Adapter for GeoJSON FeatureCollections already normalized to WGS84.
///
/// Keeps the original conditional-request and streaming JSON transport, which
/// work on native and Web. Native dart:io negotiates and transparently decodes
/// gzip by default; browsers negotiate and decode supported encodings. There
/// is deliberately no second decompression pass on the returned byte stream.
class GeoJsonOsintProvider extends CachedOsintProvider<Map<String, dynamic>> {
  GeoJsonOsintProvider({
    required this.source,
    http.Client? client,
    super.cacheDuration,
    super.now,
    super.persistentCache,
    this.requestTimeout = const Duration(seconds: 45),
    this.bodyStallTimeout = const Duration(seconds: 20),
    this.conditionalRequests = true,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (source.coordinateReference != 'EPSG:4326') {
      throw ArgumentError('GeoJSON adapter requires EPSG:4326 data');
    }
    if (requestTimeout <= Duration.zero || bodyStallTimeout <= Duration.zero) {
      throw ArgumentError('Invalid HTTP timeout');
    }
  }

  @override
  final OsintSource source;
  final http.Client _client;
  final bool _ownsClient;

  /// Hard upper limit including headers, body and parsing.
  final Duration requestTimeout;

  /// Maximum time without receiving a body chunk (distinct from a slow but
  /// progressing transfer). Never disables the overall request limit.
  final Duration bodyStallTimeout;
  final bool conditionalRequests;
  Completer<void>? _abort;

  GeoJsonDownloadMetrics? lastDownloadMetrics;
  bool get isDownloading => _abort != null;

  @override
  bool reusesCachedPayload(
    OsintDataset<Map<String, dynamic>>? previous,
    OsintDataset<Map<String, dynamic>> current,
  ) =>
      previous != null &&
      lastDownloadMetrics?.usedNotModifiedResponse == true &&
      identical(previous.data, current.data) &&
      previous.fetchedAtUtc == current.fetchedAtUtc &&
      previous.sourceUrl == current.sourceUrl;

  /// Stop an active request or stream without discarding the cached dataset.
  /// An existing in-flight fetch completes with a typed cancellation failure;
  /// a future fetch may retry normally. No cached data is overwritten.
  void cancelPendingDownload() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final abort = _abort = Completer<void>();
    final trace = _DownloadTrace()..stopwatch.start();
    lastDownloadMetrics = null;
    try {
      final result = await _download(abort, trace).timeout(requestTimeout);
      _record(trace);
      return result;
    } on TimeoutException {
      cancelPendingDownload();
      _record(trace, failure: 'timeout');
      rethrow;
    } on _DownloadCancelled {
      _record(trace, failure: 'cancelled');
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.cancelled,
        message: 'Data download cancelled',
      );
    } on http.ClientException {
      if (abort.isCompleted) {
        _record(trace, failure: 'cancelled');
        throw OsintProviderException(
          providerId: id,
          kind: OsintFailureKind.cancelled,
          message: 'Data download cancelled',
        );
      }
      _record(trace, failure: 'network');
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.network,
        message: 'Unable to reach data source',
      );
    } on FormatException {
      _record(trace, failure: 'invalid-data');
      rethrow;
    } on OsintProviderException catch (error) {
      _record(trace, failure: error.kind.name);
      rethrow;
    } catch (_) {
      if (abort.isCompleted) {
        _record(trace, failure: 'cancelled');
        throw OsintProviderException(
          providerId: id,
          kind: OsintFailureKind.cancelled,
          message: 'Data download cancelled',
        );
      }
      _record(trace, failure: 'transport');
      rethrow;
    } finally {
      if (!abort.isCompleted) abort.complete();
      if (identical(_abort, abort)) _abort = null;
    }
  }

  void _record(_DownloadTrace trace, {String? failure}) {
    // On timeout the abandoned asynchronous task is still being cancelled.
    // Recording is only performed by the owning request, not a late callback.
    trace.stopwatch.stop();
    final elapsed = trace.stopwatch.elapsed;
    final headers =
        trace.headersTime ?? (trace.statusCode == 0 ? elapsed : Duration.zero);
    final body =
        trace.bodyTime ??
        (trace.statusCode != 0 && trace.headersTime != null
            ? elapsed - trace.headersTime!
            : Duration.zero);
    lastDownloadMetrics = GeoJsonDownloadMetrics(
      responseBytes: trace.bytes,
      downloadTime: headers + body,
      parseTime: trace.parseTime,
      totalTime: elapsed,
      httpStatusCode: trace.statusCode,
      headersTime: headers,
      bodyTime: body,
      declaredContentLength: trace.declaredLength,
      contentEncoding: trace.contentEncoding,
      conditionalRequest: trace.conditional,
      failure: failure,
    );
  }

  static String? _validator(String? value) =>
      value != null &&
          value.length <= 1024 &&
          !value.contains(RegExp(r'[\r\n]'))
      ? value
      : null;

  Future<OsintDataset<Map<String, dynamic>>> _download(
    Completer<void> abort,
    _DownloadTrace trace,
  ) async {
    final previous = cached;
    final request = http.AbortableRequest(
      'GET',
      sourceUri,
      abortTrigger: abort.future,
    );
    request.headers['Accept'] = 'application/geo+json, application/json';
    // Do not explicitly set Accept-Encoding: it is a forbidden header in Web
    // browsers, while dart:io already advertises gzip and auto-uncompresses.
    final etag = conditionalRequests ? _validator(previous?.httpEtag) : null;
    final modified = conditionalRequests
        ? _validator(previous?.httpLastModified)
        : null;
    if (etag != null) {
      request.headers['If-None-Match'] = etag;
    } else if (modified != null) {
      request.headers['If-Modified-Since'] = modified;
    }
    trace.conditional = etag != null || modified != null;

    final response = await Future.any<http.StreamedResponse>([
      _client.send(request),
      abort.future.then<http.StreamedResponse>(
        (_) => throw const _DownloadCancelled(),
      ),
    ]);
    if (abort.isCompleted) throw const _DownloadCancelled();
    trace.headersTime = trace.stopwatch.elapsed;
    trace.statusCode = response.statusCode;
    final length = response.contentLength;
    trace.declaredLength = length != null && length >= 0 ? length : null;
    trace.contentEncoding = response.headers['content-encoding']?.toLowerCase();
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
    if (response.statusCode == 304 && previous != null && trace.conditional) {
      await response.stream.listen((_) {}).cancel();
      if (abort.isCompleted) throw const _DownloadCancelled();
      trace.bodyTime = Duration.zero;
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
    // After automatic decompression Content-Length still reports compressed
    // wire bytes. On Web CORS may expose Content-Length but hide
    // Content-Encoding, so only native identity responses can verify it.
    final compressed =
        trace.contentEncoding != null && trace.contentEncoding != 'identity';
    final verifiableLength = !kIsWeb && !compressed;
    if (verifiableLength && (trace.declaredLength ?? 0) > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('GeoJSON dataset exceeds supported size');
    }
    final bodyStart = trace.stopwatch.elapsed;
    final payload = await _collectBytes(
      response.stream,
      abort,
      trace,
      maxBytes: maxBytes,
      expectedBytes: verifiableLength ? trace.declaredLength : null,
    );
    trace.bodyTime = trace.stopwatch.elapsed - bodyStart;
    if (abort.isCompleted) throw const _DownloadCancelled();
    final parseStart = trace.stopwatch.elapsed;
    // compute runs on a worker isolate on native Flutter. Web executes on
    // the UI thread; retaining this fallback avoids additional dependencies.
    late final Object? decoded;
    try {
      decoded = payload.length >= 256 * 1024
          ? await compute(_parseGeoJsonBytes, payload)
          : _parseGeoJsonBytes(payload);
    } finally {
      trace.parseTime = trace.stopwatch.elapsed - parseStart;
    }
    if (abort.isCompleted) throw const _DownloadCancelled();
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a GeoJSON FeatureCollection');
    }
    final received = nowUtc;
    return OsintDataset(
      source: source,
      data: decoded,
      fetchedAtUtc: received,
      lastCheckedAtUtc: received,
      cacheExpiresAtUtc: received.add(
        mustCheck ? Duration.zero : cacheDuration,
      ),
      httpLastModified: _validator(response.headers['last-modified']),
      httpEtag: _validator(response.headers['etag']),
      persistable: !noStore,
      requiresRevalidation: mustCheck,
    );
  }

  /// Collect only within the decoded byte budget; cancel a stalled stream
  /// immediately when a refresh is cancelled or its timeout expires.
  Future<Uint8List> _collectBytes(
    Stream<List<int>> stream,
    Completer<void> abort,
    _DownloadTrace trace, {
    required int maxBytes,
    required int? expectedBytes,
  }) async {
    final buffer = BytesBuilder(copy: false);
    final done = Completer<Uint8List>();
    late final StreamSubscription<List<int>> subscription;
    Timer? stallTimer;
    void fail(Object error, StackTrace stack) {
      if (done.isCompleted) return;
      stallTimer?.cancel();
      done.completeError(error, stack);
      unawaited(subscription.cancel());
    }

    void restartStallTimer() {
      stallTimer?.cancel();
      stallTimer = Timer(bodyStallTimeout, () {
        fail(
          TimeoutException('GeoJSON body stream stalled'),
          StackTrace.current,
        );
      });
    }

    subscription = stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        if (abort.isCompleted) {
          fail(const _DownloadCancelled(), StackTrace.current);
          return;
        }
        if (buffer.length + chunk.length > maxBytes) {
          fail(
            const FormatException('GeoJSON dataset exceeds supported size'),
            StackTrace.current,
          );
          return;
        }
        buffer.add(chunk);
        trace.bytes += chunk.length;
        restartStallTimer();
      },
      onError: (Object error, StackTrace stack) => fail(error, stack),
      onDone: () {
        if (done.isCompleted) return;
        stallTimer?.cancel();
        if (expectedBytes != null && expectedBytes != buffer.length) {
          fail(
            const FormatException('Incomplete GeoJSON response body'),
            StackTrace.current,
          );
        } else {
          done.complete(buffer.takeBytes());
        }
      },
      cancelOnError: true,
    );
    restartStallTimer();
    unawaited(
      abort.future.then((_) {
        if (!done.isCompleted) {
          fail(const _DownloadCancelled(), StackTrace.current);
        }
      }),
    );
    try {
      return await done.future;
    } finally {
      stallTimer?.cancel();
    }
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
    cancelPendingDownload();
    if (_ownsClient) _client.close();
    super.dispose();
  }
}

class _DownloadTrace {
  final Stopwatch stopwatch = Stopwatch();
  Duration? headersTime;
  Duration? bodyTime;
  Duration parseTime = Duration.zero;
  int bytes = 0;
  int statusCode = 0;
  int? declaredLength;
  String? contentEncoding;
  bool conditional = false;
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}

Object? _parseGeoJsonBytes(Uint8List bytes) => jsonDecode(utf8.decode(bytes));
