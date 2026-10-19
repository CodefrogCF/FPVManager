import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/osint/osint_provider.dart';
import '../airspace/data/swiss_uas_provider.dart';

enum GlobeMapStyle { satellite, topographic, relief }

typedef GlobeCommandSender = Future<void> Function(String command);

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
  GlobeController({OsintProvider<Map<String, dynamic>>? uasProvider})
    : _uasProvider = uasProvider ?? SwissUasProvider(),
      _ownsUasProvider = uasProvider == null;

  final OsintProvider<Map<String, dynamic>> _uasProvider;
  final bool _ownsUasProvider;

  bool _uasDatasetSentToRenderer = false;
  bool _uasRequestedVisible = false;
  int _nextTransferId = 0;
  int _nextElevationRequestId = 0;

  final Map<String, Completer<TerrainElevation>> _pendingElevationRequests = {};

  GlobeCommandSender? _sender;

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
    _sender = sender;
    _ready = false;
  }

  void detach() {
    _cancelElevationRequests();
    _sender = null;
    _ready = false;
    _uasDatasetSentToRenderer = false;
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

    final requestId = (++_nextElevationRequestId).toString();
    final completer = Completer<TerrainElevation>();

    _pendingElevationRequests[requestId] = completer;

    try {
      await _send({
        'type': 'query-terrain-elevation',
        'requestId': requestId,
        'latitude': latitude,
        'longitude': longitude,
      });

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Terrain elevation request timed out');
        },
      );
    } finally {
      _pendingElevationRequests.remove(requestId);
    }
  }

  void _cancelElevationRequests() {
    final pending = _pendingElevationRequests.values.toList();
    _pendingElevationRequests.clear();

    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Globe connection closed'));
      }
    }
  }

  Future<void> _send(Map<String, dynamic> command) async {
    final sender = _sender;

    if (!_ready || sender == null) {
      throw StateError('Globe is not ready');
    }

    final encoded = jsonEncode(command);

    const chunkSize = 32 * 1024;

    if (encoded.length <= chunkSize) {
      await sender(encoded);
      return;
    }

    final transferId = (++_nextTransferId).toString();

    await sender(jsonEncode({'type': 'transfer-start', 'id': transferId}));

    try {
      for (var offset = 0; offset < encoded.length; offset += chunkSize) {
        final end = (offset + chunkSize < encoded.length)
            ? offset + chunkSize
            : encoded.length;

        await sender(
          jsonEncode({
            'type': 'transfer-chunk',
            'id': transferId,
            'data': encoded.substring(offset, end),
          }),
        );
      }

      await sender(jsonEncode({'type': 'transfer-complete', 'id': transferId}));
    } catch (_) {
      try {
        await sender(jsonEncode({'type': 'transfer-abort', 'id': transferId}));
      } catch (_) {
        // The renderer may already be unavailable.
      }

      rethrow;
    }
  }

  Future<void> resetCamera() {
    return _send({'type': 'reset-camera'});
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
    await _send({'type': 'set-map-style', 'style': style.name});
  }

  Future<void> setUasZonesVisible(bool visible) async {
    _uasRequestedVisible = visible;

    if (!visible) {
      await _send({'type': 'set-uas-zones', 'visible': false});
      return;
    }

    if (_uasDatasetSentToRenderer) {
      await _send({'type': 'set-uas-zones', 'visible': true});
      return;
    }

    if (!_ready) {
      throw StateError('Globe is not ready');
    }

    _uasZonesLoading = true;
    _uasZonesError = null;
    notifyListeners();

    try {
      final dataset = await _uasProvider.fetch();

      if (!_uasRequestedVisible) {
        _uasZonesLoading = false;
        notifyListeners();
        return;
      }

      await _send({
        'type': 'set-uas-zones',
        'visible': true,
        'geojson': dataset.data,
        'downloadedAtUtc': dataset.fetchedAtUtc.toIso8601String(),
      });

      _uasDatasetSentToRenderer = true;
    } catch (error) {
      _uasZonesLoading = false;
      _uasZonesError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshUasZones() async {
    if (!_ready) {
      throw StateError('Globe is not ready');
    }

    _uasZonesLoading = true;
    _uasZonesError = null;
    notifyListeners();

    try {
      final dataset = await _uasProvider.fetch(forceRefresh: true);

      await _send({
        'type': 'replace-uas-zones',
        'geojson': dataset.data,
        'downloadedAtUtc': dataset.fetchedAtUtc.toIso8601String(),
      });

      _uasDatasetSentToRenderer = true;
    } catch (error) {
      _uasZonesLoading = false;
      _uasZonesError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setUasZonesFillOpacity(double opacity) {
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(opacity, 'opacity', 'Must be between 0 and 1');
    }

    return _send({'type': 'set-uas-opacity', 'opacity': opacity});
  }

  void handleEvent(String message) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(message);

      if (decoded is! Map<String, dynamic>) return;
      if (decoded['source'] != 'fpvmanager-globe') return;

      data = decoded;
    } on FormatException {
      return;
    }

    switch (data['type']) {
      case 'globe-ready':
        _ready = true;
        _error = null;
        _terrainAvailable = data['terrainAvailable'] == true;
        _uasDatasetSentToRenderer = false;
        if (_spotMarkers.isNotEmpty) {
          unawaited(
            _pushSpotMarkers().catchError((Object error, StackTrace stack) {
              _error = 'Spot marker sync failed: $error';
              notifyListeners();
            }),
          );
        }
        notifyListeners();

      case 'spot-selected':
        final id = data['id'];

        if (id is! int || !_spotMarkers.any((spot) => spot.id == id)) {
          return;
        }

        _selectedSpotId = id;
        _selectedUasZone = null;
        notifyListeners();

      case 'spot-cleared':
        clearSelectedSpot();

      case 'point-selected':
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        final altitude = data['altitude'];

        if (latitude is num && longitude is num && altitude is num) {
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

        _selectedUasZone = UasZoneDetails(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'UAS Zone',
          attributes: attributes,
        );

        notifyListeners();

      case 'terrain-elevation-result':
        final requestId = data['requestId']?.toString();

        if (requestId == null) return;

        final completer = _pendingElevationRequests[requestId];

        if (completer == null || completer.isCompleted) {
          return;
        }

        final error = data['error'];

        if (error is String && error.isNotEmpty) {
          completer.completeError(StateError(error));
          return;
        }

        final latitude = data['latitude'];
        final longitude = data['longitude'];
        final height = data['heightMeters'];
        final samplingMethod = data['samplingMethod'];

        if (latitude is! num ||
            longitude is! num ||
            height is! num ||
            samplingMethod is! String ||
            !latitude.toDouble().isFinite ||
            !longitude.toDouble().isFinite ||
            !height.toDouble().isFinite) {
          completer.completeError(
            const FormatException('Invalid terrain elevation response'),
          );
          return;
        }

        completer.complete(
          TerrainElevation(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
            heightMeters: height.toDouble(),
            samplingMethod: samplingMethod,
          ),
        );

      case 'uas-zone-cleared':
        clearSelectedUasZone();

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
    _cancelElevationRequests();
    super.dispose();
  }
}
