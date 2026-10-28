import 'dart:async';

import 'package:flutter/foundation.dart';

import 'wind_field.dart';
import 'wind_field_service.dart';

class WindMapController extends ChangeNotifier {
  WindMapController({
    required this.send,
    WindFieldService? service,
    DateTime Function()? now,
  }) : _service = service ?? WindFieldService(),
       _now = now ?? DateTime.now;
  final Future<void> Function(Map<String, dynamic>) send;
  final WindFieldService _service;
  final DateTime Function() _now;
  WindFieldSnapshot? snapshot;
  bool visible = false,
      affectFlight = false,
      loading = false,
      refreshFailed = false;
  bool _disposed = false,
      _foreground = true,
      _flying = false,
      _rendering = true;
  int _operation = 0;
  String? error;
  String rendererState = 'unavailable';
  void rendererStatus(String state) {
    if (rendererState == state) return;
    rendererState = state;
    _changed();
  }

  WindTimeMode mode = WindTimeMode.current;
  DateTime? forecastUtc;
  Timer? _refresh;
  DateTime? _lastAttempt;
  bool get expired => snapshot?.expiredAt(_now()) ?? false;
  Map<String, dynamic> command() => {
    'type': 'set-wind-field',
    'visible': visible,
    'affectFlight': affectFlight,
    'field': snapshot?.toJson(),
  };
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _push() async {
    if (!_disposed) await send(command());
  }

  Future<void> flags({bool? arrows, bool? physics}) async {
    if (_disposed) return;
    visible = arrows ?? visible;
    affectFlight = physics ?? affectFlight;
    _schedule();
    _changed();
    try {
      await _push();
    } catch (_) {
      error = 'Winddarstellung konnte nicht aktualisiert werden.';
      _changed();
    }
  }

  Future<void> load({
    required double latitude,
    required double longitude,
    required WindTimeMode timeMode,
    DateTime? timeUtc,
    double radiusMeters = 1500,
  }) async {
    if (_disposed) return;
    final previous = snapshot;
    final same =
        previous != null &&
        mode == timeMode &&
        forecastUtc == timeUtc?.toUtc() &&
        (previous.centerLatitude - latitude).abs() < 1e-8 &&
        (previous.centerLongitude - longitude).abs() < 1e-8 &&
        previous.radiusMeters == radiusMeters;
    final operation = ++_operation;
    _lastAttempt = _now().toUtc();
    _service.cancel();
    _refresh?.cancel();
    loading = true;
    error = null;
    refreshFailed = false;
    mode = timeMode;
    forecastUtc = timeUtc?.toUtc();
    if (!same) snapshot = null;
    _changed();
    try {
      if (!same) await _push();
      if (_disposed || operation != _operation) return;
      final next = await _service.load(
        latitude: latitude,
        longitude: longitude,
        mode: timeMode,
        forecastUtc: timeUtc?.toUtc(),
        radiusMeters: radiusMeters,
      );
      if (_disposed || operation != _operation) return;
      snapshot = next;
      await _push();
    } catch (e) {
      if (!_disposed && operation == _operation) {
        error = e.toString();
        refreshFailed = snapshot != null;
      }
    } finally {
      if (!_disposed && operation == _operation) {
        loading = false;
        _schedule();
        _changed();
      }
    }
  }

  Future<void> refresh() async {
    final last = snapshot;
    if (last == null || loading) return;
    await load(
      latitude: last.centerLatitude,
      longitude: last.centerLongitude,
      timeMode: mode,
      timeUtc: forecastUtc,
      radiusMeters: last.radiusMeters,
    );
  }

  Future<void> rendererReady() async {
    if (snapshot == null && !visible && !affectFlight) return;
    try {
      await _push();
    } catch (_) {
      error = 'Winddarstellung konnte nicht wiederhergestellt werden.';
      _changed();
    }
  }

  void foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _schedule();
  }

  void flying(bool value) {
    if (_flying == value) return;
    _flying = value;
    _schedule();
  }

  void rendering(bool value) {
    if (_rendering == value) return;
    _rendering = value;
    _schedule();
  }

  void _schedule() {
    _refresh?.cancel();
    _refresh = null;
    if (_disposed ||
        !_foreground ||
        !_rendering ||
        loading ||
        snapshot == null ||
        mode != WindTimeMode.current ||
        !(visible || affectFlight && _flying)) {
      return;
    }
    final elapsed = _now().toUtc().difference(
      _lastAttempt ?? snapshot!.retrievedUtc,
    );
    final remaining = const Duration(minutes: 15) - elapsed;
    _refresh = Timer(
      remaining.isNegative ? const Duration(seconds: 1) : remaining,
      () => unawaited(refresh()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    _refresh?.cancel();
    _service.dispose();
    super.dispose();
  }
}
