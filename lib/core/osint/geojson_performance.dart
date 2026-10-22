/// Local diagnostic timings only; no telemetry or external reporting.
/// Measurements are per successful HTTP 200 response, not cached re-use.
class GeoJsonDownloadMetrics {
  const GeoJsonDownloadMetrics({
    required this.responseBytes,
    required this.downloadTime,
    required this.parseTime,
    required this.totalTime,
  });
  final int responseBytes;
  final Duration downloadTime;
  final Duration parseTime;
  final Duration totalTime;
  String get summary =>
      '$responseBytes bytes · HTTP ${downloadTime.inMilliseconds} ms · '
      'decode/parse ${parseTime.inMilliseconds} ms · '
      'total ${totalTime.inMilliseconds} ms';
}
