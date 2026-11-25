/// Bounded diagnostics. Times are elapsed monotonic milliseconds, never wall time.
/// Snapshots/percentiles are built only when requested by the optional panel.
class LiveRadioDiagnostics {
  String quality = 'unknown';
  String? errorCategory;
  String? errorDetail;
  String provider = 'unavailable';
  int requestId = 0, generation = 0, failures = 0;
  int samples = 0, validSamples = 0, missingSamples = 0;
  int attempts = 0, successes = 0;
  double? startedMs, completedMs, durationMs;
  final List<double> _latencies = [];
  final List<Map<String, Object?>> _history = [];

  void start(int id, int epoch, double ms) {
    requestId = id;
    generation = epoch;
    startedMs = ms;
    samples = validSamples = missingSamples = 0;
    errorDetail = null;
    ++attempts;
  }

  void finish(double ms, {required bool success, String? error}) {
    completedMs = ms;
    durationMs = (ms - startedMs!).clamp(0, double.infinity);
    _latencies.add(durationMs!);
    if (_latencies.length > 64) _latencies.removeAt(0);
    if (success) {
      ++successes;
      failures = 0;
    } else if (error != 'SUPERSEDED') {
      ++failures;
    }
    errorCategory = error;
    _history.add({
      'requestId': requestId,
      'generation': generation,
      'startMs': startedMs,
      'completionMs': ms,
      'durationMs': durationMs,
      'samples': samples,
      'validSamples': validSamples,
      'missingSamples': missingSamples,
      'errorCategory': error,
      'errorDetail': errorDetail,
    });
    if (_history.length > 64) _history.removeAt(0);
  }

  Map<String, Object?> snapshot() {
    final sorted = [..._latencies]..sort();
    double? percentile(double p) => sorted.isEmpty
        ? null
        : sorted[((sorted.length * p).ceil() - 1).clamp(0, sorted.length - 1)];
    return {
      'quality': quality,
      'error': errorCategory,
      'errorDetail': errorDetail,
      'provider': provider,
      'requestId': requestId,
      'generation': generation,
      'failures': failures,
      'samples': samples,
      'validSamples': validSamples,
      'missingSamples': missingSamples,
      'attempts': attempts,
      'successes': successes,
      'startMs': startedMs,
      'completionMs': completedMs,
      'durationMs': durationMs,
      'p50Ms': percentile(.5),
      'p95Ms': percentile(.95),
      'history': List<Map<String, Object?>>.unmodifiable(_history),
    };
  }
}
