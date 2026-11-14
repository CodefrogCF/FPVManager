import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';
import 'package:fpvmanager/features/signal/surface_csv.dart';

const pilot = Wgs84Coordinate(latitude: 47, longitude: 8);
List<RouteWaypointInput> route({
  WaypointHeight? height = const AglWaypointHeight(AboveGroundHeight(50)),
}) => [
  for (final lon in [8.005, 8.006])
    RouteWaypointInput(
      position: Wgs84Coordinate(latitude: 47, longitude: lon),
      height: height,
    ),
];

RadioAnalysisBatch batch(
  List<RouteWaypointInput> points,
  SignalSettings settings, {
  double ground = 500,
}) {
  final plan = RouteSamplingPlan.create(points, spacing: 100);
  final profile = RouteAnalysis.calculate(
    points,
    plan,
    List.filled(plan.samples.length, ground),
    const RoutePlanningSettings(),
  ).profile;
  return RadioAnalysisBatch.forRoute(profile, settings).single;
}

void main() {
  test('Fresnel SI formula and frequency scaling', () {
    expect(fresnelRadius(5800, 500, 500), closeTo(3.5947335, .0001));
    expect(
      fresnelRadius(1450, 500, 500),
      closeTo(2 * fresnelRadius(5800, 500, 500), 1e-10),
    );
    expect(fresnelRadius(5800, 0, 100), 0);
    expect(() => fresnelRadius(0, 1, 1), throwsArgumentError);
  });
  test('flat terrain, ridge, missing datum and complete profiles', () {
    const settings = SignalSettings(pilot: pilot, antennaHeight: 10);
    final plan = batch(route(), settings);
    final heights = List.filled(plan.positions.length, 500.0);
    expect(
      plan
          .calculate(settings, 500, heights)
          .every((p) => p.state == RadioPathState.noSampledObstruction),
      isTrue,
    );
    final midpoint =
        (plan.offsets[plan.targets.length - 1] + plan.offsets.last) ~/ 2;
    final ridge = List.of(heights)..[midpoint] = 1000;
    final obstructed = plan
        .calculate(settings, 500, ridge, includeProfiles: true)
        .last;
    expect(obstructed.state, RadioPathState.obstructed);
    expect(obstructed.minimumClearance, lessThan(0));
    expect(obstructed.profile, isNotEmpty);
    expect(
      () => plan.calculate(settings, 500, heights.sublist(1)),
      throwsArgumentError,
    );
    final unknown = batch(
      route(
        height: const AbsoluteWaypointHeight(
          ReferencedElevation(meters: 550, reference: VerticalReference.ln02),
        ),
      ),
      settings,
    );
    expect(
      unknown
          .calculate(settings, 500, [])
          .every((p) => p.state == RadioPathState.unknown),
      isTrue,
    );
    final missing = batch(route(height: null), settings);
    expect(missing.calculate(settings, 500, []).first.altitude, isNull);
  });
  test('geometric LOS and Fresnel intrusion are separate results', () {
    const low = AglWaypointHeight(AboveGroundHeight(2));
    const settings = SignalSettings(
      pilot: pilot,
      antennaHeight: 2,
      frequencyMhz: 100,
    );
    final plan = batch(route(height: low), settings);
    final result = plan
        .calculate(settings, 500, List.filled(plan.positions.length, 500.0))
        .last;
    expect(result.minimumClearance, greaterThan(0));
    expect(result.state, RadioPathState.fresnelIntrusion);
  });
  test('ECEF sight line accounts for Earth curvature', () {
    final points = [
      for (final lon in [.44, .4401])
        RouteWaypointInput(
          position: Wgs84Coordinate(latitude: 0, longitude: lon),
          height: const AglWaypointHeight(AboveGroundHeight(20)),
        ),
    ];
    const settings = SignalSettings(
      pilot: Wgs84Coordinate(latitude: 0, longitude: 0),
      antennaHeight: 20,
    );
    final plan = batch(points, settings, ground: 0);
    expect(
      plan
          .calculate(settings, 0, List.filled(plan.positions.length, 0.0))
          .last
          .state,
      RadioPathState.obstructed,
    );
  });
  test('local vegetation observations are optional and preserve source', () {
    final surfaces = decodeSurfaceCsv(
      Uint8List.fromList(
        utf8.encode(
          'latitude,longitude,height_m_agl,radius_m,kind,source\n47,8.003,100,80,vegetation,Site survey 2026-10-24\n',
        ),
      ),
    );
    SignalSettings settings(bool enabled) => SignalSettings(
      pilot: pilot,
      antennaHeight: 10,
      surfaces: surfaces,
      useSurfaces: enabled,
    );
    RadioPathState state(bool enabled) {
      final config = settings(enabled), plan = batch(route(), config);
      return plan
          .calculate(config, 500, List.filled(plan.positions.length, 500.0))
          .last
          .state;
    }

    expect(state(true), RadioPathState.obstructed);
    expect(state(false), RadioPathState.noSampledObstruction);
    final planning = const RoutePlanningSettings().withSignal(settings(true));
    expect(
      RoutePlanningSettings.decode(planning.encode())
          .signal!
          .surfaces
          .single
          .source,
      'Site survey 2026-10-24',
    );
    expect(
      () => decodeSurfaceCsv(
        Uint8List.fromList(
          utf8.encode(
            'latitude,longitude,height_m_agl,radius_m,kind,source\n47,8,10,50,tree,\n',
          ),
        ),
      ),
      throwsArgumentError,
    );
  });
  test(
    'batch budget preserves target order and distant paths remain unknown',
    () {
      const settings = SignalSettings(pilot: pilot);
      final points = [
        for (var i = 0; i < 300; ++i)
          RouteWaypointInput(
            position: Wgs84Coordinate(
              latitude: 47,
              longitude: 8.15 + i * .00001,
            ),
            height: const AglWaypointHeight(AboveGroundHeight(30)),
          ),
      ];
      final plan = RouteSamplingPlan.create(points, spacing: 100);
      final profile = RouteAnalysis.calculate(
        points,
        plan,
        List.filled(plan.samples.length, 500),
        const RoutePlanningSettings(),
      ).profile;
      final batches = RadioAnalysisBatch.forRoute(profile, settings).toList();
      expect(batches.length, greaterThan(3));
      expect(batches.expand((b) => b.targets), profile);
      expect(
        batches.every(
          (b) => b.positions.length <= 16384 && b.targets.length <= 128,
        ),
        isTrue,
      );
      final distant = profile
          .map(
            (p) => RouteProfilePoint(
              RouteSample(
                const Wgs84Coordinate(latitude: 47, longitude: 9),
                p.sample.segment,
                1,
                0,
              ),
              p.ground,
              p.altitude,
            ),
          )
          .take(1)
          .toList();
      final only = RadioAnalysisBatch.forRoute(distant, settings).single;
      expect(only.positions, isEmpty);
      expect(
        only.calculate(settings, 500, []).single.state,
        RadioPathState.unknown,
      );
      expect(
        () => SignalSettings(pilot: pilot, frequencyMhz: double.nan).validate(),
        throwsArgumentError,
      );
    },
  );
}
