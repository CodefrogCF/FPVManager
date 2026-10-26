import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/user_preferences.dart';
import '../../core/osint/osint_cache_database.dart';
import 'obstacle_models.dart';
import 'swiss_obstacle_heights.dart';
import 'swiss_obstacle_provider.dart';

class ObstacleMapController extends ChangeNotifier {
  ObstacleMapController({
    required this.send,
    required this.preferences,
    required this.savePreferences,
    required this.canEdit,
    required this.onSelected,
    SwissObstacleProvider? provider,
    OsintCacheDatabase Function()? cacheFactory,
  }) : provider = provider ?? SwissObstacleProvider(cacheFactory: cacheFactory),
       _ownsProvider = provider == null {
    this.provider.addListener(_providerChanged);
  }
  final Future<void> Function(Map<String, dynamic>) send;
  final UserPreferences Function() preferences;
  final Future<void> Function(UserPreferences) savePreferences;
  final bool Function() canEdit;
  final VoidCallback onSelected;
  final SwissObstacleProvider provider;
  final bool _ownsProvider;
  bool _disposed = false, _ready = false;
  String wmsState = 'off';
  String? wmsError, vectorError;
  String vectorStatus = 'Enable vector obstacles to inspect a local area';
  ObstacleFeature? selected;
  String? _snapshotKey;
  ObstacleViewport? _viewport;
  Timer? _debounce;
  int _revision = 0, _query = 0;
  Map<String, ObstacleFeature> _rendered = {};
  Map<String, ObstacleFeature> _hazardsRendered = {};
  int _hazardRevision = 0;
  Future<SwissObstacleHeights>? _heights;
  ObstacleViewport? _coverage;
  String? _coverageKey, _sentVectors, _sentHazards;
  List<ObstacleFeature> _cachedFeatures = [], _cachedSupports = [];

  static bool _contains(ObstacleViewport outer, ObstacleViewport inner) =>
      outer.west <= inner.west &&
      outer.south <= inner.south &&
      outer.east >= inner.east &&
      outer.north >= inner.north;

  static ObstacleViewport _expand(ObstacleViewport area, double x, double y) =>
      ObstacleViewport(
        (area.west - x).clamp(-180, 180).toDouble(),
        (area.south - y).clamp(-90, 90).toDouble(),
        (area.east + x).clamp(-180, 180).toDouble(),
        (area.north + y).clamp(-90, 90).toDouble(),
      );
  bool get wmsVisible => preferences().obstacleWmsVisible;
  double get wmsOpacity => preferences().obstacleWmsOpacity;
  bool get vectorsVisible => preferences().obstacleVectorsVisible;
  bool get modelsVisible => preferences().obstacleModelsVisible;
  bool get hazardsVisible => preferences().hazardAreasVisible;
  double get bufferMeters => preferences().obstacleBufferMeters;
  bool get _needsData => vectorsVisible || hazardsVisible;
  Set<ObstacleCategory> get categories => preferences().obstacleCategories;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _editable() {
    if (!canEdit()) throw StateError('Map preferences unavailable');
  }

  Future<void> setWmsVisible(bool visible) async {
    _editable();
    await savePreferences(preferences().copyWith(obstacleWmsVisible: visible));
    await restoreWms();
  }

  Future<void> setWmsOpacity(double opacity) async {
    _editable();
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError('Invalid obstacle opacity');
    }
    await savePreferences(preferences().copyWith(obstacleWmsOpacity: opacity));
    await restoreWms();
  }

  Future<void> restoreWms({bool retry = false}) async {
    if (!_ready || _disposed) return;
    try {
      await send({
        'type': 'set-obstacle-wms',
        'visible': wmsVisible,
        'opacity': wmsOpacity,
        'retry': retry,
      });
    } catch (e) {
      if (!_disposed) {
        wmsState = 'failed';
        wmsError = 'Obstacle imagery unavailable: $e';
      }
    }
    _notify();
  }

  Future<void> setVectorsVisible(bool visible) async {
    _editable();
    await savePreferences(
      preferences().copyWith(obstacleVectorsVisible: visible),
    );
    clearSelection();
    _query++;
    if (!visible) await _clearVectors();
    if (_needsData) {
      await _loadVectors();
    }
    _notify();
  }

  Future<void> setModelsVisible(bool visible) async {
    _editable();
    await savePreferences(
      preferences().copyWith(obstacleModelsVisible: visible),
    );
    if (vectorsVisible) await updateViewport();
    _notify();
  }

  Future<void> setHazardsVisible(bool visible) async {
    _editable();
    await savePreferences(preferences().copyWith(hazardAreasVisible: visible));
    _query++;
    clearSelection();
    if (visible) {
      await _loadVectors();
    } else {
      await _clearHazards();
      if (vectorsVisible) await updateViewport();
    }
    _notify();
  }

  Future<void> setBufferMeters(double meters) async {
    _editable();
    UserPreferences.validateObstacleBuffer(meters);
    await savePreferences(preferences().copyWith(obstacleBufferMeters: meters));
    await updateViewport();
    _notify();
  }

  Future<void> setCategory(ObstacleCategory category, bool visible) async {
    _editable();
    final next = {...categories};
    visible ? next.add(category) : next.remove(category);
    await savePreferences(preferences().copyWith(obstacleCategories: next));
    if (selected != null && !next.contains(selected!.category)) {
      clearSelection();
    }
    await updateViewport();
  }

  Future<void> refreshVectors() async {
    try {
      await provider.fetch(forceRefresh: true);
      if (!_disposed) {
        vectorError = null;
        await updateViewport();
      }
    } catch (e) {
      vectorError = '$e';
    }
    _notify();
  }

  Future<void> _loadVectors() async {
    try {
      await provider.loadCached();
      if (_disposed || !_needsData) return;
      if (provider.status.dataset == null) await provider.fetch();
      if (!_disposed) {
        vectorError = null;
        await updateViewport();
      }
    } catch (e) {
      vectorError = '$e';
      _notify();
    }
  }

  void _providerChanged() {
    if (_disposed) return;
    final key = provider.status.dataset?.data.key;
    if (key != _snapshotKey) {
      _snapshotKey = key;
      clearSelection();
      if (_ready && _needsData) unawaited(updateViewport());
    }
    _notify();
  }

  void rendererLost() {
    _ready = false;
    _query++;
    _debounce?.cancel();
    _viewport = null;
    _rendered = {};
    _hazardsRendered = {};
    _sentVectors = _sentHazards = null;
    selected = null;
    wmsState = 'off';
    wmsError = null;
  }

  Future<void> rendererReady({bool force = false}) async {
    _ready = true;
    if (wmsVisible || force) await restoreWms();
    if (_needsData) {
      await _loadVectors();
    } else if (force) {
      await _clearVectors();
      await _clearHazards();
    }
  }

  bool handleEvent(Map<String, dynamic> event) {
    if (event['type'] == 'obstacle-wms-status') {
      final state = event['state'];
      if (const {'off', 'loading', 'ready', 'failed'}.contains(state)) {
        wmsState = state as String;
        wmsError = state == 'failed'
            ? 'Obstacle tiles unavailable or timed out. Retry the layer.'
            : null;
        _notify();
      }
      return true;
    }
    if (event['type'] == 'obstacle-viewport') {
      final values = [
        event['west'],
        event['south'],
        event['east'],
        event['north'],
      ];
      if (values.every((v) => v is num && v.isFinite) &&
          (values[0] as num).abs() <= 180 &&
          (values[2] as num).abs() <= 180 &&
          (values[1] as num).abs() <= 90 &&
          (values[3] as num).abs() <= 90 &&
          (values[1] as num) <= (values[3] as num)) {
        _viewport = ObstacleViewport(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        );
        _query++;
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 250),
          () => unawaited(updateViewport()),
        );
      }
      return true;
    }
    if (event['type'] == 'obstacle-selected') {
      final hazard = event['layer'] == 'hazard';
      final feature = (hazard ? _hazardsRendered : _rendered)[event['id']];
      if ((hazard ? hazardsVisible : vectorsVisible) &&
          event['revision'] == (hazard ? _hazardRevision : _revision) &&
          feature != null) {
        selected = feature;
        onSelected();
        _notify();
      }
      return true;
    }
    if (event['type'] == 'obstacle-cleared') {
      clearSelection();
      return true;
    }
    return false;
  }

  void clearSelection() {
    if (selected != null) {
      selected = null;
      _notify();
    }
  }

  Future<void> _clearVectors() async {
    if (!_ready || _disposed) return;
    _rendered = {};
    _sentVectors = null;
    try {
      await send({
        'type': 'set-obstacle-vectors',
        'revision': ++_revision,
        'features': <Object>[],
      });
    } catch (e) {
      vectorError = 'Unable to update obstacle display: $e';
    }
  }

  Future<void> _clearHazards() async {
    if (!_ready || _disposed) return;
    _hazardsRendered = {};
    _sentHazards = null;
    try {
      await send({
        'type': 'set-hazard-areas',
        'revision': ++_hazardRevision,
        'bufferMeters': bufferMeters,
        'features': <Object>[],
      });
    } catch (e) {
      vectorError = 'Unable to update advisory areas: $e';
    }
  }

  Future<void> updateViewport() async {
    if (_disposed || !_ready || !_needsData) return;
    final operation = ++_query;
    bool current() => !_disposed && _ready && _needsData && operation == _query;
    final snapshot = provider.status.dataset?.data;
    final viewport = _viewport;
    if (snapshot == null || viewport == null || !viewport.isLocal) {
      vectorStatus = snapshot == null ? 'No local vector dataset available' : 'Zoom in to inspect vector obstacles (local view up to about 60 km)';
      await _clearVectors();
      await _clearHazards();
      _notify();
      return;
    }
    try {
      final requested = hazardsVisible
          ? _expand(viewport, bufferMeters / 60000, bufferMeters / 100000)
          : viewport;
      final categoryNames = categories.map((c) => c.name).toList()..sort();
      final cacheKey = jsonEncode([
        snapshot.key,
        categoryNames,
        vectorsVisible,
      ]);
      var features = _cachedFeatures, supports = _cachedSupports;
      if (_coverage == null ||
          _coverageKey != cacheKey ||
          !_contains(_coverage!, requested)) {
        var area = _expand(
          requested,
          ((viewport.east - viewport.west) * .25).clamp(.01, .05),
          ((viewport.north - viewport.south) * .25).clamp(.01, .05),
        );
        features = await provider.cache.queryObstacles(
          snapshot.key,
          area,
          categories,
          localViewOnly: false,
        );
        if (!current()) return;
        // Dense views retain the original display budget instead of allowing
        // offscreen neighbours to displace relevant visible obstacles.
        if (features.length > 1200) {
          area = requested;
          features = await provider.cache.queryObstacles(
            snapshot.key,
            area,
            categories,
            localViewOnly: false,
          );
        }
        // Hidden support masts still anchor cable display, so category visibility
        // does not change an otherwise known attachment height.
        var supportArea = area;
        for (final feature in features) {
          if (!feature.parts.any((p) => p.kind == 'LineString')) continue;
          supportArea = ObstacleViewport(
            feature.west < supportArea.west ? feature.west : supportArea.west,
            feature.south < supportArea.south
                ? feature.south
                : supportArea.south,
            feature.east > supportArea.east ? feature.east : supportArea.east,
            feature.north > supportArea.north
                ? feature.north
                : supportArea.north,
          );
        }
        supports =
            vectorsVisible &&
                (categories.contains(ObstacleCategory.powerLines) ||
                    categories.contains(ObstacleCategory.cableways))
            ? await provider.cache.queryObstacles(
                snapshot.key,
                supportArea,
                {
                  ObstacleCategory.masts,
                  ObstacleCategory.powerLines,
                  ObstacleCategory.cableways,
                },
                pointsOnly: true,
                localViewOnly: false,
              )
            : <ObstacleFeature>[];
        if (!current()) return;
        _coverage = area;
        _coverageKey = cacheKey;
        _cachedFeatures = features;
        _cachedSupports = supports;
      }
      final heights = await (_heights ??= SwissObstacleHeights.load());
      if (!current()) return;
      var vertices = 0, parts = 0, projected = 0;
      final payload = <Map<String, dynamic>>[];
      final rendered = <String, ObstacleFeature>{};
      for (final f in {
        for (final f in [...features, ...supports]) f.id: f,
      }.values) {
        final size = f.parts.fold<int>(0, (n, p) => n + p.coordinates.length);
        if (payload.length >= 1200 ||
            vertices + size > 40000 ||
            parts + f.parts.length > 4000) {
          continue;
        }
        vertices += size;
        parts += f.parts.length;
        final converted = <Map<String, dynamic>>[];
        for (final p in f.parts) {
          final positions = p.coordinates
              .map(
                (a) => <double?>[
                  a[0],
                  a[1],
                  p.mode == 'absolute' && a.length == 3
                      ? heights.ellipsoidHeight(a[0], a[1], a[2])
                      : null,
                ],
              )
              .toList();
          final elevated = positions.every((p) => p[2] != null);
          // For an isolated Point, the published maxHeightAGL describes
          // the actual object height at the same position. For a line or
          // polygon it may apply anywhere on the feature, not each vertex.
          final agl = double.tryParse(f.attributes['maxHeightAGL'] ?? '');
          final heightAgl =
              p.kind == 'Point' &&
                  f.parts.length == 1 &&
                  agl != null &&
                  agl.isFinite &&
                  agl > 0 &&
                  agl < 1500
              ? agl
              : null;
          if (!elevated && heightAgl == null) projected++;
          converted.add({
            'kind': p.kind,
            'elevated': elevated,
            'coordinates': positions,
            'heightAgl': ?heightAgl,
          });
        }
        payload.add({
          'id': f.id,
          'category': f.category.name,
          'sourceType': f.sourceType,
          if (!categories.contains(f.category)) 'supportOnly': true,
          'parts': converted,
        });
        if (categories.contains(f.category)) rendered[f.id] = f;
      }
      if (!current()) return;
      final signature = jsonEncode([snapshot.key, modelsVisible, payload]);
      if (vectorsVisible && _sentVectors != signature) {
        final revision = ++_revision;
        await send({
          'type': 'set-obstacle-vectors',
          'useModels': modelsVisible,
          'revision': revision,
          'features': payload,
        });
        if (!_disposed && _ready && revision == _revision) {
          _rendered = rendered;
          _sentVectors = signature;
        }
      }
      if (!current()) return;
      final hazardSignature = jsonEncode([snapshot.key, bufferMeters, payload]);
      if (hazardsVisible && _sentHazards != hazardSignature) {
        final revision = ++_hazardRevision;
        await send({
          'type': 'set-hazard-areas',
          'revision': revision,
          'bufferMeters': bufferMeters,
          'features': payload,
        });
        if (!_disposed && _ready && revision == _hazardRevision) {
          _hazardsRendered = rendered;
          _sentHazards = hazardSignature;
        }
        if (!current()) return;
      }
      final limited = features.length > rendered.length;
      vectorStatus =
          '${rendered.length} nearby obstacles${limited ? ' · display limit reached; zoom in' : ''}'
          '${projected > 0 ? ' · $projected ground markers (height unavailable/unsupported)' : ''}';
      vectorError = null;
      _notify();
    } catch (e) {
      if (current()) {
        vectorError = 'Obstacle preview unavailable: $e';
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _query++;
    _debounce?.cancel();
    provider.removeListener(_providerChanged);
    if (_ownsProvider) provider.dispose();
    super.dispose();
  }
}
