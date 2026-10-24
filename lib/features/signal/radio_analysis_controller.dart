import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/route_planning_settings.dart';
import '../routes/route_editor_controller.dart';
import 'radio_analysis.dart';

class RadioAnalysisController extends ChangeNotifier {
  RadioAnalysisController(this.editor) {
    _remember();
    editor.addListener(_changed);
    editor.globe.addListener(_changed);
  }
  final RouteEditorController editor;
  late List<EditableWaypoint> _points;
  late RoutePlanningSettings _settings;
  late (int, int) _revision;
  int _operation = 0, completed = 0, total = 0, selected = 0;
  bool _disposed = false, loading = false;
  String? error;
  List<RadioPathResult>? result;
  RadioAnalysisPlan? _plan;
  List<double>? _heights;
  final Set<String> methods = {};
  void _remember() {
    _points = editor.points;
    _settings = editor.planning;
    _revision = editor.globe.terrainRevision;
  }

  void _changed() {
    if (_disposed ||
        (identical(_points, editor.points) &&
            identical(_settings, editor.planning) &&
            _revision == editor.globe.terrainRevision)) {
      return;
    }
    _remember();
    clear();
  }

  Future<void> _clearMap() async {
    try {
      await editor.globe.setSignalAnalysis(const {'rays': []});
    } catch (_) {
      /* Renderer may already have been replaced. */
    }
  }

  void clear() {
    ++_operation;
    loading = false;
    result = null;
    _plan = null;
    _heights = null;
    error = null;
    unawaited(_clearMap());
    if (!_disposed) notifyListeners();
  }

  Future<void> calculate() async {
    if (_disposed || loading) return;
    final token = ++_operation;
    bool current() => !_disposed && token == _operation;
    loading = true;
    error = null;
    result = null;
    completed = 0;
    total = 0;
    methods.clear();
    unawaited(_clearMap());
    notifyListeners();
    try {
      final settings = editor.planning.signal;
      if (settings == null) {
        throw ArgumentError('Set a pilot location and antenna height first');
      }
      if (!editor.globe.isReady || !editor.globe.terrainAvailable) {
        throw StateError(
          'Detailed terrain is unavailable. Retry after reconnecting terrain.',
        );
      }
      final plan = RadioAnalysisPlan.create([
        for (final p in editor.points) p.input,
      ], settings);
      total = plan.positions.length;
      final heights = <double>[];
      for (var offset = 0; offset < total; offset += 256) {
        if (!current()) return;
        final sample = await editor.globe.queryRouteTerrain(
          plan.positions.sublist(offset, (offset + 256).clamp(0, total)),
        );
        if (!current()) return;
        heights.addAll(sample.heights);
        methods.add(sample.samplingMethod);
        completed = heights.length;
        notifyListeners();
      }
      if (!current()) return;
      final calculated = await compute(calculateRadioAnalysis, (plan, heights));
      if (!current()) return;
      _plan = plan;
      _heights = heights;
      result = calculated;
      selected = 0;
      await _map();
    } catch (e) {
      if (current()) {
        result = null;
        _plan = null;
        _heights = null;
        error = '$e';
        await _clearMap();
      }
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(int index) async {
    if (result == null || index < 0 || index >= result!.length) return;
    selected = index;
    notifyListeners();
    try {
      await _map();
    } catch (_) {
      if (!_disposed) {
        error = 'Signal overlay unavailable. Recalculate to retry.';
        notifyListeners();
      }
    }
  }

  Future<void> _map() async {
    final paths = result, plan = _plan, heights = _heights;
    if (paths == null || plan == null || heights == null) return;
    await editor.globe.setSignalAnalysis({
      'pilot': {
        'latitude': plan.settings.pilot.latitude,
        'longitude': plan.settings.pilot.longitude,
        'height': heights[0] + plan.settings.antennaHeight,
      },
      'frequencyMhz': plan.settings.frequencyMhz,
      'fraction': plan.settings.clearanceFraction,
      'selected': selected,
      'rays': [
        for (var i = 0; i < paths.length; i++)
          {
            'latitude': paths[i].target.latitude,
            'longitude': paths[i].target.longitude,
            'height': paths[i].altitude,
            'ground': heights[i + 1],
            'state': paths[i].state.name,
          },
      ],
    });
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    editor.removeListener(_changed);
    editor.globe.removeListener(_changed);
    unawaited(_clearMap());
    super.dispose();
  }
}
