import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import '../../core/models/flight_route.dart';
import '../globe/globe_controller.dart';
import '../globe/route_map_state.dart';

/// The current map session's selected saved routes, independent of ego mode.
class RouteLayersController extends ChangeNotifier {
  RouteLayersController({required this.repository, required this.globe});
  final FlightPlanRepository repository;
  final GlobeController globe;
  final _subscriptions = <int, StreamSubscription<FlightRoute?>>{};
  final _routes = <int, FlightRoute>{};
  final _loadErrors = <int>{};
  bool _disposed = false;
  bool retrying = false;
  String? _syncError;
  int _syncRevision = 0;
  Future<void> _writes = Future.value();
  Future<void> _closing = Future.value();
  Future<void> get settled => Future.wait([_writes, _closing]);
  Set<int> get selectedIds => Set.unmodifiable(_subscriptions.keys);
  bool hasGeometry(int id) => _routes[id]?.waypoints.isNotEmpty == true;
  String? get error => _loadErrors.isNotEmpty
      ? 'Unable to load a selected route. Retry route preview.'
      : _syncError;

  void select(int id, bool selected) {
    if (_disposed ||
        retrying ||
        id <= 0 ||
        _subscriptions.containsKey(id) == selected) {
      return;
    }
    if (selected && _subscriptions.length >= 20) {
      _syncError = 'Up to 20 routes can be displayed together.';
      notifyListeners();
      return;
    }
    _syncError = null;
    if (selected) {
      _watch(id);
    } else {
      final removed = _subscriptions.remove(id);
      _closing = Future.wait([_closing, if (removed != null) removed.cancel()]);
      _routes.remove(id);
      _loadErrors.remove(id);
      _sync();
    }
    notifyListeners();
  }

  void _watch(int id) {
    _subscriptions[id] = repository
        .watchRoute(id)
        .listen(
          (route) {
            if (_disposed || !_subscriptions.containsKey(id)) return;
            _loadErrors.remove(id);
            if (route == null) {
              select(id, false);
              return;
            }
            _routes[id] = route;
            _sync();
            notifyListeners();
          },
          onError: (Object _) {
            if (!_disposed && _subscriptions.containsKey(id)) {
              _loadErrors.add(id);
              notifyListeners();
            }
          },
        );
  }

  void _sync() {
    final routes = [
      for (final route in _routes.values)
        VisibleMapRoute(
          id: route.plan.id,
          name: route.plan.name,
          points: [
            for (final p in route.waypoints) RouteMapPoint(p.id, p.position),
          ],
        ),
    ];
    final revision = ++_syncRevision;
    Future<void> push() async {
      if (_disposed) return;
      try {
        await globe.setVisibleRoutes(routes);
        if (!_disposed && revision == _syncRevision) _syncError = null;
      } catch (_) {
        if (!_disposed && revision == _syncRevision) {
          _syncError =
              'Unable to display selected routes. Retry route preview.';
        }
      }
      if (!_disposed && revision == _syncRevision) notifyListeners();
    }

    _writes = Future.wait([_writes, push()]);
  }

  Future<void> retry() async {
    if (_disposed || retrying) return;
    retrying = true;
    notifyListeners();
    final ids = selectedIds;
    final old = _subscriptions.values.toList();
    _subscriptions.clear();
    await Future.wait(old.map((subscription) => subscription.cancel()));
    if (_disposed) return;
    _loadErrors.clear();
    _syncError = null;
    for (final id in ids) {
      _watch(id);
    }
    retrying = false;
    _sync();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closing = Future.wait([
      _closing,
      ..._subscriptions.values.map((subscription) => subscription.cancel()),
    ]);
    _subscriptions.clear();
    _routes.clear();
    super.dispose();
  }
}
