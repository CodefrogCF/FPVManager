import 'dart:async';

import 'package:flutter/foundation.dart';

import '../mobility/navigation_location.dart';

/// Device-local foreground location. Coordinates are never persisted or sent
/// to a geocoder; the renderer receives only the currently displayed fix.
class GlobeLocationController extends ChangeNotifier {
  GlobeLocationController({
    NavigationLocationSource? source,
    required this.send,
    DateTime Function()? now,
    this.staleAfter = const Duration(seconds: 30),
  }) : _source = source ?? const DeviceNavigationLocation(forNavigation: false),
       _now = now ?? DateTime.now;

  final NavigationLocationSource _source;
  final Future<void> Function(Map<String, dynamic>) send;
  final DateTime Function() _now;
  final Duration staleAfter;
  StreamSubscription<NavigationFix>? _subscription;
  Timer? _timer;
  NavigationFix? fix;
  bool enabled = false, following = false, busy = false;
  bool _foreground = true, _suspended = false, _disposed = false;
  bool _recenter = false;
  DateTime? _waitingSince;
  int _generation = 0;
  String? message;
  Future<void> _writes = Future.value();
  Map<String, dynamic>? _pending;
  bool _sending = false;

  bool get stale =>
      fix != null &&
      (_now().toUtc().difference(fix!.timeUtc) > staleAfter ||
          !_foreground ||
          _suspended ||
          busy ||
          message != null);
  double? get heading {
    final value = fix;
    if (value == null ||
        stale ||
        value.speedMetersPerSecond?.isFinite != true ||
        value.headingAccuracyDegrees?.isFinite != true ||
        (value.speedMetersPerSecond ?? 0) < 1 ||
        (value.headingAccuracyDegrees ?? double.infinity) > 20 ||
        (value.headingAccuracyDegrees ?? -1) < 0 ||
        value.headingDegrees == null ||
        !value.headingDegrees!.isFinite ||
        value.headingDegrees! < 0 ||
        value.headingDegrees! >= 360) {
      return null;
    }
    return value.headingDegrees;
  }

  Future<void> locate() async {
    _recenter = true;
    if (!enabled || _subscription == null || fix == null && !busy || stale) {
      enabled = true;
      await _start();
    } else {
      await _publish();
    }
  }

  Future<void> setFollowing(bool value) async {
    following = value;
    if (value && !enabled) await locate();
    await _publish();
    if (!_disposed) notifyListeners();
  }

  Future<void> disable() async {
    enabled = following = _recenter = false;
    await _stop();
    fix = null;
    message = null;
    await _publish();
    if (!_disposed) notifyListeners();
  }

  Future<void> foreground(bool value) async {
    if (_foreground == value) return;
    _foreground = value;
    await _lifecycle();
  }

  Future<void> suspended(bool value) async {
    if (_suspended == value) return;
    _suspended = value;
    await _lifecycle();
  }

  Future<void> _lifecycle() async {
    if (_disposed || !enabled) return;
    await _stop();
    if (_disposed || !enabled) return;
    if (enabled && _foreground && !_suspended) await _start();
    await _publish();
    if (!_disposed) notifyListeners();
  }

  Future<void> _stop() async {
    _generation++;
    _pending = null;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    busy = false;
    await subscription?.cancel();
  }

  Future<void> _start() async {
    await _stop();
    if (_disposed || !enabled || !_foreground || _suspended) return;
    final generation = _generation;
    busy = true;
    _waitingSince = _now();
    message = null;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (generation != _generation || _disposed) return;
      if (busy &&
          _now().difference(_waitingSince!) >= const Duration(seconds: 20)) {
        // The stream may still deliver a fix after a slow GPS acquisition.
        message =
            'Standort wird gesucht. Bei Bedarf im Freien erneut versuchen.';
        busy = false;
      }
      unawaited(_publish());
      notifyListeners();
    });
    _subscription = _source.watch().listen(
      (value) {
        if (_disposed || generation != _generation) return;
        if (!value.point.latitude.isFinite ||
            !value.point.longitude.isFinite ||
            value.point.latitude.abs() > 90 ||
            value.point.longitude.abs() > 180 ||
            !value.accuracyMeters.isFinite ||
            value.accuracyMeters < 0 ||
            value.timeUtc.toUtc().isAfter(
              _now().toUtc().add(const Duration(seconds: 5)),
            )) {
          return;
        }
        if (fix != null && value.timeUtc.isBefore(fix!.timeUtc)) return;
        fix = value;
        busy = false;
        message = null;
        unawaited(_publish());
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed || generation != _generation) return;
        enabled = following = false;
        _timer?.cancel();
        busy = false;
        message = error is FormatException ? error.message : 'Standort nicht verfügbar. Berechtigung, Standortdienste und HTTPS prüfen.';
        unawaited(_publish());
        notifyListeners();
      },
      onDone: () {
        if (_disposed || generation != _generation) return;
        _subscription = null;
        enabled = following = false;
        _timer?.cancel();
        busy = false;
        message ??= 'Keine Standortaktualisierung verfügbar. Erneut orten.';
        unawaited(_publish());
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  Future<void> rendererReady() => _publish();

  Future<void> _publish() {
    if (_disposed) return Future.value();
    final value = fix;
    final recenter = _recenter && value != null && !stale;
    final command = <String, dynamic>{
      'type': 'set-device-location',
      'enabled': enabled && !_suspended,
      'follow': following && _foreground && !_suspended && !stale,
      'recenter': recenter,
      'fix': !enabled || value == null
          ? null
          : {
              'latitude': value.point.latitude,
              'longitude': value.point.longitude,
              'accuracyMeters': value.accuracyMeters,
              'timeUtc': value.timeUtc.toUtc().toIso8601String(),
              'stale': stale,
              'heading': heading,
            },
    };
    _pending = command;
    if (_sending) return _writes;
    _sending = true;
    _writes = _drain();
    return _writes;
  }

  Future<void> _drain() async {
    try {
      while (!_disposed && _pending != null) {
        final command = _pending!;
        final generation = _generation;
        _pending = null;
        try {
          await send(command);
          if (command['recenter'] == true && generation == _generation) {
            _recenter = false;
            _pending?['recenter'] = false;
          }
        } catch (_) {
          /* Restored when the renderer is ready. */
        }
      }
    } finally {
      _sending = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stop());
    super.dispose();
  }
}
