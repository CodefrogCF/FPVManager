import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  bool get uasZonesVisible => _uasZonesVisible;
  bool get uasZonesLoading => _uasZonesLoading;
  String? get uasZonesError => _uasZonesError;
  bool get isReady => _ready;
  bool get terrainAvailable => _terrainAvailable;
  GlobeMapStyle get mapStyle => _mapStyle;
  GlobePoint? get selectedPoint => _selectedPoint;
  String? get error => _error;
  UasZoneDetails? get selectedUasZone => _selectedUasZone;

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
  }

  Future<void> _send(Map<String, dynamic> command) async {
    final sender = _sender;

    if (!_ready || sender == null) {
      throw StateError('Globe is not ready');
    }

    await sender(jsonEncode(command));
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

  Future<void> setUasZonesVisible(bool visible) {
    return _send({'type': 'set-uas-zones', 'visible': visible});
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
}
