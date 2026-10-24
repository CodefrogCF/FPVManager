import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
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
    final plan = RadioAnalysisPlan.create(
      route(),
      const SignalSettings(pilot: pilot, antennaHeight: 10),
    );
    final heights = List.filled(plan.positions.length, 500.0);
    expect(
      plan
          .calculate(heights)
          .every((p) => p.state == RadioPathState.noSampledObstruction),
      isTrue,
    );
    final ridge = List.of(heights)
      ..[plan.paths.last[plan.paths.last.length ~/ 2]] = 1000;
    expect(plan.calculate(ridge).last.state, RadioPathState.obstructed);
    expect(plan.calculate(ridge).last.minimumClearance, lessThan(0));
    expect(() => plan.calculate(heights.sublist(1)), throwsArgumentError);
    final unknown = RadioAnalysisPlan.create(
      route(
        height: const AbsoluteWaypointHeight(
          ReferencedElevation(meters: 550, reference: VerticalReference.ln02),
        ),
      ),
      const SignalSettings(pilot: pilot),
    );
    expect(
      unknown
          .calculate(List.filled(unknown.positions.length, 500.0))
          .every((p) => p.state == RadioPathState.unknown),
      isTrue,
    );
    final missing = RadioAnalysisPlan.create(
      route(height: null),
      const SignalSettings(pilot: pilot),
    );
    expect(
      missing
          .calculate(List.filled(missing.positions.length, 500.0))
          .first
          .altitude,
      isNull,
    );
  });
  test('geometric LOS and Fresnel intrusion are separate results', () {
    const low = AglWaypointHeight(AboveGroundHeight(2));
    final plan = RadioAnalysisPlan.create(
      route(height: low),
      const SignalSettings(pilot: pilot, antennaHeight: 2, frequencyMhz: 100),
    );
    final result = plan
        .calculate(List.filled(plan.positions.length, 500.0))
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
    final plan = RadioAnalysisPlan.create(
      points,
      const SignalSettings(
        pilot: Wgs84Coordinate(latitude: 0, longitude: 0),
        antennaHeight: 20,
      ),
    );
    expect(
      plan.calculate(List.filled(plan.positions.length, 0.0)).last.state,
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
    RadioAnalysisPlan plan(bool enabled) => RadioAnalysisPlan.create(
      route(),
      SignalSettings(
        pilot: pilot,
        antennaHeight: 10,
        surfaces: surfaces,
        useSurfaces: enabled,
      ),
    );
    final included = plan(true), excluded = plan(false);
    expect(
      included
          .calculate(List.filled(included.positions.length, 500.0))
          .last
          .state,
      RadioPathState.obstructed,
    );
    expect(
      excluded
          .calculate(List.filled(excluded.positions.length, 500.0))
          .last
          .state,
      RadioPathState.noSampledObstruction,
    );
    final settings = const RoutePlanningSettings().withSignal(
      included.settings,
    );
    expect(
      RoutePlanningSettings.decode(settings.encode())
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
  test('limits reject unbounded target and sample work', () {
    expect(
      () => RadioAnalysisPlan.create([
        const RouteWaypointInput(position: pilot),
        const RouteWaypointInput(
          position: Wgs84Coordinate(latitude: 47, longitude: 9),
        ),
      ], const SignalSettings(pilot: pilot)),
      throwsArgumentError,
    );
    expect(
      () => SignalSettings(pilot: pilot, frequencyMhz: double.nan).validate(),
      throwsArgumentError,
    );
  });
}
