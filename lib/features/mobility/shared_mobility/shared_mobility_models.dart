import 'dart:convert';
import 'dart:math' as math;

import '../road_routing.dart';

/// User-triggered, small search area; no nationwide feed download.
class SharedMobilityArea {
  SharedMobilityArea({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500,
  }) {
    MobilityPoint(latitude, longitude);
    if (latitude < 45 ||
        latitude > 48.5 ||
        longitude < 5.5 ||
        longitude > 11.5 ||
        radiusMeters < 200 ||
        radiusMeters > 2000) {
      throw const FormatException('Choose a Swiss search area of 200–2000 m.');
    }
  }
  final double latitude, longitude;
  final int radiusMeters;
  String get identity =>
      '${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}:$radiusMeters';
  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radius': radiusMeters,
  };
  factory SharedMobilityArea.fromJson(Map<String, dynamic> json) =>
      SharedMobilityArea(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: json['radius'] as int,
      );
  bool contains(double lat, double lon) {
    final radians = math.pi / 180;
    final dLat = (lat - latitude) * radians;
    final dLon = (lon - longitude) * radians;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(lat * radians) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1).toDouble())) <=
        radiusMeters;
  }
}

enum SharedMobilityPickup { stationBased, freeFloating, unknown }

enum SharedMobilityStatus {
  available,
  reserved,
  disabled,
  unavailable,
  unknown,
}

class SharedMobilityOffer {
  const SharedMobilityOffer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.latitude,
    required this.longitude,
    required this.pickup,
    required this.vehicleTypes,
    this.name,
    this.operatorUrl,
    this.reportedAvailable,
    this.reserved,
    this.disabled,
    this.installed,
    this.renting,
    this.availableCount,
    this.updatedUtc,
  });
  final String id, providerId, providerName;
  final String? name, operatorUrl;
  final double latitude, longitude;
  final SharedMobilityPickup pickup;
  final List<String> vehicleTypes;
  final bool? reportedAvailable, reserved, disabled, installed, renting;
  final int? availableCount;
  final DateTime? updatedUtc;

  SharedMobilityStatus get reportedStatus {
    if (disabled == true) {
      return SharedMobilityStatus.disabled;
    }
    if (reserved == true) {
      return SharedMobilityStatus.reserved;
    }
    if (pickup == SharedMobilityPickup.stationBased) {
      if (installed == false ||
          renting == false ||
          availableCount == 0 ||
          reportedAvailable == false) {
        return SharedMobilityStatus.unavailable;
      }
      if (availableCount != null &&
          availableCount! > 0 &&
          installed != false &&
          renting != false) {
        return SharedMobilityStatus.available;
      }
    } else if (pickup == SharedMobilityPickup.freeFloating) {
      if (reportedAvailable == false) {
        return SharedMobilityStatus.unavailable;
      }
      if (reportedAvailable == true && disabled == false && reserved == false) {
        return SharedMobilityStatus.available;
      }
    }
    return SharedMobilityStatus.unknown;
  }

  /// No source publication timestamp = no live availability assertion.
  SharedMobilityStatus effectiveStatus(
    DateTime now, {
    required bool refreshFailed,
    required DateTime? feedUpdatedUtc,
    required Duration? maxAge,
  }) {
    if (refreshFailed || maxAge == null || maxAge <= Duration.zero) {
      return SharedMobilityStatus.unknown;
    }
    final published = updatedUtc ?? feedUpdatedUtc;
    if (published == null ||
        published.isAfter(now.toUtc().add(const Duration(minutes: 1))) ||
        now.toUtc().difference(published) > maxAge) {
      return SharedMobilityStatus.unknown;
    }
    return reportedStatus;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'providerId': providerId,
    'providerName': providerName,
    'name': name,
    'operatorUrl': operatorUrl,
    'latitude': latitude,
    'longitude': longitude,
    'pickup': pickup.name,
    'vehicleTypes': vehicleTypes,
    'reportedAvailable': reportedAvailable,
    'reserved': reserved,
    'disabled': disabled,
    'installed': installed,
    'renting': renting,
    'availableCount': availableCount,
    'updatedUtc': updatedUtc?.toIso8601String(),
  };
  factory SharedMobilityOffer.fromJson(Map<String, dynamic> json) =>
      SharedMobilityOffer(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        providerName: json['providerName'] as String,
        name: json['name'] as String?,
        operatorUrl: json['operatorUrl'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        pickup: SharedMobilityPickup.values.byName(json['pickup'] as String),
        vehicleTypes: List<String>.from(json['vehicleTypes'] as List),
        reportedAvailable: json['reportedAvailable'] as bool?,
        reserved: json['reserved'] as bool?,
        disabled: json['disabled'] as bool?,
        installed: json['installed'] as bool?,
        renting: json['renting'] as bool?,
        availableCount: json['availableCount'] as int?,
        updatedUtc: json['updatedUtc'] == null
            ? null
            : DateTime.parse(json['updatedUtc'] as String).toUtc(),
      );
}

class SharedMobilitySnapshot {
  const SharedMobilitySnapshot({
    required this.area,
    required this.fetchedUtc,
    required this.offers,
    required this.truncated,
    this.feedUpdatedUtc,
    this.maxAge,
    this.fromCache = false,
    this.refreshFailed = false,
    this.sourceVersion = 'REST v1',
  });
  final SharedMobilityArea area;
  final DateTime fetchedUtc;

  /// Source publication time, never the HTTP retrieval time.
  final DateTime? feedUpdatedUtc;
  final Duration? maxAge;
  final List<SharedMobilityOffer> offers;
  final bool truncated, fromCache, refreshFailed;
  final String sourceVersion;

  bool get hasProvenFreshness => feedUpdatedUtc != null && maxAge != null;
  bool isOld(DateTime now) =>
      now.toUtc().difference(fetchedUtc) > const Duration(minutes: 5);
  SharedMobilityStatus status(SharedMobilityOffer offer, DateTime now) =>
      offer.effectiveStatus(
        now,
        refreshFailed: refreshFailed,
        feedUpdatedUtc: feedUpdatedUtc,
        maxAge: maxAge,
      );
  SharedMobilitySnapshot cached({bool failed = false}) =>
      SharedMobilitySnapshot(
        area: area,
        fetchedUtc: fetchedUtc,
        offers: offers,
        truncated: truncated,
        feedUpdatedUtc: feedUpdatedUtc,
        maxAge: maxAge,
        fromCache: true,
        refreshFailed: failed,
        sourceVersion: sourceVersion,
      );
  String encode() => jsonEncode({
    'version': 1,
    'area': area.toJson(),
    'fetchedUtc': fetchedUtc.toIso8601String(),
    'feedUpdatedUtc': feedUpdatedUtc?.toIso8601String(),
    'maxAgeSeconds': maxAge?.inSeconds,
    'sourceVersion': sourceVersion,
    'truncated': truncated,
    'offers': offers.map((o) => o.toJson()).toList(),
  });
  factory SharedMobilitySnapshot.decode(String raw) {
    if (raw.length > 650000) {
      throw const FormatException('Shared mobility cache too large.');
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported shared mobility cache.');
    }
    final offers = json['offers'] as List;
    if (offers.length > 200) {
      throw const FormatException('Too many cached offers.');
    }
    return SharedMobilitySnapshot(
      area: SharedMobilityArea.fromJson(
        Map<String, dynamic>.from(json['area'] as Map),
      ),
      fetchedUtc: DateTime.parse(json['fetchedUtc'] as String).toUtc(),
      feedUpdatedUtc: json['feedUpdatedUtc'] == null
          ? null
          : DateTime.parse(json['feedUpdatedUtc'] as String).toUtc(),
      maxAge: json['maxAgeSeconds'] == null
          ? null
          : Duration(seconds: json['maxAgeSeconds'] as int),
      sourceVersion: json['sourceVersion'] as String? ?? 'REST v1',
      truncated: json['truncated'] == true,
      offers: List.unmodifiable(
        offers.map(
          (e) =>
              SharedMobilityOffer.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
    );
  }
}
