/// Local, in-memory HTTP diagnostics. No measurements are uploaded.
///
/// Header time includes resolver, TCP/TLS setup, request dispatch and time to
/// the response headers. These phases cannot be separated by package:http.
/// Body time measures response stream consumption, including transparent gzip
/// decompression performed by the platform HTTP stack. `responseBytes` counts
/// decoded stream bytes; `declaredContentLength` is the original HTTP length
/// (often the *compressed* length) and must not be compared to responseBytes
/// for compressed responses.
class GeoJsonDownloadMetrics {
  const GeoJsonDownloadMetrics({
    required this.responseBytes,
    required this.downloadTime,
    required this.parseTime,
    required this.totalTime,
    this.httpStatusCode = 200,
    this.headersTime = Duration.zero,
    this.bodyTime = Duration.zero,
    this.declaredContentLength,
    this.contentEncoding,
    this.conditionalRequest = false,
    this.failure,
    this.retryCount = 0,
  });

  final int responseBytes;
  final Duration downloadTime;
  final Duration parseTime;
  final Duration totalTime;
  final int httpStatusCode;
  final Duration headersTime;
  final Duration bodyTime;
  final int? declaredContentLength;
  final String? contentEncoding;
  final bool conditionalRequest;

  /// Sanitized category only, never a URL, token or server response body.
  final String? failure;

  /// The OSINT adapter intentionally performs no implicit retry.
  final int retryCount;

  bool get usedNotModifiedResponse => httpStatusCode == 304;
  String get summary =>
      'HTTP ${httpStatusCode == 0 ? "pending" : httpStatusCode} · '
      '$responseBytes decoded bytes · '
      'headers ${headersTime.inMilliseconds} ms · '
      'body ${bodyTime.inMilliseconds} ms · '
      'decode/parse ${parseTime.inMilliseconds} ms · '
      'total ${totalTime.inMilliseconds} ms · '
      'encoding ${contentEncoding ?? "unspecified"} · '
      'declared wire bytes ${declaredContentLength ?? "unknown"} · '
      'conditional $conditionalRequest · retries $retryCount'
      '${failure == null ? "" : " · failure $failure"}';
}
