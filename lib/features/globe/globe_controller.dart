import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/osint/osint_provider.dart';
import '../airspace/data/swiss_uas_provider.dart';
import 'globe_bridge.dart';

export 'globe_bridge.dart' show GlobeBridgeOptions, GlobeCommandSender;

enum GlobeMapStyle { satellite, topographic, relief }

class GlobePoint {
  const GlobePoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final double latitude;
  final double longitude;
  final double altitude;
}

class UasZoneDetails {
  const UasZoneDetails({
    required this.id,
    required this.name,
    required this.attributes,
  });

  final String id;
  final String name;
  final Map<String, String> attributes;
}

class TerrainElevation {
  const TerrainElevation({
    required this.latitude,
    required this.longitude,
    required this.heightMeters,
    required this.samplingMethod,
  });

  final double latitude;
  final double longitude;

  /// Height relative to the WGS84 reference ellipsoid.
  final double heightMeters;

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

class GlobeController extends ChangeNotifier {
  GlobeController({
    OsintProvider<Map<String, dynamic>>? uasProvider,
    GlobeBridgeOptions bridgeOptions = const GlobeBridgeOptions(),
  }) : _uasProvider = uasProvider ?? SwissUasProvider(),
       _ownsUasProvider = uasProvider == null,
       _bridge = GlobeBridge(options: bridgeOptions);

  final OsintProvider<Map<String, dynamic>> _uasProvider;
  final bool _ownsUasProvider;
  final GlobeBridge _bridge;
  bool _disposed = false;
  int _connectionGeneration = 0;
  int _uasOperation = 0;
  GlobeMapStyle _requestedMapStyle = GlobeMapStyle.satellite;
  double _requestedUasOpacity = 0.20;

  bool _uasDatasetSentToRenderer = false;
  bool _uasRequestedVisible = false;
  bool _ready = false;
  bool _terrainAvailable = false;
  GlobeMapStyle _mapStyle = GlobeMapStyle.satellite;
  GlobePoint? _selectedPoint;
  String? _error;
  bool _uasZonesVisible = false;
  bool _uasZonesLoading = false;
  String? _uasZonesError;
  UasZoneDetails? _selectedUasZone;
  double _uasZonesFillOpacity = 0.20;
  DateTime? _uasZonesDownloadedAt;
  int? _uasZonesFeatureCount;
  List<SpotMapMarker> _spotMarkers = const [];
  int? _selectedSpotId;
  int _spotMarkerRevision = 0;

  bool get uasZonesVisible => _uasZonesVisible;
  bool get uasZonesLoading => _uasZonesLoading;
  String? get uasZonesError => _uasZonesError;
  bool get isReady => _ready;
  bool get terrainAvailable => _terrainAvailable;
  GlobeMapStyle get mapStyle => _mapStyle;

  /// The active raw map point. Saved spots and UAS zones are separate,
  /// mutually exclusive selections and clear this value when selected.
  GlobePoint? get selectedPoint => _selectedPoint;
  String? get error => _error;
  UasZoneDetails? get selectedUasZone => _selectedUasZone;
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

    if (markers.length > 5000) {
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

    _selectedUasZone = null;
    notifyListeners();
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
    _connectionGeneration++;
    _uasOperation++;
    _spotFocusSequence++;
    _ready = false;
    _terrainAvailable = false;
    _uasDatasetSentToRenderer = false;
    _uasZonesVisible = false;
    _uasZonesLoading = false;
    _error = null;
    _uasZonesError = null;
    _selectedPoint = null;
    _selectedSpotId = null;
    _selectedUasZone = null;
    if (!_disposed) notifyListeners();
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

    final result = await _request({
      'type': 'query-terrain-elevation',
      'latitude': latitude,
      'longitude': longitude,
    }, timeout: _bridge.options.terrainTimeout);
    final height = result['heightMeters'];
    final method = result['samplingMethod'];
    if (result['latitude'] != latitude ||
        result['longitude'] != longitude ||
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
      heightMeters: height.toDouble(),
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
    _requestedMapStyle = style;
    await _send({'type': 'set-map-style', 'style': style.name});
  }

  Future<void> setUasZonesVisible(bool visible) {
    _uasRequestedVisible = visible;
    return _updateUas(forceRefresh: false);
  }

  Future<void> refreshUasZones() => _updateUas(forceRefresh: true);

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
      if (_uasDatasetSentToRenderer && !forceRefresh) {
        await _send({'type': 'set-uas-zones', 'visible': true});
      } else {
        final dataset = await _uasProvider.fetch(forceRefresh: forceRefresh);
        if (!current()) return;
        await _request({
          'type': forceRefresh ? 'replace-uas-zones' : 'set-uas-zones',
          'visible': _uasRequestedVisible,
          'geojson': dataset.data,
          'downloadedAtUtc': dataset.fetchedAtUtc.toIso8601String(),
        }, timeout: _bridge.options.datasetTimeout);
        if (current()) _uasDatasetSentToRenderer = true;
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

  Future<void> setUasZonesFillOpacity(double opacity) {
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(opacity, 'opacity', 'Must be between 0 and 1');
    }

    _requestedUasOpacity = opacity;
    return _send({'type': 'set-uas-opacity', 'opacity': opacity});
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

    switch (data['type']) {
      case 'renderer-loading':
        _resetConnection();

      case 'globe-ready':
        if (_ready && previousSession == _bridge.session) return;
        _connectionGeneration++;
        _uasOperation++;
        _ready = true;
        _error = null;
        _terrainAvailable = data['terrainAvailable'] == true;
        _uasDatasetSentToRenderer = false;
        _uasZonesVisible = false;
        _uasZonesLoading = false;
        _selectedPoint = null;
        _selectedSpotId = null;
        _selectedUasZone = null;
        final generation = _connectionGeneration;
        unawaited(_restoreRendererState(generation));
        notifyListeners();

      case 'spot-selected':
        final id = data['id'];

        if (id is! int || !_spotMarkers.any((spot) => spot.id == id)) {
          return;
        }

        _selectedSpotId = id;
        _selectedPoint = null;
        _selectedUasZone = null;
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
          _selectedUasZone = null;
          _selectedPoint = GlobePoint(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
            altitude: altitude.toDouble(),
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

        if (rawAttributes is! Map<String, dynamic>) {
          return;
        }

        final attributes = <String, String>{};

        for (final entry in rawAttributes.entries) {
          if (entry.value is String) {
            attributes[entry.key] = entry.value as String;
          }
        }

        _selectedPoint = null;
        _selectedSpotId = null;
        _selectedUasZone = UasZoneDetails(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'UAS Zone',
          attributes: attributes,
        );

        notifyListeners();

      case 'uas-zone-cleared':
        clearSelectedUasZone();

        notifyListeners();
    }
  }

  Future<void> _restoreRendererState(int generation) async {
    bool current() =>
        !_disposed && _ready && generation == _connectionGeneration;
    try {
      if (_requestedMapStyle != GlobeMapStyle.satellite) {
        await _send({
          'type': 'set-map-style',
          'style': _requestedMapStyle.name,
        });
      }
      if (!current()) return;
      if (_requestedUasOpacity != 0.20) {
        await _send({
          'type': 'set-uas-opacity',
          'opacity': _requestedUasOpacity,
        });
      }
      if (!current()) return;
      if (_spotMarkers.isNotEmpty) await _pushSpotMarkers();
      if (!current()) return;
      if (_uasRequestedVisible) await _updateUas(forceRefresh: false);
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
    if (_ownsUasProvider) {
      _uasProvider.dispose();
    }
    _disposed = true;
    _connectionGeneration++;
    _uasOperation++;
    _bridge.detach();
    super.dispose();
  }
}
