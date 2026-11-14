import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/route_planning_settings.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';
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
  List<RouteProfilePoint>? _route;
  SignalSettings? _signal;
  double? _pilotGround;
  RadioPathResult? selectedProfile;
  bool loadingProfile = false;
  int _selection = 0;
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
    _route = null;
    _signal = null;
    _pilotGround = null;
    selectedProfile = null;
    loadingProfile = false;
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
    selectedProfile = null;
    loadingProfile = false;
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
      final points = [for (final p in editor.points) p.input];
      final plan = RouteSamplingPlan.create(points, spacing: 100);
      total = plan.samples.length;
      final ground = await _sample([
        settings.pilot,
        for (final sample in plan.samples) sample.position,
      ], current);
      if (ground == null) return;
      final route = RouteAnalysis.calculate(
        points,
        plan,
        ground.sublist(1),
        const RoutePlanningSettings(),
      ).profile;
      final paths = <RadioPathResult>[];
      for (final batch in RadioAnalysisBatch.forRoute(route, settings)) {
        final heights = await _sample(batch.positions, current);
        if (heights == null) return;
        final calculated = await compute(calculateRadioBatch, (
          batch,
          settings,
          ground.first,
          heights,
          false,
        ));
        if (!current()) return;
        paths.addAll(calculated);
        completed = paths.length;
        notifyListeners();
      }
      _route = route;
      _signal = settings;
      _pilotGround = ground.first;
      result = List.unmodifiable(paths);
      selected = 0;
      await _map();
      if (current()) await _loadProfile();
    } catch (e) {
      if (current()) {
        result = null;
        _route = null;
        _signal = null;
        _pilotGround = null;
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

  Future<List<double>?> _sample(
    List<Wgs84Coordinate> positions,
    bool Function() current,
  ) async {
    final heights = <double>[];
    for (var offset = 0; offset < positions.length; offset += 256) {
      if (!current()) return null;
      final sample = await editor.globe.queryRouteTerrain(
        positions.sublist(offset, (offset + 256).clamp(0, positions.length)),
      );
      if (!current()) return null;
      heights.addAll(sample.heights);
      methods.add(sample.samplingMethod);
    }
    return current() ? heights : null;
  }

  Future<void> _loadProfile() async {
    final paths = result!, target = selected, request = ++_selection;
    bool current() =>
        !_disposed && identical(result, paths) && request == _selection;
    selectedProfile = paths[target];
    final known = paths[target].state != RadioPathState.unknown;
    loadingProfile = known;
    notifyListeners();
    if (!known || !current()) return;
    try {
      final settings = _signal!, pilotGround = _pilotGround!;
      final batch = RadioAnalysisBatch.forRoute([
        _route![target],
      ], settings).single;
      final heights = await _sample(batch.positions, current);
      if (heights == null) return;
      final detailed = await compute(calculateRadioBatch, (
        batch,
        settings,
        pilotGround,
        heights,
        true,
      ));
      if (current()) selectedProfile = detailed.single;
    } catch (_) {
      if (current()) error = 'Communication profile unavailable. Select the path again to retry.';
    } finally {
      if (current()) {
        loadingProfile = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(int index) async {
    if (_disposed ||
        loading ||
        result == null ||
        index < 0 ||
        index >= result!.length) {
      return;
    }
    final paths = result;
    selected = index;
    selectedProfile = null;
    ++_selection;
    final selection = _selection;
    error = null;
    notifyListeners();
    try {
      await _map();
      if (!_disposed && identical(paths, result) && selection == _selection) {
        await _loadProfile();
      }
    } catch (_) {
      if (!_disposed && identical(paths, result) && selection == _selection) {
        loadingProfile = false;
        error = 'Signal overlay unavailable. Recalculate to retry.';
        notifyListeners();
      }
    }
  }

  Future<void> _map() async {
    final paths = result, route = _route, settings = _signal;
    if (paths == null || route == null || settings == null) return;
    final start = selected ~/ radioMapPageSize * radioMapPageSize;
    final end = (start + radioMapPageSize).clamp(0, paths.length);
    await editor.globe.setSignalAnalysis({
      'pilot': {
        'latitude': settings.pilot.latitude,
        'longitude': settings.pilot.longitude,
        'height': _pilotGround! + settings.antennaHeight,
      },
      'frequencyMhz': settings.frequencyMhz,
      'fraction': settings.clearanceFraction,
      'selected': selected - start,
      'targetOffset': start,
      'rays': [
        for (var i = start; i < end; i++)
          {
            'latitude': paths[i].target.latitude,
            'longitude': paths[i].target.longitude,
            'height': paths[i].altitude,
            'ground': route[i].ground,
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
