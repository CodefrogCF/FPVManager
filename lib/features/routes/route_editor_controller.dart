import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import '../../core/models/flight_route.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../globe/globe_controller.dart';
import '../globe/route_map_state.dart';

class EditableWaypoint {
  const EditableWaypoint(this.key, this.position, this.height);
  final int key;
  final Wgs84Coordinate position;
  final WaypointHeight? height;
  RouteWaypointInput get input =>
      RouteWaypointInput(position: position, height: height);
}

class RouteEditorController extends ChangeNotifier {
  RouteEditorController({
    required this.repository,
    required this.globe,
    this.routeId,
  }) {
    _subscription = globe.routeActions.listen(_mapAction);
  }
  final FlightPlanRepository repository;
  final GlobeController globe;
  int? routeId;
  final String editorId = 'route-${DateTime.now().microsecondsSinceEpoch}';
  late final StreamSubscription<RouteMapAction> _subscription;
  FlightRoute? _original;
  List<EditableWaypoint> _points = const [];
  List<EditableWaypoint> get points => _points;
  final List<List<EditableWaypoint>> _undo = [];
  String name = 'New route';
  int? selectedId, moveId;
  int _nextKey = 0;
  bool loading = true, saving = false, dirty = false, _disposed = false;
  bool _loadedSuccessfully = false;
  bool get loadFailed => !loading && !_loadedSuccessfully;
  String? error, mapError;
  EditableWaypoint? get selected =>
      _points.where((p) => p.key == selectedId).firstOrNull;
  bool get canUndo => _undo.isNotEmpty && !saving;
  bool get canSave =>
      !loading &&
      !saving &&
      name.trim().isNotEmpty &&
      name.trim().length <= 120 &&
      _loadedSuccessfully;

  Future<void> load() async {
    loading = true;
    _loadedSuccessfully = false;
    error = null;
    notifyListeners();
    try {
      final route = routeId == null
          ? null
          : await repository.getRoute(routeId!);
      if (_disposed) return;
      if (routeId != null && route == null) {
        throw StateError('Route no longer exists');
      }
      _original = route;
      name = route?.plan.name ?? 'New route';
      _points = List.unmodifiable([
        for (final point in route?.waypoints ?? <RouteWaypoint>[])
          EditableWaypoint(++_nextKey, point.position, point.height),
      ]);
      selectedId = null;
      moveId = null;
      dirty = false;
      _undo.clear();
      _loadedSuccessfully = true;
    } catch (_) {
      if (!_disposed) error = 'Unable to load this route. Please retry.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
        await syncMap();
      }
    }
  }

  void rename(String value) {
    if (saving || loading || !_loadedSuccessfully || name == value) return;
    name = value;
    dirty = true;
    error = null;
    notifyListeners();
  }

  void _mapAction(RouteMapAction action) {
    if (loading || saving || _disposed || !_loadedSuccessfully) {
      return;
    }
    switch (action.kind) {
      case RouteMapActionKind.select:
        select(action.id!);
      case RouteMapActionKind.add:
        if (_points.length >= 1000) {
          error = 'A route supports at most 1000 waypoints.';
          notifyListeners();
          return;
        }
        _change([
          ..._points,
          EditableWaypoint(++_nextKey, action.position!, null),
        ], selected: _nextKey);
      case RouteMapActionKind.move:
        _change([
          for (final point in _points)
            point.key == action.id
                ? EditableWaypoint(point.key, action.position!, point.height)
                : point,
        ], selected: action.id);
      case RouteMapActionKind.delete:
        deletePoint(action.id!);
    }
  }

  void select(int id) {
    if (saving || !_points.any((p) => p.key == id)) return;
    selectedId = id;
    moveId = null;
    notifyListeners();
    unawaited(syncMap());
  }

  void toggleMove() {
    if (selected == null || saving) return;
    moveId = moveId == null ? selectedId : null;
    notifyListeners();
    unawaited(syncMap());
  }

  void deletePoint(int id) {
    if (saving || !_points.any((p) => p.key == id)) return;
    _change(_points.where((p) => p.key != id).toList());
  }

  void _change(List<EditableWaypoint> next, {int? selected}) {
    _undo.add(_points);
    if (_undo.length > 50) _undo.removeAt(0);
    _points = List.unmodifiable(next);
    selectedId = selected;
    moveId = null;
    dirty = true;
    error = null;
    notifyListeners();
    unawaited(syncMap());
  }

  void undo() {
    if (!canUndo) return;
    _points = _undo.removeLast();
    selectedId = null;
    moveId = null;
    dirty = true;
    error = null;
    notifyListeners();
    unawaited(syncMap());
  }

  Future<void> syncMap() async {
    if (_disposed || loading) return;
    try {
      await globe.setRouteEditor(
        editorId: editorId,
        points: [
          for (final point in _points) RouteMapPoint(point.key, point.position),
        ],
        selectedId: selectedId,
        moveId: moveId,
        interactive: !saving && _loadedSuccessfully,
      );
      if (!_disposed && mapError != null) {
        mapError = null;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        mapError = 'Unable to update route markers. Retry map sync.';
        notifyListeners();
      }
    }
  }

  Future<bool> save() async {
    if (!canSave) return false;
    saving = true;
    error = null;
    notifyListeners();
    await syncMap();
    try {
      final id = await repository.saveRoute(
        id: routeId,
        name: name,
        droneId: _original?.plan.droneId,
        startSpotId: _original?.plan.startSpotId,
        notes: _original?.plan.notes,
        waypoints: [for (final point in _points) point.input],
      );
      if (_disposed) return true;
      routeId = id;
      dirty = false;
      _undo.clear();
      // Retain original drone/spot/notes metadata without another fallible read
      // after the committed save. Newly created routes have no such metadata.
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'Unable to save. Your draft is retained; please retry.';
      }
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
        await syncMap();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
