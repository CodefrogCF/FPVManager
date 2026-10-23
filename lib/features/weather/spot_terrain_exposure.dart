import 'dart:math' as math;

import '../globe/globe_controller.dart';

class SpotTerrainExposure {
  const SpotTerrainExposure({
    required this.localReliefMeters,
    required this.sampleRadiusMeters,
    required this.samples,
  });
  final double localReliefMeters, sampleRadiusMeters;
  final int samples;
  String get warning => localReliefMeters >= 100
      ? 'Strong local elevation differences; ridge effects, rotors and gusts may be pronounced. No turbulence prediction.'
      : localReliefMeters >= 35
      ? 'Complex surrounding relief; funneling, downdrafts and turbulence may differ substantially from forecasts.'
      : 'Limited sampled relief; buildings, trees, thermals and local turbulence are still unmodelled.';
}

/// Uses the same Cesium terrain reference for every sample; terrain availability
/// is required. This does NOT derive rotor strength or forecast wind at AGL.
Future<SpotTerrainExposure> inspectSpotTerrain(
  GlobeController globe,
  double latitude,
  double longitude, {
  double radiusMeters = 300,
  bool Function()? isCancelled,
}) async {
  final latDelta = radiusMeters / 111320;
  final lonDelta = radiusMeters / (111320 * math.cos(latitude * math.pi / 180));
  final points = [
    (latitude, longitude),
    (latitude + latDelta, longitude),
    (latitude - latDelta, longitude),
    (latitude, longitude + lonDelta),
    (latitude, longitude - lonDelta),
  ];
  final heights = <double>[];
  for (final point in points) {
    if (isCancelled?.call() ?? false) {
      throw StateError('Terrain inspection cancelled');
    }
    final elevation = await globe.queryTerrainElevation(
      latitude: point.$1,
      longitude: point.$2,
    );
    heights.add(elevation.heightMeters);
  }
  return SpotTerrainExposure(
    localReliefMeters: heights.reduce(math.max) - heights.reduce(math.min),
    sampleRadiusMeters: radiusMeters,
    samples: heights.length,
  );
}
