import 'dart:convert';
import 'dart:math' as math;

import '../road_routing.dart';

/// Deliberately small geographic query. Switzerland and nearby border points.
class EvChargingArea {
  EvChargingArea({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 2000,
  }) {
    MobilityPoint(latitude, longitude);
    if (latitude < 45 ||
        latitude > 48.5 ||
        longitude < 5.5 ||
        longitude > 11.5 ||
        radiusMeters < 250 ||
        radiusMeters > 5000) {
      throw const FormatException(
        'Choose an area in Switzerland (250–5000 m).',
      );
    }
  }
  final double latitude, longitude;
  final int radiusMeters;
  String get identity =>
      '${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}:$radiusMeters';

  /// WGS84 envelope passed to the server, not a nationwide data fetch.
  List<double> get envelope {
    final dy = radiusMeters / 111320.0;
    final dx = radiusMeters / (111320.0 * math.cos(latitude * math.pi / 180));
    return [longitude - dx, latitude - dy, longitude + dx, latitude + dy];
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radius': radiusMeters,
  };
  factory EvChargingArea.fromJson(Map<String, dynamic> data) => EvChargingArea(
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    radiusMeters: data['radius'] as int,
  );
  bool contains(double lat, double lon) {
    final phi1 = latitude * math.pi / 180;
    final phi2 = lat * math.pi / 180;
    final dphi = (lat - latitude) * math.pi / 180;
    final dlambda = (lon - longitude) * math.pi / 180;
    final a =
        math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dlambda / 2) *
            math.sin(dlambda / 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1))) <= radiusMeters;
  }
}

class EvChargingConnector {
  const EvChargingConnector({
    required this.id,
    required this.type,
    this.powerKw,
  });
  final String id, type;
  final double? powerKw;
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'powerKw': powerKw};
  factory EvChargingConnector.fromJson(Map<String, dynamic> json) =>
      EvChargingConnector(
        id: json['id'] as String,
        type: json['type'] as String,
        powerKw: (json['powerKw'] as num?)?.toDouble(),
      );
}

/// Site location and connectors never implicitly receive a live status.
class EvChargingStation {
  const EvChargingStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.evseIds,
    required this.connectors,
    this.address,
  });
  final String id, name;
  final double latitude, longitude;
  final String? address;
  final List<String> evseIds;
  final List<EvChargingConnector> connectors;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'evseIds': evseIds,
    'connectors': connectors.map((c) => c.toJson()).toList(),
  };
  factory EvChargingStation.fromJson(Map<String, dynamic> map) =>
      EvChargingStation(
        id: map['id'] as String,
        name: map['name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        address: map['address'] as String?,
        evseIds: List<String>.from(map['evseIds'] as List),
        connectors: (map['connectors'] as List)
            .map(
              (e) => EvChargingConnector.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}

class EvChargingAvailability {
  const EvChargingAvailability({
    required this.evseId,
    required this.rawStatus,
    required this.updatedUtc,
  });
  final String evseId, rawStatus;
  final DateTime? updatedUtc;

  /// Missing source timestamp, failed refresh or older than five minutes cannot be marked free.
  bool isFresh(DateTime now) =>
      updatedUtc != null &&
      !updatedUtc!.isAfter(now.toUtc().add(const Duration(minutes: 1))) &&
      now.toUtc().difference(updatedUtc!) <= const Duration(minutes: 5);
  bool isAvailable(DateTime now) =>
      rawStatus.toUpperCase() == 'AVAILABLE' && isFresh(now);
  String label(DateTime now) {
    if (!isFresh(now)) return 'Unbekannt / veraltet';
    return switch (rawStatus.toUpperCase()) {
      'AVAILABLE' => 'Gemeldet frei',
      'CHARGING' || 'OCCUPIED' => 'Belegt',
      'RESERVED' => 'Reserviert',
      'OUTOFORDER' || 'OUT_OF_SERVICE' || 'INOPERATIVE' => 'Ausser Betrieb',
      _ => 'Unbekannt',
    };
  }

  Map<String, dynamic> toJson() => {
    'evseId': evseId,
    'rawStatus': rawStatus,
    'updated': updatedUtc?.toIso8601String(),
  };
  factory EvChargingAvailability.fromJson(Map<String, dynamic> map) =>
      EvChargingAvailability(
        evseId: map['evseId'] as String,
        rawStatus: map['rawStatus'] as String,
        updatedUtc: DateTime.tryParse(map['updated'] as String? ?? '')?.toUtc(),
      );
}

class EvChargingSnapshot {
  const EvChargingSnapshot({
    required this.area,
    required this.fetchedUtc,
    required this.stations,
    required this.statuses,
    this.fromCache = false,
    this.refreshFailed = false,
    this.truncated = false,
  });
  final EvChargingArea area;
  final DateTime fetchedUtc;
  final List<EvChargingStation> stations;

  /// Strictly separate from static station data; keyed by charging point id.
  final Map<String, EvChargingAvailability> statuses;
  final bool fromCache, refreshFailed, truncated;
  bool isOld(DateTime now) =>
      now.toUtc().difference(fetchedUtc) > const Duration(minutes: 15);
  EvChargingSnapshot cached({bool failed = false}) => EvChargingSnapshot(
    area: area,
    fetchedUtc: fetchedUtc,
    stations: stations,
    statuses: statuses,
    truncated: truncated,
    fromCache: true,
    refreshFailed: failed,
  );
  Map<String, dynamic> toJson() => {
    'area': area.toJson(),
    'fetched': fetchedUtc.toIso8601String(),
    'stations': stations.map((e) => e.toJson()).toList(),
    'statuses': statuses.map((k, v) => MapEntry(k, v.toJson())),
    'truncated': truncated,
  };
  String encode() => jsonEncode(toJson());
  factory EvChargingSnapshot.decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    return EvChargingSnapshot(
      area: EvChargingArea.fromJson(
        Map<String, dynamic>.from(map['area'] as Map),
      ),
      fetchedUtc: DateTime.parse(map['fetched'] as String).toUtc(),
      stations: (map['stations'] as List)
          .map(
            (e) =>
                EvChargingStation.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      statuses: (map['statuses'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          EvChargingAvailability.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      truncated: map['truncated'] == true,
    );
  }
}
