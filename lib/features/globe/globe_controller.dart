import 'dart:convert';

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

class GlobeController extends ChangeNotifier {
  GlobeController({OsintProvider<Map<String, dynamic>>? uasProvider})
    : _uasProvider = uasProvider ?? SwissUasProvider(),
      _ownsUasProvider = uasProvider == null;

  final OsintProvider<Map<String, dynamic>> _uasProvider;
  final bool _ownsUasProvider;

  bool _uasDatasetSentToRenderer = false;
  bool _uasRequestedVisible = false;
  int _nextTransferId = 0;

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
    _sender = null;
    _ready = false;
    _uasDatasetSentToRenderer = false;
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
        notifyListeners();

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

      case 'uas-zone-cleared':
        clearSelectedUasZone();

        notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_ownsUasProvider) {
      _uasProvider.dispose();
    }
    super.dispose();
  }
}
