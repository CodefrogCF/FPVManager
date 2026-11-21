import 'dart:math' as math;

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
import '../../core/models/signal_settings.dart';
import '../routes/analysis/route_analysis.dart';
import 'live_sampling_policy.dart';
import 'radio_analysis.dart';

/// Diagnostics for the live profile, not a guarantee of terrain completeness.
class LiveTerrainSampleResult {
  const LiveTerrainSampleResult({
    required this.path,
    required this.coarseCount,
    required this.refinedCount,
    required this.queryCount,
    required this.maximumGapMeters,
    required this.coverageLimited,
    required this.tier,
  });
  final RadioPathResult path;
  final int coarseCount, refinedCount, queryCount;
  final double maximumGapMeters;
  final bool coverageLimited;
  final LiveSamplingTier tier;
  int get sampleCount => coarseCount + refinedCount;
}

/// Reuses the route radio kernel and route point interpolation. All terrain
/// calls are sequential and bounded to at most 256 points per request.
/// A sparse *clear* profile must remain explicitly uncertain.
class LiveTerrainSampler {
  const LiveTerrainSampler._();

  static Future<LiveTerrainSampleResult> calculate({
    required SignalSettings signal,
    required Wgs84Coordinate target,
    required double targetHeight,
    required double distanceMeters,
    required LiveSamplingTier tier,
    required Future<List<double>> Function(List<Wgs84Coordinate>) sample,
    required bool Function() valid,
  }) async {
    if (tier.coarsePoints < 2 ||
        tier.coarsePoints > 256 ||
        tier.refinementPoints < 0 ||
        tier.refinementPoints > 768 ||
        !tier.coverageGapMeters.isFinite ||
        tier.coverageGapMeters <= 0) {
      throw ArgumentError('Invalid live sampling budget');
    }
    final plan = RouteSamplingPlan.create([
      RouteWaypointInput(position: signal.pilot),
      RouteWaypointInput(position: target),
    ], spacing: LiveSamplingPolicy.spacing(distanceMeters));
    final all = plan.samples;
    final count = all.length;
    final indices = <int>{};
    final coarseCount = math.min(count, tier.coarsePoints);
    for (var i = 0; i < coarseCount; ++i) {
      indices.add((i * (count - 1) / (coarseCount - 1)).round());
    }
    final data = <int, double>{};
    var requests = 0;

    Future<void> fetch(List<int> positions) async {
      if (!valid()) {
        return;
      }
      for (var offset = 0; offset < positions.length; offset += 256) {
        final batch = positions.skip(offset).take(256).toList();
        final heights = await sample([
          for (final index in batch) all[index].position,
        ]);
        ++requests;
        if (!valid()) {
          return;
        }
        if (heights.length != batch.length ||
            heights.any((h) => !h.isFinite || h.abs() > 100000)) {
          throw const FormatException('Incomplete live terrain profile');
        }
        for (var i = 0; i < batch.length; ++i) {
          data[batch[i]] = heights[i];
        }
      }
    }

    RadioPathResult evaluate() {
      final sorted = data.keys.toList()..sort();
      return calculateRadioLink(
        settings: signal,
        target: target,
        altitude: targetHeight,
        pilotHeight: data[0]! + signal.antennaHeight,
        positions: [for (final i in sorted) all[i].position],
        heights: [for (final i in sorted) data[i]!],
      );
    }

    await fetch(indices.toList()..sort());
    if (!valid()) {
      throw const FormatException('Stale live terrain request');
    }
    // Adaptive midpoint refinement in bounded rounds. Re-rank after each
    // sampled batch: a newly discovered narrow ridge must influence the next
    // selection. Each gap contributes at most one midpoint per round so a
    // single rugged region cannot starve coverage everywhere else.
    var refined = 0;
    while (refined < tier.refinementPoints &&
        indices.length + refined < count) {
      final sorted = data.keys.toList()..sort();
      final profile = evaluate().profile;
      final candidates = <(int, double)>[];
      for (var i = 1; i < sorted.length; ++i) {
        final left = sorted[i - 1], right = sorted[i];
        if (right - left <= 1) continue;
        final a = profile[i - 1], b = profile[i];
        final leftMargin = a.clearance - signal.clearanceFraction * a.radius;
        final rightMargin = b.clearance - signal.clearanceFraction * b.radius;
        final rise = (a.surface - b.surface).abs();
        final gap = distanceMeters * (all[right].fraction - all[left].fraction);
        final nearRay = math.max(
          0,
          140 - math.min(leftMargin.abs(), rightMargin.abs()),
        );
        final crossing = (leftMargin <= 0) != (rightMargin <= 0);
        final priority =
            gap / tier.coverageGapMeters +
            math.min(rise, 500) / 8 +
            nearRay / 7 +
            (crossing ? 30 : 0);
        candidates.add(((left + right) ~/ 2, priority));
      }
      if (candidates.isEmpty) break;
      candidates.sort((a, b) {
        final score = b.$2.compareTo(a.$2);
        return score != 0 ? score : a.$1.compareTo(b.$1);
      });
      final remaining = tier.refinementPoints - refined;
      // Stop at a batch boundary, then use the new elevation information to
      // reprioritize further splits. Hard cap: 256 samples per bridge query.
      final selected = <int>[];
      for (final c in candidates) {
        if (selected.length >= math.min(remaining, 256)) break;
        if (!data.containsKey(c.$1)) selected.add(c.$1);
      }
      if (selected.isEmpty) break;
      selected.sort();
      await fetch(selected);
      if (!valid()) {
        throw const FormatException('Stale live terrain request');
      }
      refined += selected.length;
    }
    final ordered = data.keys.toList()..sort();
    var maxGap = 0.0;
    for (var i = 1; i < ordered.length; ++i) {
      maxGap = math.max(
        maxGap,
        distanceMeters *
            (all[ordered[i]].fraction - all[ordered[i - 1]].fraction),
      );
    }
    return LiveTerrainSampleResult(
      path: evaluate(),
      coarseCount: indices.length,
      refinedCount: refined,
      queryCount: requests,
      maximumGapMeters: maxGap,
      coverageLimited: maxGap > tier.coverageGapMeters,
      tier: tier,
    );
  }
}
