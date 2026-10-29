import 'dart:math' as math;

import 'offline_region.dart';

class OfflinePreparationOptions {
  const OfflinePreparationOptions({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.name,
    required this.maps,
    this.wholeSwitzerland = false,
    this.includeTerrain = true,
    this.imageryLevel = 14,
    this.terrainLevel = 14,
    this.budgetGiB = 8,
  });
  final double latitude, longitude, radiusKm;
  final String name;
  final List<String> maps;
  final bool wholeSwitzerland, includeTerrain;
  final int imageryLevel, terrainLevel, budgetGiB;
  OfflineRegion region() {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 45.6 ||
        latitude > 48 ||
        longitude < 5.8 ||
        longitude > 10.7 ||
        !radiusKm.isFinite ||
        radiusKm <= 0 ||
        radiusKm > 25 ||
        maps.isEmpty && !includeTerrain) {
      throw const FormatException(
        'Schweizer Mittelpunkt, Radius bis 25 km und mindestens eine Ebene wählen.',
      );
    }
    final dy = radiusKm / 111.195, dx = dy / math.cos(latitude * math.pi / 180);
    return OfflineRegion(
      id: 'region-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      west: wholeSwitzerland ? 5.95 : math.max(5.8, longitude - dx),
      east: wholeSwitzerland ? 10.5 : math.min(10.7, longitude + dx),
      south: wholeSwitzerland ? 45.8 : math.max(45.6, latitude - dy),
      north: wholeSwitzerland ? 47.85 : math.min(48.0, latitude + dy),
      style: maps.firstOrNull ?? 'relief',
      imageryLevel: imageryLevel,
      terrainLevel: terrainLevel,
      preparationVersion: 2,
      maps: maps,
      includeTerrain: includeTerrain,
      scope: wholeSwitzerland ? 'switzerland' : 'radius',
      radiusKm: radiusKm,
      centerLatitude: latitude,
      centerLongitude: longitude,
    );
  }

  ({int tiles, int bytes}) estimate() {
    final r = region();
    int count(bool terrain) {
      var total = 0;
      for (var z = 0; z <= (terrain ? terrainLevel : imageryLevel); z++) {
        final range = r.range(z, terrain: terrain);
        total +=
            (range.right - range.left + 1) * (range.top - range.bottom + 1);
      }
      return total;
    }

    final terrain = includeTerrain ? count(true) : 0,
        imagery = maps.length * count(false);
    return (
      tiles: terrain + imagery + 1,
      bytes: terrain * offlinePreparedMeshBytes + imagery * 65536,
    );
  }

  Map<String, dynamic> request() => {
    ...region().toJson(),
    'budget': budgetGiB * 1024 * 1024 * 1024,
    'estimatedBytes': estimate().bytes,
  };
}
