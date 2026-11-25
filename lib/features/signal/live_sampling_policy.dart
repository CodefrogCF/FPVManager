import 'dart:math' as math;

import 'radio_analysis.dart';

/// A bounded policy for live terrain profiling. The tiers are performance
/// budgets, not guarantees about the resolution of available Cesium terrain.
class LiveSamplingTier {
  const LiveSamplingTier({
    required this.name,
    required this.coarsePoints,
    required this.refinementPoints,
    required this.coverageGapMeters,
    required this.minimumInterval,
  });

  final String name;
  final int coarsePoints, refinementPoints;
  final double coverageGapMeters;
  final Duration minimumInterval;
}

class LiveSamplingPolicy {
  static const maximumPathMeters = radioMaximumPathMeters;
  // The established route/profile geometry bound. A logical terrain query can
  // carry a complete first pass while Cesium's tile workers remain bounded.
  static const maximumQueryPoints = 4096;

  static LiveSamplingTier forDistance(double distanceMeters) {
    if (!distanceMeters.isFinite ||
        distanceMeters < 0 ||
        distanceMeters > maximumPathMeters) {
      throw ArgumentError.value(distanceMeters, 'distanceMeters');
    }
    if (distanceMeters <= 6000) {
      return const LiveSamplingTier(
        name: 'highResolution',
        // The first 256 points cover short paths. Fast flight fuses the next
        // complete midpoint wave when the 16 m coverage limit requires it,
        // spending this same refinement budget without another round trip.
        coarsePoints: 256,
        refinementPoints: 384,
        coverageGapMeters: 16,
        minimumInterval: Duration(milliseconds: 200),
      );
    }
    if (distanceMeters <= 15000) {
      return const LiveSamplingTier(
        name: 'adaptive',
        coarsePoints: 128,
        refinementPoints: 128,
        coverageGapMeters: 80,
        minimumInterval: Duration(milliseconds: 450),
      );
    }
    if (distanceMeters <= 30000) {
      return const LiveSamplingTier(
        name: 'longRange',
        coarsePoints: 96,
        refinementPoints: 96,
        coverageGapMeters: 165,
        minimumInterval: Duration(milliseconds: 850),
      );
    }
    // Smooth the resource reduction around the 30-km boundary. This avoids
    // a sudden quality drop solely because a profile crossed a tier limit.
    final fraction = ((distanceMeters - 30000) / 20000).clamp(0.0, 1.0);
    return LiveSamplingTier(
      name: 'extendedRange',
      coarsePoints: 96,
      refinementPoints: (96 - 32 * fraction).round(),
      coverageGapMeters: 300,
      minimumInterval: const Duration(milliseconds: 1500),
    );
  }

  static Duration interval(
    double speedMetersPerSecond, [
    double distanceMeters = 0,
  ]) {
    final speedInterval = speedMetersPerSecond >= 30
        ? 200
        : speedMetersPerSecond >= 12
        ? 400
        : 800;
    if (distanceMeters < 1 ||
        !distanceMeters.isFinite ||
        distanceMeters > maximumPathMeters) {
      return Duration(milliseconds: speedInterval);
    }
    return Duration(
      milliseconds: math.max(
        speedInterval,
        forDistance(distanceMeters).minimumInterval.inMilliseconds,
      ),
    );
  }

  /// Only the regular route planner creates candidate positions. Their actual
  /// terrain heights can be sampled much more sparsely, within a fixed budget.
  static double spacing(double distanceMeters) => distanceMeters <= 6000
      // RouteSamplingPlan requires spacing >= 5 m. A finer value would
      // invalidate the entire live profile, leaving even nearby links unknown.
      ? math.max(5.0, math.min(6.0, distanceMeters / 1000))
      : math.min(100.0, math.max(8.0, distanceMeters / 750));

  static double maximumStaleness(
    double speedMetersPerSecond, [
    double? distanceMeters,
  ]) {
    // A 60–70 m/s aircraft can travel tens of metres while terrain is being
    // sampled. Never treat an old, clear near-field ray as verified across a
    // 40 m displacement near a cliff or ridge. Recompute instead. Unknown is
    // preferable to a false clear if the provider cannot keep up.
    if (distanceMeters != null &&
        distanceMeters >= 0 &&
        distanceMeters <= 6000) {
      return math.max(12, math.min(24, speedMetersPerSecond * 0.35));
    }
    return math.max(
      12,
      speedMetersPerSecond *
          math.min(3.5, 0.6 + math.max(0, distanceMeters ?? 0) / 18000),
    );
  }
}
