import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/osint/osint_provider_state.dart';

import '../../airspace/uas_airspace_checker.dart';
import '../../obstacles/obstacle_models.dart';
import '../../obstacles/obstacle_proximity.dart';
import '../../obstacles/swiss_obstacle_heights.dart';
import '../route_editor_controller.dart';
import '../../globe/infrastructure_clearance.dart';
import 'route_analysis.dart';
import 'route_rule_check.dart';

class RouteSafetyController extends ChangeNotifier {
  RouteSafetyController(this.editor) {
    _remember();
    editor.addListener(_changed);
    editor.globe.addListener(_changed);
  }
  final RouteEditorController editor;
  Object? _points, _settings, _uas, _obstacles;
  Object? _uasState, _obstacleState;
  int _infrastructureRevision = 0;
  bool infrastructureEnabled = false, infrastructureLayerVisible = true;
  double droneRadiusMeters = 0.25;
  InfrastructureClearanceReport? infrastructure;
  String? infrastructureError;
  Set<Object> _categories = {};
  double _buffer = 0;
  int _operation = 0;
  bool _disposed = false, loading = false;
  RouteRuleCheck? rules;
  UasAirspaceCheck? airspace;
  ObstacleProximityReport? proximity;
  ObstacleSnapshot? snapshot;
  String? airspaceError, obstacleError, obstacleStatus;
  bool get hasResult => rules != null;
  Set<int> get highlighted => {
    ...?rules?.findings.map((f) => f.segment),
    ...?airspace?.intersections.expand((hit) => hit.geometry.segmentIndices),
    ...?proximity?.hits.map((h) => h.segment),
    ...?infrastructure?.findings
        .where((f) => f.modelContact)
        .map((f) => f.segment),
  };
  void _remember() {
    _points = editor.points;
    _settings = editor.planning;
    _uas = editor.globe.uasProvider.status.dataset;
    _obstacles = editor.globe.obstacles.provider.status.dataset;
    final u = editor.globe.uasProvider.status,
        o = editor.globe.obstacles.provider.status;
    _uasState = (u.update, u.error, u.dataState);
    _obstacleState = (o.update, o.error, o.dataState);
    _categories = Set.of(editor.globe.obstacles.categories);
    _buffer = editor.globe.obstacles.bufferMeters;
    _infrastructureRevision = editor.globe.infrastructureRevision;
  }

  void _changed() {
    if (_disposed) return;
    final inputChanged =
        !identical(_points, editor.points) ||
        !identical(_settings, editor.planning) ||
        _buffer != editor.globe.obstacles.bufferMeters ||
        _infrastructureRevision != editor.globe.infrastructureRevision ||
        !setEquals(_categories, editor.globe.obstacles.categories);
    final sourceChanged =
        !identical(_uas, editor.globe.uasProvider.status.dataset) ||
        !identical(_obstacles, editor.globe.obstacles.provider.status.dataset);
    final u = editor.globe.uasProvider.status,
        o = editor.globe.obstacles.provider.status;
    final statusChanged =
        _uasState != (u.update, u.error, u.dataState) ||
        _obstacleState != (o.update, o.error, o.dataState);
    _remember();
    if (inputChanged || ((sourceChanged || statusChanged) && !loading)) {
      cancel();
    }
  }

  void setInfrastructureEnabled(bool enabled) {
    if (infrastructureEnabled == enabled) return;
    infrastructureEnabled = enabled;
    cancel();
    if (!enabled) {
      // No persisted inspection result can be mistaken for current clearance.
      unawaited(
        editor.globe
            .showInfrastructureClearance(false)
            .catchError((Object _) {}),
      );
    }
  }

  void setInfrastructureLayerVisible(bool visible) {
    if (infrastructureLayerVisible == visible) return;
    infrastructureLayerVisible = visible;
    unawaited(
      editor.globe
          .showInfrastructureClearance(visible && infrastructureEnabled)
          .catchError((Object _) {}),
    );
    if (!_disposed) notifyListeners();
  }

  void setDroneRadiusMeters(double radius) {
    if (!radius.isFinite || radius < 0.05 || radius > 2) {
      throw ArgumentError('Drone bounding radius must be 0.05–2 m');
    }
    if (droneRadiusMeters == radius) return;
    droneRadiusMeters = radius;
    cancel();
  }

  void cancel() {
    ++_operation;
    loading = false;
    rules = null;
    airspace = null;
    proximity = null;
    snapshot = null;
    infrastructure = null;
    infrastructureError = null;
    airspaceError = null;
    obstacleError = null;
    obstacleStatus = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> calculate(RouteAnalysis analysis) async {
    if (_disposed || loading) return;
    cancel();
    final token = ++_operation,
        points = [for (final p in editor.points) p.input];
    final categories = Set.of(editor.globe.obstacles.categories),
        buffer = editor.globe.obstacles.bufferMeters;
    bool current() => !_disposed && token == _operation;
    loading = true;
    notifyListeners();
    final calculated = RouteRuleCheck.calculate(
      analysis,
      points,
      editor.planning.constraints,
    );
    UasAirspaceCheck? uas;
    ObstacleProximityReport? obstacles;
    ObstacleSnapshot? checked;
    try {
      uas = await editor.globe.checkAirspace(
        points.map((p) => p.position).toList(),
      );
      if (!current()) return;
      if (uas.fetchedAtUtc !=
          editor.globe.uasProvider.status.dataset?.fetchedAtUtc) {
        uas = null;
        airspaceError = 'Airspace data changed during this check. Recalculate.';
      }
    } catch (_) {
      if (!current()) return;
      airspaceError = 'UAS intersections unavailable. Check official airspace information and retry.';
    }
    if (!current()) return;
    try {
      final provider = editor.globe.obstacles.provider;
      await provider.loadCached();
      if (!current()) return;
      checked = provider.status.dataset?.data;
      if (checked == null) {
        obstacleError = 'No local vector obstacle dataset. Download it in Map layers → Obstacles.';
      } else {
        final lat = points.map((p) => p.position.latitude),
            lon = points.map((p) => p.position.longitude);
        // Conservative padding in Switzerland, including features outside the path bbox.
        final features = await provider.cache.queryObstacles(
          checked.key,
          ObstacleViewport(
            lon.reduce(math.min) - buffer / 60000,
            lat.reduce(math.min) - buffer / 100000,
            lon.reduce(math.max) + buffer / 60000,
            lat.reduce(math.max) + buffer / 100000,
          ),
          categories,
          localViewOnly: false,
        );
        if (!current()) return;
        final heights = await SwissObstacleHeights.load();
        if (!current()) return;
        final report = await checkObstacleProximity(
          route: analysis,
          obstacles: features.take(1200).toList(),
          bufferMeters: buffer,
          heights: heights,
          cancelled: () => !current(),
        );
        if (!current()) return;
        if (checked.key != provider.status.dataset?.data.key) {
          obstacleError =
              'Obstacle dataset changed during this check. Recalculate.';
        } else {
          obstacles = ObstacleProximityReport(
            report.hits,
            report.incomplete || features.length > 1200,
            report.comparisons,
          );
          obstacleStatus = provider.status.dataState.label;
        }
      }
    } catch (_) {
      if (!current()) return;
      obstacleError = 'Obstacle proximity unavailable. No obstacle clearance has been assessed.';
    }
    if (!current()) return;
    InfrastructureClearanceReport? infrastructureResult;
    if (infrastructureEnabled) {
      try {
        final profile = analysis.profile;
        // The bridge protocol has a bounded request frame. Long routes remain
        // explicitly incomplete rather than being treated as obstacle-free.
        final stride = math.max(1, (profile.length / 510).ceil());
        final selected = <InfrastructureRoutePoint>[
          for (var i = 0; i < profile.length; i += stride)
            InfrastructureRoutePoint(
              latitude: profile[i].sample.position.latitude,
              longitude: profile[i].sample.position.longitude,
              heightMetersWgs84: profile[i].altitude,
              segment: profile[i].sample.segment,
            ),
        ];
        if (selected.length < 512 &&
            profile.length > 1 &&
            (selected.last.latitude != profile.last.sample.position.latitude ||
                selected.last.longitude !=
                    profile.last.sample.position.longitude)) {
          selected.add(
            InfrastructureRoutePoint(
              latitude: profile.last.sample.position.latitude,
              longitude: profile.last.sample.position.longitude,
              heightMetersWgs84: profile.last.altitude,
              segment: profile.last.sample.segment,
            ),
          );
        }
        infrastructureResult = await editor.globe.queryInfrastructureClearance(
          selected,
          droneRadiusMeters: droneRadiusMeters,
          truncated: stride > 1,
        );
        if (!current()) return;
        await editor.globe.showInfrastructureClearance(
          infrastructureLayerVisible,
        );
        if (!current()) return;
      } catch (_) {
        if (!current()) return;
        infrastructureError = '3D infrastructure assessment unavailable. No clearance was established.';
      }
    }
    if (!current()) return;
    if (uas != null &&
        !identical(
          uas.datasetIdentity,
          editor.globe.uasProvider.status.dataset,
        )) {
      uas = null;
      airspaceError = 'Airspace data changed during this check. Recalculate.';
    }
    rules = calculated;
    airspace = uas;
    proximity = obstacles;
    infrastructure = infrastructureResult;
    snapshot = checked;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    editor.removeListener(_changed);
    editor.globe.removeListener(_changed);
    super.dispose();
  }
}
