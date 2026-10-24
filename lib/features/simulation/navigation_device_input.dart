import 'dart:async';

import 'package:flutter/services.dart';

/// Android motion events bypass inconsistent WebView gamepad delivery.
/// One platform stream, no identifiers retained, bounded/coalesced bridge work.
class NavigationDeviceInput {
  NavigationDeviceInput(this.send, {Duration Function()? elapsed})
    : _elapsed = elapsed ?? _monotonicTime {
    _subscription = _events.listen(
      _event,
      onError: (Object error) {
        _latest = _neutral;
      },
    );
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _flush());
  }
  final Future<void> Function(Map<String, dynamic>) send;
  static final _clock = Stopwatch()..start();
  static Duration _monotonicTime() => _clock.elapsed;
  final Duration Function() _elapsed;
  static const _channel = MethodChannel(
    'com.codefrog.fpvmanager/navigation_input',
  );
  static final _events = const EventChannel(
    'com.codefrog.fpvmanager/navigation_events',
  ).receiveBroadcastStream();
  static final Set<NavigationDeviceInput> _enabledOwners = {};
  static const _neutral = <String, dynamic>{
    'forward': 0.0,
    'right': 0.0,
    'yaw': 0.0,
    'pitch': 0.0,
    'vertical': 0.0,
    'reset': false,
    'exit': false,
    'connected': false,
  };
  late final StreamSubscription<dynamic> _subscription;
  Timer? _timer;
  bool _disposed = false, _enabled = false, _sending = false;
  Map<String, dynamic>? _latest;
  Duration? _received;
  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    _latest = null;
    _received = null;
    final previous = _enabledOwners.isNotEmpty;
    if (enabled) {
      _enabledOwners.add(this);
    } else {
      _enabledOwners.remove(this);
    }
    if (previous != _enabledOwners.isNotEmpty) {
      unawaited(
        _channel
            .invokeMethod<void>('setEnabled', {
              'enabled': _enabledOwners.isNotEmpty,
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _event(dynamic value) {
    if (!_enabled || _disposed || value is! Map) return;
    final frame = <String, dynamic>{};
    for (final name in ['forward', 'right', 'yaw', 'pitch', 'vertical']) {
      final v = value[name];
      if (v is! num || !v.isFinite || v.abs() > 1) return;
      frame[name] = v.toDouble();
    }
    for (final name in ['reset', 'exit', 'connected']) {
      if (value[name] is! bool) return;
      frame[name] = value[name];
    }
    _latest = frame;
    _received = _elapsed();
  }

  Future<void> _flush() async {
    if (_disposed || !_enabled || _sending || _latest == null) return;
    final stale =
        _received == null ||
        _elapsed() - _received! > const Duration(milliseconds: 250);
    final frame = stale ? _neutral : _latest!;
    _sending = true;
    try {
      await send(frame);
    } catch (_) {
      /* Renderer lifecycle invalidates old input. */
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    setEnabled(false);
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription.cancel());
  }
}
