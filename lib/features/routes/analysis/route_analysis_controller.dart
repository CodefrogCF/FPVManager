import 'package:flutter/foundation.dart';

import '../../../core/models/route_planning_settings.dart';
import '../route_editor_controller.dart';
import 'route_analysis.dart';
import 'route_energy.dart';
import 'route_safety_controller.dart';

class RouteAnalysisController extends ChangeNotifier {
  RouteAnalysisController(this.editor) {
    _remember();
    editor.addListener(_changed);
    editor.globe.addListener(_changed);
    safety.addListener(_safetyChanged);
  }
  final RouteEditorController editor;
  late final safety = RouteSafetyController(editor);
  void _safetyChanged() {
    if (_disposed) return;
    _highlight();
    notifyListeners();
  }

  late List<EditableWaypoint> _points;
  late RoutePlanningSettings _settings;
  late (int, int) _terrainRevision;
  int? _droneId, selectedBatteryId;
  Set<int> _batteryIds = {};
  int _operation = 0;
  bool _disposed = false, loading = false;
  int completedSamples = 0, totalSamples = 0;
  RouteAnalysis? result;
  RouteEnergyEstimate? energy;
  List<BatteryRouteAssessment> batteries = const [];
  String? error, terrainError;
  final Set<String> samplingMethods = {};

  void _remember() {
    _points = editor.points;
    _settings = editor.planning;
    _terrainRevision = editor.globe.terrainRevision;
    _droneId = editor.droneId;
    _batteryIds = Set.of(editor.batteryIds);
  }

  void _changed() {
    if (_disposed ||
        (identical(_points, editor.points) &&
            identical(_settings, editor.planning) &&
            _terrainRevision == editor.globe.terrainRevision &&
            _droneId == editor.droneId &&
            setEquals(_batteryIds, editor.batteryIds))) {
      return;
    }
    _remember();
    cancel();
  }

  void cancel() {
    ++_operation;
    loading = false;
    result = null;
    energy = null;
    batteries = const [];
    safety.cancel();
    editor.highlightSegments({});
    if (!_disposed) notifyListeners();
  }

  void selectBattery(int? id) {
    selectedBatteryId = id;
    _highlight();
    notifyListeners();
  }

  void _highlight() {
    final r = result;
    if (r == null) {
      editor.highlightSegments({});
      return;
    }
    final critical = <int>{
      ...safety.highlighted,
      for (final s in r.segments)
        if (s.minimumClearance != null &&
            s.minimumClearance! < editor.planning.minimumClearance)
          s.index,
      ...batteries
          .where((b) => b.battery.id == selectedBatteryId)
          .expand((b) => b.criticalSegments),
    };
    editor.highlightSegments(critical);
  }

  Future<void> calculate() async {
    if (loading || _disposed) return;
    final token = ++_operation;
    safety.cancel();
    final points = [for (final p in editor.points) p.input];
    final settings = editor.planning;
    loading = true;
    result = null;
    energy = null;
    batteries = const [];
    error = null;
    terrainError = null;
    completedSamples = 0;
    samplingMethods.clear();
    totalSamples = 0;
    editor.highlightSegments({});
    notifyListeners();
    bool current() => !_disposed && token == _operation;
    try {
      final plan = RouteSamplingPlan.create(points);
      totalSamples = plan.samples.length;
      await editor.loadEquipment();
      if (!current()) return;
      List<double>? heights;
      try {
        if (!editor.globe.terrainAvailable || !editor.globe.isReady) {
          throw StateError('Terrain unavailable');
        }
        heights = <double>[];
        for (var offset = 0; offset < plan.samples.length; offset += 256) {
          if (!current()) return;
          final end = (offset + 256).clamp(0, plan.samples.length);
          final sampled = await editor.globe.queryRouteTerrain([
            for (final s in plan.samples.sublist(offset, end)) s.position,
          ]);
          if (!current()) return;
          heights.addAll(sampled.heights);
          samplingMethods.add(sampled.samplingMethod);
          completedSamples = heights.length;
          notifyListeners();
        }
      } catch (_) {
        if (!current()) return;
        heights = null;
        terrainError = 'Terrain profile unavailable. No terrain clearance can be assessed. Retry when detailed terrain is available.';
      }
      if (!current()) return;
      final calculated = RouteAnalysis.calculate(
        points,
        plan,
        heights,
        settings,
      );
      final drone = editor.equipmentError != null
          ? null
          : editor.equipment?.drones
                .where((d) => d.drone.id == editor.droneId)
                .firstOrNull;
      final modeled = RouteEnergyEstimate.calculate(
        calculated,
        settings,
        droneMassGrams: drone?.drone.takeoffWeightGrams,
      );
      result = calculated;
      energy = modeled;
      batteries = editor.equipmentError != null
          ? const []
          : [
              for (final b in editor.equipment?.batteries ?? [])
                if (editor.batteryIds.contains(b.id))
                  BatteryRouteAssessment.calculate(
                    b,
                    calculated,
                    modeled,
                    settings,
                  ),
            ];
      if (!batteries.any((b) => b.battery.id == selectedBatteryId)) {
        selectedBatteryId = batteries.firstOrNull?.battery.id;
      }
      _highlight();
    } catch (e) {
      if (current()) {
        error = e is ArgumentError
            ? e.message?.toString()
            : 'Unable to calculate the route. Check inputs and retry.';
      }
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    editor.removeListener(_changed);
    editor.globe.removeListener(_changed);
    safety.removeListener(_safetyChanged);
    safety.dispose();
    super.dispose();
  }
}
