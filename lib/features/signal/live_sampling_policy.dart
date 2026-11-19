import 'dart:math' as math;

/// Bound the load independently of renderer FPS. Distance-based sampling keeps
/// narrow terrain obstruction windows visible at higher flying speeds.
class LiveSamplingPolicy {
  static Duration interval(double speedMetersPerSecond) => Duration(
    milliseconds: speedMetersPerSecond >= 30
        ? 250
        : speedMetersPerSecond >= 12
        ? 450
        : 800,
  );
  static double spacing(double distanceMeters) =>
      math.max(8, distanceMeters / 250);
  static double maximumStaleness(double speedMetersPerSecond) =>
      math.max(12, speedMetersPerSecond * 0.6);
}
