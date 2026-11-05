import 'package:flutter/widgets.dart';

/// Opt-in diagnostics for Flutter startup, navigation and renderer lifecycle.
///
/// Enable with `--dart-define=FPV_LIFECYCLE_PROFILE=true`. Only durations,
/// counters and generic lifecycle phase names are logged: never positions,
/// URLs, cache content or user data. Not a GPU-memory profiler.
class AppLifecycleProbe {
  AppLifecycleProbe._();

  static const enabled = bool.fromEnvironment('FPV_LIFECYCLE_PROFILE');
  static final Stopwatch _clock = Stopwatch();
  static final Map<String, int> _counts = <String, int>{};
  static int? _lastRendererLoadingMs;
  static int? _lastBackgroundMs;
  static int? _lastResumeMs;
  static bool _firstReady = false;

  static void start() {
    if (!enabled || _clock.isRunning) return;
    _clock.start();
    record('app-start');
  }

  static void record(String phase, {int? durationMs}) {
    if (!enabled) return;
    if (!_clock.isRunning) start();
    _counts[phase] = (_counts[phase] ?? 0) + 1;
    final duration = durationMs == null ? '' : ' durationMs=$durationMs';
    debugPrint(
      '[FPVManager lifecycle] phase=$phase '
      'elapsedMs=${_clock.elapsedMilliseconds} '
      'count=${_counts[phase]}$duration',
    );
  }

  static void rendererLoading() {
    if (!enabled) return;
    _lastRendererLoadingMs = _clock.elapsedMilliseconds;
    record('renderer-loading');
  }

  static void rendererReady({required bool terrainAvailable}) {
    if (!enabled) return;
    final now = _clock.elapsedMilliseconds;
    if (!_firstReady) {
      _firstReady = true;
      record('first-globe-ready', durationMs: now);
    }
    final began = _lastRendererLoadingMs;
    record(
      terrainAvailable ? 'renderer-ready-terrain' : 'renderer-ready-no-terrain',
      durationMs: began == null ? null : now - began,
    );
    _lastRendererLoadingMs = null;
    final resume = _lastResumeMs;
    if (resume != null) {
      record('resume-to-globe-ready', durationMs: now - resume);
      _lastResumeMs = null;
    }
  }

  static void appState(AppLifecycleState state) {
    if (!enabled) return;
    final now = _clock.elapsedMilliseconds;
    if (state == AppLifecycleState.paused) {
      _lastBackgroundMs = now;
      record('app-paused');
    } else if (state == AppLifecycleState.resumed) {
      final previous = _lastBackgroundMs;
      _lastResumeMs = now;
      record(
        'app-resumed',
        durationMs: previous == null ? null : now - previous,
      );
      _lastBackgroundMs = null;
    }
  }

  static Map<String, int> snapshot() => Map<String, int>.unmodifiable(_counts);
}

/// Measures only time until the first Flutter frame after a route operation.
/// This is not the full route-transition animation or time-to-usable-data.
class AppLifecycleRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _afterFrame('route-push-first-frame');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _afterFrame('route-pop-first-frame');
  }

  static void _afterFrame(String name) {
    if (!AppLifecycleProbe.enabled) return;
    final stopwatch = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stopwatch.stop();
      AppLifecycleProbe.record(name, durationMs: stopwatch.elapsedMilliseconds);
    });
  }
}
