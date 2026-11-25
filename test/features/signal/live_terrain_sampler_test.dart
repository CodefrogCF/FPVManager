import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/signal/live_sampling_policy.dart';
import 'package:fpvmanager/features/signal/live_terrain_sampler.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';

const station = Wgs84Coordinate(latitude: 47, longitude: 8);

void main() {
  test('distance tiers cover both sides of 6 km and cap analysis at 50 km', () {
    expect(LiveSamplingPolicy.forDistance(5999).name, 'highResolution');
    expect(LiveSamplingPolicy.forDistance(6001).name, 'adaptive');
    expect(LiveSamplingPolicy.forDistance(10000).name, 'adaptive');
    expect(LiveSamplingPolicy.forDistance(20000).name, 'longRange');
    expect(LiveSamplingPolicy.forDistance(30000).name, 'longRange');
    expect(LiveSamplingPolicy.forDistance(49999).name, 'extendedRange');
    expect(() => LiveSamplingPolicy.forDistance(50001), throwsArgumentError);
    expect(LiveSamplingPolicy.interval(60, 49000).inMilliseconds, 1500);
    expect(
      LiveSamplingPolicy.maximumStaleness(70, 900),
      24,
      reason: 'do not carry a clear near-field ray over 40 m at high speed',
    );
    expect(LiveSamplingPolicy.maximumStaleness(70, 49000), greaterThan(24));
  });

  for (final distance in [5900, 6100, 10000, 20000, 30000, 49900]) {
    test(
      '$distance m live terrain uses bounded, sequential sampling',
      () async {
        final target = Wgs84Coordinate(
          latitude: 47 + distance / 111195,
          longitude: 8,
        );
        final actual = routeDistance(station, target);
        final tier = LiveSamplingPolicy.forDistance(actual);
        var calls = 0, maxRequest = 0, total = 0, busy = false;
        final result = await LiveTerrainSampler.calculate(
          signal: const SignalSettings(pilot: station, antennaHeight: 2),
          target: target,
          targetHeight: 1200,
          distanceMeters: actual,
          tier: tier,
          valid: () => true,
          sample: (positions) async {
            expect(busy, false);
            busy = true;
            calls++;
            total += positions.length;
            if (positions.length > maxRequest) maxRequest = positions.length;
            await Future<void>.delayed(Duration.zero);
            busy = false;
            return List.filled(positions.length, 500);
          },
        );
        expect(maxRequest, lessThanOrEqualTo(256));
        expect(result.sampleCount, total);
        expect(result.queryCount, calls);
        expect(result.maximumGapMeters, greaterThan(0));
        expect(result.path.profile, hasLength(total));
        expect(result.path.state, isNot(RadioPathState.unknown));
        if (distance > 40000) {
          expect(result.coverageLimited, true);
        }
      },
    );
  }

  test(
    'abandoned moving-ray refinement cannot claim a verified clear path',
    () async {
      const preciseTier = LiveSamplingTier(
        name: 'highResolution',
        coarsePoints: 96,
        refinementPoints: 384,
        coverageGapMeters: 5.5,
        minimumInterval: Duration(milliseconds: 250),
      );
      final target = const Wgs84Coordinate(latitude: 47.010, longitude: 8);
      final distance = routeDistance(station, target);
      var queries = 0;
      final partial = await LiveTerrainSampler.calculate(
        signal: const SignalSettings(pilot: station),
        target: target,
        targetHeight: 1100,
        distanceMeters: distance,
        tier: preciseTier,
        valid: () => true,
        shouldRefine: () => false,
        sample: (positions) async {
          ++queries;
          return List.filled(positions.length, 500.0);
        },
      );
      expect(queries, 1);
      expect(partial.queryCount, 1);
      expect(partial.coverageLimited, true);
      expect(
        partial.maximumGapMeters,
        greaterThan(preciseTier.coverageGapMeters),
      );
      expect(partial.path.state, RadioPathState.noSampledObstruction);
    },
  );

  test(
    'fast coarse obstruction remains evidence despite cancelled refinement',
    () async {
      const tier = LiveSamplingTier(
        name: 'highResolution',
        coarsePoints: 96,
        refinementPoints: 384,
        coverageGapMeters: 5.5,
        minimumInterval: Duration(milliseconds: 250),
      );
      final target = const Wgs84Coordinate(latitude: 47.010, longitude: 8);
      final distance = routeDistance(station, target);
      var calls = 0;
      final blocked = await LiveTerrainSampler.calculate(
        signal: const SignalSettings(pilot: station, antennaHeight: 2),
        target: target,
        targetHeight: 550,
        distanceMeters: distance,
        tier: tier,
        valid: () => true,
        shouldRefine: () => false,
        sample: (positions) async {
          ++calls;
          final heights = List.filled(positions.length, 500.0);
          heights[positions.length ~/ 2] = 800.0;
          return heights;
        },
      );
      expect(calls, 1);
      expect(blocked.path.state, RadioPathState.obstructed);
      expect(blocked.path.minimumClearance, lessThan(-8));
    },
  );

  test('dense short clear path finishes in one terrain query instead of exhausting budget', () async {
    final target = const Wgs84Coordinate(latitude: 47.009, longitude: 8);
    final distance = routeDistance(station, target);
    var calls = 0;
    final terrain = await LiveTerrainSampler.calculate(
      signal: const SignalSettings(pilot: station),
      target: target,
      targetHeight: 1100,
      distanceMeters: distance,
      tier: LiveSamplingPolicy.forDistance(distance),
      valid: () => true,
      sample: (positions) async {
        ++calls;
        return List.filled(positions.length, 500.0);
      },
    );
    expect(terrain.path.state, RadioPathState.noSampledObstruction);
    expect(terrain.coverageLimited, false);
    expect(terrain.maximumGapMeters, lessThanOrEqualTo(16));
    expect(terrain.queryCount, 1);
    expect(terrain.refinedCount, 0);
    expect(calls, 1);
  });

  test('up to 1 km samples the complete 5 m grid at highest terrain detail in one query', () async {
    final target = const Wgs84Coordinate(latitude: 47.008, longitude: 8);
    final distance = routeDistance(station, target);
    var queries = 0;
    var largestBatch = 0;
    final result = await LiveTerrainSampler.calculate(
      signal: const SignalSettings(pilot: station, antennaHeight: 2),
      target: target,
      targetHeight: 1200,
      distanceMeters: distance,
      tier: LiveSamplingPolicy.forDistance(distance),
      valid: () => true,
      sample: (positions) async {
        ++queries;
        largestBatch = positions.length;
        return List.filled(positions.length, 500.0);
      },
    );
    expect(queries, 1);
    expect(largestBatch, lessThanOrEqualTo(256));
    expect(result.maximumGapMeters, lessThanOrEqualTo(5.1));
    expect(result.coverageLimited, false);
    expect(result.path.state, RadioPathState.noSampledObstruction);
  });

  test('5 km high-resolution terrain needs no more than two sequential queries on a clear line', () async {
    final target = const Wgs84Coordinate(latitude: 47.045, longitude: 8);
    final distance = routeDistance(station, target);
    var queries = 0;
    final result = await LiveTerrainSampler.calculate(
      signal: const SignalSettings(pilot: station, antennaHeight: 2),
      target: target,
      targetHeight: 1400,
      distanceMeters: distance,
      tier: LiveSamplingPolicy.forDistance(distance),
      valid: () => true,
      sample: (positions) async {
        expect(positions.length, lessThanOrEqualTo(256));
        ++queries;
        return List.filled(positions.length, 500.0);
      },
    );
    expect(
      queries,
      2,
      reason: '256 initial exact-height samples plus one bounded fill pass',
    );
    expect(result.maximumGapMeters, lessThanOrEqualTo(16));
    expect(result.coverageLimited, false);
    expect(result.path.state, RadioPathState.noSampledObstruction);
  });

  test('a sharp 5 km mountain ridge between the first samples is detected on refinement', () async {
    final target = const Wgs84Coordinate(latitude: 47.045, longitude: 8);
    final distance = routeDistance(station, target);
    var queries = 0;
    double? ridgeLatitude;
    final result = await LiveTerrainSampler.calculate(
      signal: const SignalSettings(pilot: station, antennaHeight: 2),
      target: target,
      targetHeight: 1100,
      distanceMeters: distance,
      tier: LiveSamplingPolicy.forDistance(distance),
      valid: () => true,
      sample: (positions) async {
        ++queries;
        if (ridgeLatitude == null) {
          final middle = positions.length ~/ 2;
          ridgeLatitude =
              (positions[middle - 1].latitude + positions[middle].latitude) / 2;
        }
        return [
          for (final position in positions)
            (position.latitude - ridgeLatitude!).abs() < 0.00003
                ? 1250.0
                : 500.0,
        ];
      },
    );
    expect(queries, 2);
    expect(
      result.path.state,
      RadioPathState.obstructed,
      reason: 'no provisional clear state may skip the precision pass',
    );
    expect(result.path.minimumClearance, lessThan(0));
  });

  test(
    'a coarse sampled ridge reports obstruction without redundant refinement',
    () async {
      const distance = 12000.0;
      final target = Wgs84Coordinate(
        latitude: 47 + distance / 111195,
        longitude: 8,
      );
      final actual = routeDistance(station, target);
      final terrain = await LiveTerrainSampler.calculate(
        signal: const SignalSettings(pilot: station, antennaHeight: 2),
        target: target,
        targetHeight: 800,
        distanceMeters: actual,
        tier: LiveSamplingPolicy.forDistance(actual),
        valid: () => true,
        sample: (locations) async => [
          for (final p in locations)
            (p.latitude > 47.052 && p.latitude < 47.057) ? 1000.0 : 500.0,
        ],
      );
      expect(
        terrain.refinedCount,
        0,
        reason: 'A verified obstruction needs no extra terrain round',
      );
      expect(terrain.queryCount, 1);
      expect(terrain.path.state, RadioPathState.obstructed);
      expect(terrain.path.minimumClearance, lessThan(0));
    },
  );

  test(
    'a narrow ridge missed by the coarse pass is detected on refinement',
    () async {
      const distance = 12000.0;
      final target = Wgs84Coordinate(
        latitude: 47 + distance / 111195,
        longitude: 8,
      );
      final actual = routeDistance(station, target);
      var calls = 0;
      final result = await LiveTerrainSampler.calculate(
        signal: const SignalSettings(pilot: station, antennaHeight: 2),
        target: target,
        targetHeight: 800,
        distanceMeters: actual,
        tier: LiveSamplingPolicy.forDistance(actual),
        valid: () => true,
        sample: (positions) async {
          ++calls;
          return [
            for (var i = 0; i < positions.length; ++i)
              calls == 2 && i == positions.length ~/ 2 ? 1100.0 : 500.0,
          ];
        },
      );
      // Refinement is adaptive: a third bounded pass can follow the ridge
      // discovered in the second pass, rather than stopping after two calls.
      expect(calls, greaterThanOrEqualTo(2));
      expect(calls, result.queryCount);
      expect(result.refinedCount, greaterThan(0));
      expect(result.path.state, RadioPathState.obstructed);
    },
  );

  test('cancelled terrain cannot publish a late result', () async {
    final target = const Wgs84Coordinate(latitude: 47.09, longitude: 8);
    final distance = routeDistance(station, target);
    var valid = true;
    await expectLater(
      LiveTerrainSampler.calculate(
        signal: const SignalSettings(pilot: station),
        target: target,
        targetHeight: 800,
        distanceMeters: distance,
        tier: LiveSamplingPolicy.forDistance(distance),
        valid: () => valid,
        sample: (points) async {
          valid = false;
          return List.filled(points.length, 500);
        },
      ),
      throwsFormatException,
    );
  });
  for (final distance in [1000.0, 3000.0, 5000.0, 5990.0]) {
    test(
      'fused fast first pass preserves terrain precision at $distance m',
      () async {
        final target = Wgs84Coordinate(
          latitude: 47 + distance / 111195,
          longitude: 8,
        );
        final actual = routeDistance(station, target),
            tier = LiveSamplingPolicy.forDistance(
              routeDistance(station, target),
            );
        Future<LiveTerrainSampleResult> run(bool fused) =>
            LiveTerrainSampler.calculate(
              signal: const SignalSettings(pilot: station, antennaHeight: 2),
              target: target,
              targetHeight: 1400,
              distanceMeters: actual,
              tier: tier,
              valid: () => true,
              completeFirstPass: fused,
              sample: (points) async => points
                  .map(
                    (p) =>
                        500.0 + 30 * (p.latitude - 47) / (target.latitude - 47),
                  )
                  .toList(),
            );
        final adaptive = await run(false), fused = await run(true);
        expect(fused.queryCount, 1);
        expect(fused.coverageLimited, false);
        expect(
          fused.maximumGapMeters,
          lessThanOrEqualTo(tier.coverageGapMeters),
        );
        expect(
          fused.sampleCount,
          lessThanOrEqualTo(tier.coarsePoints + tier.refinementPoints),
        );
        expect(fused.path.state, adaptive.path.state);
        expect(
          fused.path.minimumClearance,
          closeTo(adaptive.path.minimumClearance!, 1e-9),
        );
        expect(
          fused.path.profile.map((p) => p.ground),
          adaptive.path.profile.map((p) => p.ground),
        );
        if (distance >= 5000) {
          expect(adaptive.queryCount, greaterThan(fused.queryCount));
        } else {
          expect(fused.sampleCount, lessThanOrEqualTo(256));
        }
      },
    );
  }
  test('fused pass never invents clear coverage when an explicit budget cannot meet the gap limit', () async {
    const target = Wgs84Coordinate(latitude: 47.054, longitude: 8);
    const tier = LiveSamplingTier(
      name: 'limited',
      coarsePoints: 96,
      refinementPoints: 384,
      coverageGapMeters: 16,
      minimumInterval: Duration(milliseconds: 250),
    );
    final result = await LiveTerrainSampler.calculate(
      signal: const SignalSettings(pilot: station),
      target: target,
      targetHeight: 1400,
      distanceMeters: routeDistance(station, target),
      tier: tier,
      valid: () => true,
      completeFirstPass: true,
      sample: (p) async => List.filled(p.length, 500.0),
    );
    expect(result.sampleCount, lessThanOrEqualTo(480));
    expect(result.coverageLimited, true);
  });
  test('a partial far-range refinement budget preserves measured priority near the remote endpoint', () async {
    final target = Wgs84Coordinate(latitude: 47 + 49900 / 111195, longitude: 8);
    final distance = routeDistance(station, target);
    // Isolate a partial wave: four coarse points but only one refinement.
    // Only the remote gap has the largest measured relief, so it must win
    // over an unmeasured station-first midpoint at one sixth of the path.
    const tier = LiveSamplingTier(
      name: 'priority-stress',
      coarsePoints: 4,
      refinementPoints: 1,
      coverageGapMeters: 300,
      minimumInterval: Duration(milliseconds: 1500),
    );
    double terrain(Wgs84Coordinate p) {
      final t = routeDistance(station, p) / distance;
      if ((t - 5 / 6).abs() < .01) return 1600;
      if (t > .99) return 1000;
      if ((t - 2 / 3).abs() < .02) return 700;
      return 500;
    }

    Future<LiveTerrainSampleResult> run(bool fused) =>
        LiveTerrainSampler.calculate(
          signal: const SignalSettings(pilot: station),
          target: target,
          targetHeight: 1200,
          distanceMeters: distance,
          tier: tier,
          valid: () => true,
          completeFirstPass: fused,
          sample: (p) async => p.map(terrain).toList(),
        );
    final adaptive = await run(false), fused = await run(true);
    expect(adaptive.path.state, RadioPathState.obstructed);
    expect(fused.path.state, adaptive.path.state);
    expect(
      fused.path.profile.map((p) => p.ground),
      adaptive.path.profile.map((p) => p.ground),
    );
    expect(fused.sampleCount, adaptive.sampleCount);
    expect(fused.queryCount, adaptive.queryCount);
  });
}
