/// Local diagnostic timings only; no telemetry or external reporting.
/// Measurements are per successful HTTP 200 response, not cached re-use.
class GeoJsonDownloadMetrics {
  const GeoJsonDownloadMetrics({
    required this.responseBytes,
    required this.downloadTime,
    required this.parseTime,
    required this.totalTime,
    this.httpStatusCode = 200,
  });
  final int responseBytes;
  final Duration downloadTime;
  final Duration parseTime;
  final Duration totalTime;
  final int httpStatusCode;
  bool get usedNotModifiedResponse => httpStatusCode == 304;
  String get summary =>
      'HTTP $httpStatusCode · $responseBytes bytes · network ${downloadTime.inMilliseconds} ms · '
      'decode/parse ${parseTime.inMilliseconds} ms · '
      'total ${totalTime.inMilliseconds} ms';
}
