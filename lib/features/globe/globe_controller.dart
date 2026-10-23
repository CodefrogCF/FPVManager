import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/osint/osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import '../../core/osint/osint_cache_database.dart';
import '../../core/osint/osint_dataset_store.dart';
import '../../core/osint/cached_osint_provider.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/user_preferences.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../airspace/data/swiss_uas_provider.dart';
import '../airspace/uas_dataset_assessment.dart';
import '../airspace/uas_zone_details.dart';
import '../airspace/uas_airspace_checker.dart';
import '../../core/osint/geojson_performance.dart';
import '../../core/osint/geojson_osint_provider.dart';
import '../obstacles/obstacle_map_controller.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import 'globe_bridge.dart';
import 'route_map_state.dart';

export 'globe_bridge.dart' show GlobeBridgeOptions, GlobeCommandSender;
export '../airspace/uas_zone_details.dart' show UasZoneDetails;
export '../../core/models/user_preferences.dart'
    show GlobeMapStyle, GlobeOverlay;

class GlobePoint {
  const GlobePoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.heightReference = VerticalReference.unverified,
  });

  final double latitude;
  final double longitude;
  final double altitude;
  final VerticalReference heightReference;
}

class TerrainElevation {
  const TerrainElevation({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.samplingMethod,
  });

  final double latitude;
  final double longitude;

  final ReferencedElevation elevation;

  double get heightMeters => elevation.meters;

  /// Method used by Cesium to sample the terrain.
  final String samplingMethod;
}

class SpotMapMarker {
  const SpotMapMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };
}

enum GlobeTerrainState { loading, ready, unavailable, offline }

class GlobeController extends ChangeNotifier {
  GlobeController({
    OsintProvider<Map<String, dynamic>>? uasProvider,
    SwissObstacleProvider? obstacleProvider,
    GlobeBridgeOptions bridgeOptions = const GlobeBridgeOptions(),
  }) : _ownsUasProvider = uasProvider == null,
       _bridge = GlobeBridge(options: bridgeOptions) {
    _uasProvider =
        uasProvider ??
        SwissUasProvider(
          persistentCache: JsonOsintDatasetStore(
            database: _sharedCache,
            storageTerms: SwissUasProvider.defaultSource.licenseUri!,
          ),
        );
    _uasProvider.addListener(_handleProviderChanged);
    obstacles = ObstacleMapController(
      provider: obstacleProvider,
      cacheFactory: _sharedCache,
      send: (command) async {
        await _bridge.send(command, timeout: _bridge.options.datasetTimeout);
      },
      preferences: () => _preferences,
      savePreferences: _savePreferences,
      canEdit: () => canEditPreferences && _ready,
      onSelected: () {
        _selectedPoint = null;
        _selectedSpotId = null;
        _resetUasSelection();
      },
    )..addListener(_handleProviderChanged);
  }

  late final ObstacleMapController obstacles;

  void _handleProviderChanged() {
    if (!_disposed) notifyListeners();
  }

  late final OsintProvider<Map<String, dynamic>> _uasProvider;
  OsintCacheDatabase? _cache;
  OsintCacheDatabase _sharedCache() => _cache ??= OsintCacheDatabase.open();
  OsintProvider<Map<String, dynamic>> get uasProvider => _uasProvider;
  final bool _ownsUasProvider;
  late final _airspaceChecker = UasAirspaceChecker(_uasProvider);

  Future<UasAirspaceCheck> checkAirspace(
    List<Wgs84Coordinate> positions, {
    bool forceRefresh = false,
  }) async {
    if (_disposed) throw StateError('Globe controller is disposed');
    final result = await _airspaceChecker.check(
      positions,
      forceRefresh: forceRefresh,
    );
    if (_disposed) throw StateError('Globe controller is disposed');
    return result;
  }

  final GlobeBridge _bridge;
  bool _disposed = false;
  int _connectionGeneration = 0;
  int _uasOperation = 0;
  GlobeMapStyle _requestedMapStyle = GlobeMapStyle.satellite;
  double _requestedUasOpacity = 0.20;

  Map<String, dynamic>? _weatherOverlayCommand;

  /// Weather presentation is independent of Swiss airspace restrictions.
  Future<void> showWeatherOverlay(Map<String, dynamic> command) async {
    if (command['type'] != 'set-weather-overlay') {
      throw ArgumentError('Invalid weather overlay');
    }
    _weatherOverlayCommand = command;
    if (_ready) await _send(command);
    if (!_disposed) notifyListeners();
  }

  Future<void> clearWeatherOverlay() async {
    _weatherOverlayCommand = null;
    if (_ready) await _send({'type': 'clear-weather-overlay'});
    if (!_disposed) notifyListeners();
  }

  bool get weatherOverlayVisible => _weatherOverlayCommand != null;

  bool _uasDatasetSentToRenderer = false;
  OsintDataset<Map<String, dynamic>>? _uasDisplayedDataset;
  bool _uasRequestedVisible = false;
  bool _ready = false;
  bool _groundViewActive = false, _groundViewPending = false;
  String? _groundViewMessage;
  Map<String, dynamic>? _routeEditorState;
  Map<String, dynamic>? _visibleRoutesState;
  int _visibleRoutesRevision = 0;
  String? _routePreviewError;
  String? get routePreviewError => _routePreviewError;
  int _routeEditorRevision = 0;
  final _routeActions = StreamController<RouteMapAction>.broadcast(sync: true);
  Stream<RouteMapAction> get routeActions => _routeActions.stream;
  bool get groundViewActive => _groundViewActive;
  bool get groundViewPending => _groundViewPending;
  String? get groundViewMessage => _groundViewMessage;

  Future<void> enterGroundView({
    required double latitude,
    required double longitude,
  }) async {
    if (!_ready || !_terrainAvailable || _groundViewPending) {
      throw StateError('Detailed terrain is required');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() >= 89.9 ||
        longitude.abs() > 180) {
      throw ArgumentError('Invalid ground-view position');
    }
    await _bridge.send({
      'type': 'enter-ground-view',
      'latitude': latitude,
      'longitude': longitude,
    }, timeout: _bridge.options.terrainTimeout);
  }

  Future<void> exitGroundView() => _send({'type': 'exit-ground-view'});

  Future<void> setRouteEditor({
    required String editorId,
    required List<RouteMapPoint> points,
    int? selectedId,
    int? moveId,
    bool interactive = true,
  }) async {
    final ids = points.map((p) => p.id).toSet();
    if (editorId.isEmpty ||
        editorId.length > 120 ||
        points.length > 1000 ||
        ids.length != points.length ||
        points.any(
          (p) =>
              p.id <= 0 ||
              !p.position.latitude.isFinite ||
              !p.position.longitude.isFinite ||
              p.position.latitude.abs() > 90 ||
              p.position.longitude.abs() > 180,
        ) ||
        (selectedId != null && !ids.contains(selectedId)) ||
        (moveId != null && !ids.contains(moveId))) {
      throw ArgumentError('Invalid route map state');
    }
    final state = _routeEditorState = {
      'type': 'set-route-editor',
      'editorId': editorId,
      'revision': ++_routeEditorRevision,
      'enabled': true,
      'interactive': interactive,
      'selectedId': selectedId,
      'moveId': moveId,
      'waypoints': points.map((p) => p.toJson()).toList(),
    };
    if (_ready) {
      await _bridge.send(state, timeout: _bridge.options.terrainTimeout);
    }
  }

  Future<void> frameRoute() async {
    await _bridge.send({
      'type': 'frame-route',
    }, timeout: _bridge.options.terrainTimeout);
  }

  Future<void> setVisibleRoutes(List<VisibleMapRoute> routes) async {
    if (routes.length > 20 ||
        routes.map((r) => r.id).toSet().length != routes.length ||
        routes.any(
          (route) =>
              route.id <= 0 ||
              route.name.length > 120 ||
              route.points.length > 1000 ||
              route.points.map((p) => p.id).toSet().length !=
                  route.points.length ||
              route.points.any(
                (point) =>
                    point.id <= 0 ||
                    !point.position.latitude.isFinite ||
                    !point.position.longitude.isFinite ||
                    point.position.latitude.abs() > 90 ||
                    point.position.longitude.abs() > 180,
              ),
        )) {
      throw ArgumentError('Invalid visible routes');
    }
    final state = _visibleRoutesState = {
      'type': 'set-visible-routes',
      'revision': ++_visibleRoutesRevision,
      'routes': routes.map((route) => route.toJson()).toList(),
    };
    _routePreviewError = null;
    if (_ready) {
      await _bridge.send(state, timeout: _bridge.options.terrainTimeout);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> frameVisibleRoute(int id) async {
    if (id <= 0) throw ArgumentError('Invalid route ID');
    await _bridge.send({
      'type': 'frame-visible-routes',
      'routeId': id,
    }, timeout: _bridge.options.terrainTimeout);
  }

  void _handleRouteAction(Map<String, dynamic> data) {
    final state = _routeEditorState;
    if (state == null ||
        state['interactive'] != true ||
        data['editorId'] != state['editorId'] ||
        data['revision'] != state['revision']) {
      return;
    }
    final kind = RouteMapActionKind.values
        .where((kind) => kind.name == data['action'])
        .firstOrNull;
    if (kind == null) return;
    final id = data['id'];
    if (kind != RouteMapActionKind.add &&
        (id is! int ||
            !(state['waypoints'] as List).any((p) => p['id'] == id))) {
      return;
    }
    Wgs84Coordinate? position;
    if (kind == RouteMapActionKind.add || kind == RouteMapActionKind.move) {
      final lat = data['latitude'], lon = data['longitude'];
      if (lat is! num ||
          lon is! num ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180) {
        return;
      }
      position = Wgs84Coordinate(
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      );
    }
    _routeActions.add(
      RouteMapAction(kind, id: id is int ? id : null, position: position),
    );
  }

  bool _terrainAvailable = false;
  GlobeTerrainState _terrainState = GlobeTerrainState.loading;
  String? _terrainReason;
  bool _terrainRetrying = false;
  int _terrainEpoch = 0;
  int _terrainRetryOperation = 0;
  GlobeMapStyle _mapStyle = GlobeMapStyle.satellite;
  GlobePoint? _selectedPoint;
  String? _error;
  bool _uasZonesVisible = false;
  bool _uasZonesLoading = false;
  String? _uasZonesError;
  UasZoneDetails? _selectedUasZone;
  List<UasZoneDetails> _selectedUasZones = const [];
  int _selectedUasZoneIndex = 0;
  int _uasSelectionOperation = 0;
  String? _uasSelectionError;
  UasDatasetAssessment? _uasDatasetAssessment;
  OsintDataset<Map<String, dynamic>>? _uasRejectedDataset;
  double _uasZonesFillOpacity = 0.20;
  DateTime? _uasZonesDownloadedAt;
  int? _uasZonesFeatureCount;
  UasRenderMetrics? _uasRenderMetrics;
  UasRenderMetrics? get uasRenderMetrics => _uasRenderMetrics;
  List<SpotMapMarker> _spotMarkers = const [];
  int? _selectedSpotId;
  int _spotMarkerRevision = 0;
  bool _savedSpotsVisible = true;
  List<GlobeOverlay> _overlayOrder = const [
    GlobeOverlay.uasZones,
    GlobeOverlay.savedSpots,
  ];
  UserPreferencesRepository? _preferencesRepository;
  UserPreferences _preferences = const UserPreferences();
  Future<void>? _preferencesLoad;
  Future<void>? _preferencesWrites;
  bool _preferencesLoading = false;
  bool _preferencesLoaded = false;
  String? _preferencesError;
  int _preferencesWriteRevision = 0;

  bool get savedSpotsVisible => _savedSpotsVisible;
  List<GlobeOverlay> get overlayOrder => _overlayOrder;
  bool get preferencesLoading => _preferencesLoading;
  bool get preferencesLoadFailed =>
      _preferencesRepository != null &&
      !_preferencesLoaded &&
      !_preferencesLoading;
  bool get canEditPreferences =>
      !_preferencesLoading &&
      (_preferencesRepository == null || _preferencesLoaded);
  String? get preferencesError => _preferencesError;

  /// Finish local I/O before the owner closes its database.
  Future<void> get preferencesSettled async {
    if (_preferencesLoading) await _preferencesLoad;
    await _preferencesWrites;
  }

  Future<void> initializePreferences(UserPreferencesRepository repository) {
    if (_preferencesRepository != null) {
      return _preferencesLoad ?? Future.value();
    }
    _preferencesRepository = repository;
    return retryLoadingPreferences();
  }

  Future<void> retryLoadingPreferences() {
    if (_preferencesLoading || _disposed) {
      return _preferencesLoad ?? Future.value();
    }
    return _preferencesLoad = _loadPreferences(reset: false);
  }

  Future<void> resetPreferences() {
    if (_preferencesLoading || _disposed) {
      return _preferencesLoad ?? Future.value();
    }
    return _preferencesLoad = _loadPreferences(reset: true);
  }

  Future<void> _loadPreferences({required bool reset}) async {
    final repository = _preferencesRepository;
    if (repository == null) return;
    _preferencesLoading = true;
    _preferencesError = null;
    notifyListeners();
    try {
      if (reset) await repository.resetPreferences();
      final preferences = await repository.getPreferences();
      if (_disposed) return;
      UserPreferences.validateOverlayOrder(preferences.overlayOrder);
      _preferences = preferences.copyWith();
      _requestedMapStyle = preferences.mapStyle;
      _requestedUasOpacity = preferences.uasZonesFillOpacity;
      _uasRequestedVisible = preferences.uasZonesVisible;
      _savedSpotsVisible = preferences.savedSpotsVisible;
      _overlayOrder = _preferences.overlayOrder;
      _preferencesLoaded = true;
      if (_ready) {
        await _restoreRendererState(_connectionGeneration, forceSettings: true);
      }
    } catch (error) {
      if (!_disposed) {
        _preferencesError = 'Unable to load map preferences: $error';
      }
    } finally {
      _preferencesLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _checkPreferencesEditable() {
    if (!canEditPreferences) {
      throw StateError('Map preferences are not available');
    }
  }

  Future<void> _savePreferences(UserPreferences preferences) {
    if (_disposed) return Future.value();
    _preferences = preferences.copyWith();
    final repository = _preferencesRepository;
    if (repository == null || !_preferencesLoaded) return Future.value();
    final snapshot = _preferences;
    final revision = ++_preferencesWriteRevision;
    // A slow earlier write must never overwrite a later UI choice.
    return _preferencesWrites = (_preferencesWrites ?? Future<void>.value())
        .then((_) async {
          try {
            await repository.savePreferences(snapshot);
            if (!_disposed && revision == _preferencesWriteRevision) {
              _preferencesError = null;
            }
          } catch (error) {
            if (!_disposed && revision == _preferencesWriteRevision) {
              _preferencesError = 'Map changes are not saved: $error';
            }
          }
          if (revision == _preferencesWriteRevision) _preferencesWrites = null;
          if (!_disposed) notifyListeners();
        });
  }

  Future<void> retrySavingPreferences() => _savePreferences(_preferences);

  Future<void> setSavedSpotsVisible(bool visible) async {
    _checkPreferencesEditable();
    await _send({'type': 'set-spots-visible', 'visible': visible});
    if (_disposed) return;
    _savedSpotsVisible = visible;
    if (!visible) _selectedSpotId = null;
    notifyListeners();
    await _savePreferences(_preferences.copyWith(savedSpotsVisible: visible));
  }

  Future<void> setOverlayOrder(List<GlobeOverlay> order) async {
    _checkPreferencesEditable();
    UserPreferences.validateOverlayOrder(order);
    final snapshot = List<GlobeOverlay>.unmodifiable(order);
    await _send({
      'type': 'set-overlay-order',
      'order': snapshot.map((item) => item.name).toList(),
    });
    if (_disposed) return;
    _overlayOrder = snapshot;
    notifyListeners();
    await _savePreferences(_preferences.copyWith(overlayOrder: snapshot));
  }

  bool get uasZonesVisible => _uasZonesVisible;
  bool get uasRequestedVisible => _uasRequestedVisible;
  bool get canClearUasCache {
    final provider = _uasProvider;
    return provider is CachedOsintProvider<Map<String, dynamic>> &&
        !provider.isClearing &&
        !_uasZonesLoading &&
        uasProviderStatus.update != OsintUpdateState.loading;
  }

  OsintProviderState<Map<String, dynamic>> get uasDisplayedStatus =>
      OsintProviderState(
        update: uasProviderStatus.update,
        freshness: uasDataFreshness,
        checkedAtUtc: uasProviderStatus.checkedAtUtc,
        dataset: _uasDisplayedDataset,
        error:
            uasProviderStatus.error ??
            (_uasZonesError == null
                ? null
                : OsintProviderException(
                    providerId: _uasProvider.id,
                    kind: OsintFailureKind.unknown,
                    message: _uasZonesError!,
                  )),
        servedFromCache: uasProviderStatus.servedFromCache,
        cacheError: uasProviderStatus.cacheError,
      );
  bool get uasZonesLoading => _uasZonesLoading;
  String? get uasZonesError => _uasZonesError;
  bool get isReady => _ready;
  bool get terrainAvailable => _terrainAvailable;

  /// Invalidates calculations when terrain or renderer state changes.
  (int, int) get terrainRevision => (_connectionGeneration, _terrainEpoch);
  OsintSource get uasSource =>
      _uasDisplayedDataset?.source ?? _uasProvider.source;
  OsintDataset<Map<String, dynamic>>? get uasDisplayedDataset =>
      _uasDisplayedDataset;
  GeoJsonDownloadMetrics? get uasNetworkMetrics =>
      _uasProvider is GeoJsonOsintProvider
      ? _uasProvider.lastDownloadMetrics
      : null;
  GlobeTransferMetrics? get uasTransferMetrics =>
      _bridge.lastTransferMetrics?.type == 'set-uas-zones' ||
          _bridge.lastTransferMetrics?.type == 'replace-uas-zones'
      ? _bridge.lastTransferMetrics
      : null;
  OsintProviderState<Map<String, dynamic>> get uasProviderStatus =>
      _uasProvider.status;
  OsintFreshness get uasDataFreshness =>
      _uasDisplayedDataset?.freshnessAt(_uasProvider.status.checkedAtUtc) ??
      OsintFreshness.notLoaded;
  GlobeTerrainState get terrainState => _terrainState;
  String? get terrainReason => _terrainReason;
  bool get terrainRetrying => _terrainRetrying;
  bool get canRetryTerrain =>
      _ready &&
      !_terrainRetrying &&
      _terrainState != GlobeTerrainState.loading &&
      _terrainState != GlobeTerrainState.ready &&
      _terrainReason != 'diagnosticOffline';
  GlobeMapStyle get mapStyle => _mapStyle;

  /// The active raw map point. Saved spots and UAS zones are separate,
  /// mutually exclusive selections and clear this value when selected.
  GlobePoint? get selectedPoint => _selectedPoint;
  String? get error => _error;
  UasZoneDetails? get selectedUasZone => _selectedUasZone;
  List<UasZoneDetails> get selectedUasZones => _selectedUasZones;
  int get selectedUasZoneIndex => _selectedUasZoneIndex;
  String? get uasSelectionError => _uasSelectionError;
  UasDatasetAssessment? get uasDatasetAssessment => _uasDatasetAssessment;
  double get uasZonesFillOpacity => _uasZonesFillOpacity;
  DateTime? get uasZonesDownloadedAt => _uasZonesDownloadedAt;
  int? get uasZonesFeatureCount => _uasZonesFeatureCount;
  int? get selectedSpotId => _selectedSpotId;

  void clearSelectedSpot() {
    if (_selectedSpotId == null) return;
    _selectedSpotId = null;
    notifyListeners();
  }

  Future<void> setSpotMarkers(List<SpotMapMarker> markers) async {
    final ids = <int>{};

    if (markers.length > 10000) {
      throw ArgumentError('Too many spot markers');
    }

    for (final marker in markers) {
      if (marker.id <= 0 ||
          !ids.add(marker.id) ||
          marker.name.trim().isEmpty ||
          !marker.latitude.isFinite ||
          !marker.longitude.isFinite ||
          marker.latitude < -90 ||
          marker.latitude > 90 ||
          marker.longitude < -180 ||
          marker.longitude > 180) {
        throw ArgumentError('Invalid spot marker');
      }
    }

    _spotMarkers = List.unmodifiable(markers);

    if (_selectedSpotId != null &&
        !_spotMarkers.any((spot) => spot.id == _selectedSpotId)) {
      clearSelectedSpot();
    }

    if (_ready) {
      await _pushSpotMarkers();
    }
  }

  Future<void> _pushSpotMarkers() {
    return _send({
      'type': 'set-spot-markers',
      'revision': ++_spotMarkerRevision,
      'spots': _spotMarkers.map((spot) => spot.toJson()).toList(),
    });
  }

  void clearSelectedUasZone() {
    if (_selectedUasZone == null) return;

    _resetUasSelection();
    notifyListeners();
  }

  void _resetUasSelection() {
    _uasSelectionOperation++;
    _selectedUasZone = null;
    _selectedUasZones = const [];
    _selectedUasZoneIndex = 0;
    _uasSelectionError = null;
  }

  void selectUasZone(int index) {
    if (index < 0 || index >= _selectedUasZones.length) return;
    _selectedUasZoneIndex = index;
    _selectedUasZone = _selectedUasZones[index];
    notifyListeners();
  }

  Future<void> _inspectOverlappingZones(
    double latitude,
    double longitude,
  ) async {
    final dataset = _uasDisplayedDataset;
    if (dataset == null) return;
    final operation = _uasSelectionOperation;
    final generation = _connectionGeneration;
    bool current() =>
        !_disposed &&
        operation == _uasSelectionOperation &&
        generation == _connectionGeneration &&
        identical(dataset, _uasDisplayedDataset);
    try {
      final zones = await UasAirspaceChecker.zonesAt(
        dataset,
        Wgs84Coordinate(latitude: latitude, longitude: longitude),
      );
      if (!current()) return;
      if (zones.isEmpty) {
        _uasSelectionError =
            'Other overlapping zones could not be verified at this position.';
      } else {
        _selectedUasZones = zones;
        _selectedUasZoneIndex = 0;
        _selectedUasZone = zones.first;
      }
      notifyListeners();
    } catch (_) {
      if (!current()) return;
      _uasSelectionError =
          'Unable to inspect overlapping zones. Select the position again.';
      notifyListeners();
    }
  }

  void attach(GlobeCommandSender sender) {
    _bridge.attach(sender);
    _connectionGeneration++;
    _ready = false;
  }

  void detach() {
    _bridge.detach();
    _resetConnection();
  }

  void rendererLoading() {
    _bridge.endSession();
    _resetConnection();
  }

  void suspend() {
    _bridge.cancelPending();
    _resetConnection();
  }

  void _resetConnection() {
    obstacles.rendererLost();
    _groundViewActive = _groundViewPending = false;
    _groundViewMessage = null;
    _connectionGeneration++;
    _uasOperation++;
    _spotFocusSequence++;
    _ready = false;
    _terrainAvailable = false;
    _terrainState = GlobeTerrainState.loading;
    _terrainReason = null;
    _terrainRetrying = false;
    _terrainEpoch++;
    _terrainRetryOperation++;
    _uasDatasetSentToRenderer = false;
    _uasDisplayedDataset = null;
    _uasDatasetAssessment = null;
    _uasZonesVisible = false;
    _uasZonesLoading = false;
    _error = null;
    _uasZonesError = null;
    _selectedPoint = null;
    _selectedSpotId = null;
    _resetUasSelection();
    if (!_disposed) notifyListeners();
  }

  Future<({List<double> heights, String samplingMethod})> queryRouteTerrain(
    List<Wgs84Coordinate> positions,
  ) async {
    if (positions.isEmpty ||
        positions.length > 256 ||
        positions.any(
          (p) =>
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        )) {
      throw ArgumentError('Invalid terrain sample batch');
    }
    if (!_ready || !_terrainAvailable) {
      throw StateError('Detailed terrain unavailable');
    }
    final revision = terrainRevision;
    final result = await _request({
      'type': 'query-route-terrain',
      'positions': [
        for (final p in positions)
          {'latitude': p.latitude, 'longitude': p.longitude},
      ],
    }, timeout: _bridge.options.terrainTimeout);
    if (_disposed ||
        !_ready ||
        !_terrainAvailable ||
        revision != terrainRevision) {
      throw StateError('Terrain changed during profile calculation');
    }
    final heights = result['heights'];
    if (result['heightReference'] != 'wgs84Ellipsoid' ||
        !const [
          'most-detailed',
          'level-12',
        ].contains(result['samplingMethod']) ||
        heights is! List ||
        heights.length != positions.length ||
        heights.any((h) => h is! num || !h.isFinite || h.abs() > 100000)) {
      throw const FormatException('Incomplete terrain profile');
    }
    return (
      heights: List<double>.unmodifiable(
        heights.map((h) => (h as num).toDouble()),
      ),
      samplingMethod: result['samplingMethod'] as String,
    );
  }

  Future<TerrainElevation> queryTerrainElevation({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid terrain coordinates');
    }

    if (!_ready) {
      throw StateError('Globe is not ready');
    }

    if (!_terrainAvailable) {
      throw StateError('Detailed terrain data unavailable');
    }
    final terrainEpoch = _terrainEpoch;

    final result = await _request({
      'type': 'query-terrain-elevation',
      'latitude': latitude,
      'longitude': longitude,
    }, timeout: _bridge.options.terrainTimeout);
    if (_disposed || !_terrainAvailable || terrainEpoch != _terrainEpoch) {
      throw StateError('Terrain changed during the request');
    }
    final height = result['heightMeters'];
    final method = result['samplingMethod'];
    if (result['latitude'] != latitude ||
        result['longitude'] != longitude ||
        result['heightReference'] != VerticalReference.wgs84Ellipsoid.name ||
        height is! num ||
        !height.isFinite ||
        method is! String ||
        method.isEmpty ||
        method.length > 80) {
      throw const FormatException('Invalid terrain elevation response');
    }
    return TerrainElevation(
      latitude: latitude,
      longitude: longitude,
      elevation: ReferencedElevation(
        meters: height.toDouble(),
        reference: VerticalReference.wgs84Ellipsoid,
      ),
      samplingMethod: method,
    );
  }

  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> command, {
    Duration? timeout,
  }) {
    if (!_ready || _disposed) {
      return Future.error(StateError('Globe is not ready'));
    }
    return _bridge.send(command, timeout: timeout);
  }

  Future<void> _send(Map<String, dynamic> command) async {
    await _request(command);
  }

  Future<void> resetCamera() {
    return _send({'type': 'reset-camera'});
  }

  Future<void> reloadRenderer() => _send({'type': 'reload-renderer'});

  Future<void> retryTerrain() async {
    if (_terrainRetrying) return;
    if (!_ready) throw StateError('Globe is not ready');
    if (!canRetryTerrain) return;
    final operation = ++_terrainRetryOperation;
    final generation = _connectionGeneration;
    _terrainRetrying = true;
    notifyListeners();
    try {
      await _send({'type': 'retry-terrain'});
    } catch (_) {
      if (!_disposed &&
          generation == _connectionGeneration &&
          operation == _terrainRetryOperation &&
          _terrainState == GlobeTerrainState.loading) {
        _applyTerrainStatus('unavailable', 'connectionFailed');
      }
      rethrow;
    } finally {
      if (!_disposed && operation == _terrainRetryOperation) {
        _terrainRetrying = false;
        notifyListeners();
      }
    }
  }

  void _applyTerrainStatus(Object? state, Object? reason) {
    final next = switch (state) {
      'loading' => GlobeTerrainState.loading,
      'ready' => GlobeTerrainState.ready,
      'unavailable' => GlobeTerrainState.unavailable,
      'offline' => GlobeTerrainState.offline,
      _ => null,
    };
    if (next == null) return;
    final validReason = switch (next) {
      GlobeTerrainState.ready || GlobeTerrainState.loading => reason == null,
      GlobeTerrainState.offline =>
        reason == 'networkOffline' || reason == 'diagnosticOffline',
      GlobeTerrainState.unavailable =>
        reason == 'connectionFailed' ||
            reason == 'tileFailed' ||
            reason == 'networkRestored',
    };
    if (!validReason || (_terrainState == next && _terrainReason == reason)) {
      return;
    }
    _terrainState = next;
    _terrainReason = reason as String?;
    _terrainAvailable = next == GlobeTerrainState.ready;
    _terrainEpoch++;
    _spotFocusSequence++;
    _selectedPoint = null;
    notifyListeners();
  }

  Future<void> flyTo({
    required double latitude,
    required double longitude,
    double altitude = 12000,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !altitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        altitude <= 0) {
      throw ArgumentError('Invalid camera coordinates');
    }

    return _send({
      'type': 'fly-to',
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
    });
  }

  Future<void> setMapStyle(GlobeMapStyle style) async {
    _checkPreferencesEditable();
    await _send({'type': 'set-map-style', 'style': style.name});
    _requestedMapStyle = style;
    await _savePreferences(_preferences.copyWith(mapStyle: style));
  }

  Future<void> setUasZonesVisible(bool visible) async {
    _checkPreferencesEditable();
    final previous = _uasRequestedVisible;
    _uasRequestedVisible = visible;
    final update = _updateUas(forceRefresh: false);
    final operation = _uasOperation;
    try {
      await update;
    } catch (_) {
      if (operation == _uasOperation) _uasRequestedVisible = previous;
      rethrow;
    }
    if (operation != _uasOperation || _disposed) return;
    await _savePreferences(_preferences.copyWith(uasZonesVisible: visible));
  }

  Future<void> refreshUasZones() => _updateUas(forceRefresh: true);

  Future<void> clearUasCache() async {
    final provider = _uasProvider;
    if (provider is! CachedOsintProvider<Map<String, dynamic>> ||
        !canClearUasCache) {
      return;
    }
    _uasOperation++;
    if (_ready) await _send({'type': 'set-uas-zones', 'visible': false});
    await provider.clearCache();
    if (_disposed) return;
    _uasRequestedVisible = false;
    _uasZonesVisible = false;
    _uasDatasetSentToRenderer = false;
    _uasDisplayedDataset = null;
    _uasDatasetAssessment = null;
    _uasRejectedDataset = null;
    _uasZonesDownloadedAt = null;
    _uasZonesFeatureCount = null;
    _uasZonesError = null;
    clearSelectedUasZone();
    await _savePreferences(_preferences.copyWith(uasZonesVisible: false));
    notifyListeners();
  }

  Future<void> _updateUas({required bool forceRefresh}) async {
    if (!_ready) throw StateError('Globe is not ready');
    final operation = ++_uasOperation;
    final generation = _connectionGeneration;
    bool current() =>
        !_disposed &&
        operation == _uasOperation &&
        generation == _connectionGeneration;
    if (!_uasRequestedVisible && !forceRefresh) {
      await _send({'type': 'set-uas-zones', 'visible': false});
      return;
    }
    _uasZonesLoading = true;
    _uasZonesError = null;
    notifyListeners();
    try {
      if (_uasDatasetSentToRenderer &&
          _uasRejectedDataset == null &&
          !forceRefresh &&
          uasDataFreshness == OsintFreshness.fresh) {
        await _send({'type': 'set-uas-zones', 'visible': true});
      } else {
        final dataset = await _uasProvider.fetch(
          forceRefresh:
              forceRefresh ||
              _uasRejectedDataset != null &&
                  identical(_uasRejectedDataset, _uasProvider.status.dataset),
        );
        if (!current()) return;
        late UasDatasetAssessment assessment;
        try {
          assessment = UasDatasetAssessment.inspect(dataset.data);
          _uasRejectedDataset = null;
        } on FormatException {
          _uasRejectedDataset = dataset;
          rethrow;
        }
        await _request({
          'type': forceRefresh || _uasDatasetSentToRenderer
              ? 'replace-uas-zones'
              : 'set-uas-zones',
          'visible': _uasRequestedVisible,
          'geojson': assessment.geoJson,
          'downloadedAtUtc': dataset.fetchedAtUtc.toIso8601String(),
          'sourceAttribution':
              dataset.source.attribution ?? dataset.source.publisher,
        }, timeout: _bridge.options.datasetTimeout);
        if (current()) {
          _uasDatasetSentToRenderer = true;
          _resetUasSelection();
          _uasDisplayedDataset = dataset;
          _uasDatasetAssessment = assessment;
        }
      }
    } catch (error) {
      if (!current()) return;
      _uasZonesError = error.toString();
      rethrow;
    } finally {
      if (current()) {
        _uasZonesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setUasZonesFillOpacity(double opacity) async {
    _checkPreferencesEditable();
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(opacity, 'opacity', 'Must be between 0 and 1');
    }

    await _send({'type': 'set-uas-opacity', 'opacity': opacity});
    _requestedUasOpacity = opacity;
    await _savePreferences(_preferences.copyWith(uasZonesFillOpacity: opacity));
  }

  void handleEvent(String message) {
    if (_disposed) return;
    final previousSession = _bridge.session;
    final data = _bridge.receive(message);
    if (data == null) return;
    if (!_ready &&
        data['type'] != 'globe-ready' &&
        data['type'] != 'renderer-loading' &&
        data['type'] != 'globe-error') {
      return;
    }

    if (obstacles.handleEvent(data)) return;
    switch (data['type']) {
      case 'ground-view-state':
        if (data['active'] is! bool || data['pending'] is! bool) return;
        _groundViewActive = data['active'] as bool;
        _groundViewPending = data['pending'] as bool;
        final reason = data['reason'];
        _groundViewMessage = reason is String
            ? reason.substring(0, reason.length.clamp(0, 180))
            : null;
        notifyListeners();
      case 'route-map-action':
        _handleRouteAction(data);
      case 'route-preview-error':
        _routePreviewError = data['message'] is String
            ? (data['message'] as String).substring(
                0,
                (data['message'] as String).length.clamp(0, 300),
              )
            : 'Route preview unavailable';
        notifyListeners();
      case 'renderer-loading':
        _resetConnection();

      case 'globe-ready':
        if (_ready && previousSession == _bridge.session) return;
        obstacles.rendererLost();
        _groundViewActive = _groundViewPending = false;
        _groundViewMessage = null;
        _connectionGeneration++;
        _uasOperation++;
        _ready = true;
        _error = null;
        _terrainAvailable = data['terrainAvailable'] == true;
        _terrainState = _terrainAvailable
            ? GlobeTerrainState.ready
            : GlobeTerrainState.unavailable;
        _terrainReason = _terrainAvailable ? null : 'connectionFailed';
        _terrainEpoch++;
        _uasDatasetSentToRenderer = false;
        _uasDisplayedDataset = null;
        _uasZonesVisible = false;
        _uasZonesLoading = false;
        _uasRenderMetrics = null;
        _selectedPoint = null;
        _selectedSpotId = null;
        _resetUasSelection();
        final generation = _connectionGeneration;
        unawaited(_restoreRendererState(generation));
        notifyListeners();

      case 'terrain-status':
        _applyTerrainStatus(data['state'], data['reason']);

      case 'spot-selected':
        final id = data['id'];

        if (!_savedSpotsVisible ||
            id is! int ||
            !_spotMarkers.any((spot) => spot.id == id)) {
          return;
        }

        _selectedSpotId = id;
        obstacles.clearSelection();
        _selectedPoint = null;
        _resetUasSelection();
        notifyListeners();

      case 'spot-cleared':
        clearSelectedSpot();

      case 'point-selected':
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        final altitude = data['altitude'];

        if (latitude is num &&
            longitude is num &&
            altitude is num &&
            latitude.isFinite &&
            longitude.isFinite &&
            altitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          _selectedSpotId = null;
          _resetUasSelection();
          obstacles.clearSelection();
          _selectedPoint = GlobePoint(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
            altitude: altitude.toDouble(),
            heightReference:
                _terrainAvailable &&
                    data['heightReference'] ==
                        VerticalReference.wgs84Ellipsoid.name
                ? VerticalReference.wgs84Ellipsoid
                : VerticalReference.unverified,
          );

          notifyListeners();
        }

      case 'map-style-changed':
        final style = data['style'];

        for (final candidate in GlobeMapStyle.values) {
          if (candidate.name == style) {
            _mapStyle = candidate;
            notifyListeners();
            break;
          }
        }

      case 'globe-error':
        _error = data['message']?.toString() ?? 'Unknown globe error';
        _uasZonesLoading = false;
        notifyListeners();

      case 'uas-render-metrics':
        final loadMs = data['loadMs'];
        final attachMs = data['attachMs'];
        final firstFrameMs = data['firstFrameMs'];
        final count = data['featureCount'];
        if (loadMs is num &&
            attachMs is num &&
            count is int &&
            loadMs.isFinite &&
            attachMs.isFinite &&
            loadMs >= 0 &&
            loadMs < 600000 &&
            attachMs >= 0 &&
            attachMs < 600000 &&
            count >= 0 &&
            count <= 1000000 &&
            (firstFrameMs == null ||
                (firstFrameMs is num &&
                    firstFrameMs.isFinite &&
                    firstFrameMs >= 0 &&
                    firstFrameMs < 600000))) {
          _uasRenderMetrics = UasRenderMetrics(
            featureCount: count,
            loadMs: loadMs.toDouble(),
            attachMs: attachMs.toDouble(),
            firstFrameMs: (firstFrameMs as num?)?.toDouble(),
          );
          notifyListeners();
        }

      case 'uas-zones-status':
        final visible = data['visible'];
        final loading = data['loading'];

        if (visible is! bool || loading is! bool) {
          return;
        }

        _uasZonesVisible = visible;
        _uasZonesLoading = loading;
        _uasZonesError = data['error'] is String
            ? data['error'] as String
            : null;

        if (_uasZonesError != null && !_uasZonesVisible) {
          _uasDatasetSentToRenderer = false;
        }

        final opacity = data['fillOpacity'];

        if (opacity is num) {
          final value = opacity.toDouble();

          if (value.isFinite && value >= 0 && value <= 1) {
            _uasZonesFillOpacity = value;
          }
        }

        final downloadedAt = data['downloadedAtUtc'];

        if (downloadedAt is String) {
          _uasZonesDownloadedAt = DateTime.tryParse(downloadedAt)?.toUtc();
        }

        final featureCount = data['featureCount'];

        if (featureCount is int && featureCount >= 0) {
          _uasZonesFeatureCount = featureCount;
        }

        notifyListeners();

      case 'uas-zone-selected':
        final rawAttributes = data['attributes'];
        final omitted = data['omittedAttributeCount'] ?? 0;
        final shortened = data['truncatedAttributes'] ?? const <String>[];

        if (rawAttributes is! Map<String, dynamic> ||
            rawAttributes.length > 128 ||
            omitted is! int ||
            omitted < 0 ||
            shortened is! List ||
            shortened.length > 128 ||
            shortened.any((key) => key is! String || key.length > 120)) {
          return;
        }

        final attributes = <String, String>{};

        for (final entry in rawAttributes.entries) {
          if (entry.key.length > 120 ||
              entry.value is String && (entry.value as String).length > 8000) {
            return;
          }
          if (entry.value is String) {
            attributes[entry.key] = entry.value as String;
          }
        }

        _selectedPoint = null;
        _selectedSpotId = null;
        _resetUasSelection();
        _selectedUasZone = UasZoneDetails(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'UAS Zone',
          attributes: Map.unmodifiable(attributes),
          omittedAttributeCount: omitted,
          truncatedAttributes: List<String>.unmodifiable(shortened),
        );
        _selectedUasZones = List.unmodifiable([_selectedUasZone!]);

        final latitude = data['latitude'];
        final longitude = data['longitude'];
        if (latitude is num &&
            longitude is num &&
            latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          unawaited(
            _inspectOverlappingZones(latitude.toDouble(), longitude.toDouble()),
          );
        }

        obstacles.clearSelection();

        notifyListeners();

      case 'uas-zone-cleared':
        clearSelectedUasZone();

        notifyListeners();
    }
  }

  Future<void> _restoreRendererState(
    int generation, {
    bool forceSettings = false,
  }) async {
    bool current() =>
        !_disposed && _ready && generation == _connectionGeneration;
    unawaited(obstacles.rendererReady(force: forceSettings));
    try {
      if (forceSettings || _requestedMapStyle != GlobeMapStyle.satellite) {
        await _send({
          'type': 'set-map-style',
          'style': _requestedMapStyle.name,
        });
      }
      if (!current()) return;
      if (forceSettings || _requestedUasOpacity != 0.20) {
        await _send({
          'type': 'set-uas-opacity',
          'opacity': _requestedUasOpacity,
        });
      }
      if (!current()) return;
      if (_spotMarkers.isNotEmpty) await _pushSpotMarkers();
      if (!current()) return;
      if (_routeEditorState != null) {
        await _bridge.send(
          _routeEditorState!,
          timeout: _bridge.options.terrainTimeout,
        );
      }
      if (!current()) return;
      if (_visibleRoutesState != null) {
        await _bridge.send(
          _visibleRoutesState!,
          timeout: _bridge.options.terrainTimeout,
        );
      }
      if (!current()) return;
      if (forceSettings || !_savedSpotsVisible) {
        await _send({
          'type': 'set-spots-visible',
          'visible': _savedSpotsVisible,
        });
      }
      if (!current()) return;
      if (forceSettings || _overlayOrder.first != GlobeOverlay.uasZones) {
        await _send({
          'type': 'set-overlay-order',
          'order': _overlayOrder.map((item) => item.name).toList(),
        });
      }
      if (!current()) return;
      if (_weatherOverlayCommand != null && current()) {
        await _send(_weatherOverlayCommand!);
      }
      if (!current()) return;
      if (_uasRequestedVisible) await _updateUas(forceRefresh: false);
      if (current() && forceSettings && !_uasRequestedVisible) {
        await _send({'type': 'set-uas-zones', 'visible': false});
      }
    } catch (error) {
      if (!current()) return;
      _error = 'Unable to restore map state: $error';
      notifyListeners();
    }
  }

  int _spotFocusSequence = 0;

  // Focuses a saved FPV spot on the actual terrain.
  //
  // Unlike flyTo(), this uses the terrain position as
  // the camera's target and an independent zoom distance.
  Future<void> focusSpot({
    required double latitude,
    required double longitude,
    double rangeMeters = 300,
  }) async {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid spot coordinates');
    }

    if (!rangeMeters.isFinite || rangeMeters < 50 || rangeMeters > 10000) {
      throw ArgumentError.value(
        rangeMeters,
        'rangeMeters',
        'Must be between 50 and 10000 meters',
      );
    }

    final sequence = ++_spotFocusSequence;

    // Reuse our existing Cesium terrain elevation query.
    final terrain = await queryTerrainElevation(
      latitude: latitude,
      longitude: longitude,
    );

    // Ignore outdated results when another spot was
    // selected while this request was in progress.
    if (sequence != _spotFocusSequence) {
      return;
    }

    await _send({
      'type': 'focus-spot',
      'latitude': latitude,
      'longitude': longitude,
      'terrainHeightMeters': terrain.heightMeters,
      'rangeMeters': rangeMeters,
    });
  }

  @override
  void dispose() {
    final uas = _uasProvider;
    final pending = [
      if (uas is CachedOsintProvider<Map<String, dynamic>>) uas.settled,
      obstacles.provider.settled,
    ];
    obstacles.removeListener(_handleProviderChanged);
    obstacles.dispose();
    unawaited(_routeActions.close());
    _uasProvider.removeListener(_handleProviderChanged);
    if (_ownsUasProvider) {
      _uasProvider.dispose();
    }
    _disposed = true;
    _connectionGeneration++;
    _uasOperation++;
    _bridge.detach();
    if (_cache case final cache?) {
      unawaited(Future.wait(pending).then((_) => cache.close()));
    }
    super.dispose();
  }
}

/// Cesium-side measured durations. First-frame time begins after data source
/// attachment; it is distinct from the Flutter bridge acknowledgement time.
class UasRenderMetrics {
  const UasRenderMetrics({
    required this.featureCount,
    required this.loadMs,
    required this.attachMs,
    this.firstFrameMs,
  });
  final int featureCount;
  final double loadMs;
  final double attachMs;
  final double? firstFrameMs;
}
