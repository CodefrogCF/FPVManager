import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/recorded_route_track.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/simulation/route_playback.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

const first = Wgs84Coordinate(latitude: 46.7, longitude: 8.4);
const last = Wgs84Coordinate(latitude: 46.71, longitude: 8.42);
const relative = AglWaypointHeight(AboveGroundHeight(40));
const absolute = AbsoluteWaypointHeight(
  ReferencedElevation(
    meters: 1100,
    reference: VerticalReference.wgs84Ellipsoid,
  ),
);

void main() {
  test(
    'planned replay preserves height reference, positions, and speed',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final id = await repository.saveRoute(
        name: 'Alpine FPV ridge',
        waypoints: const [
          RouteWaypointInput(
            position: first,
            height: relative,
            speedMetersPerSecond: 12,
          ),
          RouteWaypointInput(position: last, height: absolute),
        ],
      );
      final request = RoutePlaybackRequest(
        (await repository.getRoute(id))!,
        const SimulationSettings(cameraFovDegrees: 115),
      ).command;
      expect(request['type'], 'start-route-playback');
      final points = request['points'] as List;
      expect(points.length, 2);
      expect(points.first['heightMode'], 'agl');
      expect(points.first['heightMeters'], 40);
      expect(points.first['speedMetersPerSecond'], 12);
      expect(points.last['heightMode'], 'absolute');
      expect(points.last['heightMeters'], 1100);
      expect(request.containsKey('recorded'), isFalse);
      expect((request['settings'] as Map)['cameraFovDegrees'], 115);
    },
  );

  test(
    'recorded replay retains UTC-derived elapsed seconds and missing AGL',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final points = const [
        RouteWaypointInput(position: first, height: absolute),
        RouteWaypointInput(position: last, height: absolute),
      ];
      final track = RecordedRouteTrack(
        id: 'recording-109',
        startedAtUtc: DateTime.utc(2026, 11, 4),
        waypointSignature: recordedInputSignature(points),
        samples: const [
          RecordedTrackSample(
            seconds: 0,
            absoluteElevationMeters: 1080,
            groundSpeedMetersPerSecond: 3,
          ),
          RecordedTrackSample(
            seconds: 3.5,
            absoluteElevationMeters: 1100,
            terrainElevationMeters: 1000,
            groundSpeedMetersPerSecond: 15,
          ),
        ],
      );
      final id = await repository.saveRoute(
        name: 'Recorded ridge',
        planning: const RoutePlanningSettings().withRecordedTrack(track),
        waypoints: points,
      );
      final payload = RoutePlaybackRequest(
        (await repository.getRoute(id))!,
        const SimulationSettings(),
      ).command;
      final samples = payload['recorded'] as List;
      expect(samples.length, 2);
      expect(samples.first['seconds'], 0);
      expect(samples.last['seconds'], 3.5);
      expect(samples.first['groundSpeedMetersPerSecond'], 3);
      expect(samples.last['groundSpeedMetersPerSecond'], 15);
      expect(samples.first.containsKey('terrainElevationMeters'), isFalse);
      expect(samples.last['terrainElevationMeters'], 1000);
    },
  );

  test(
    'non-WGS84 heights are not silently treated as ellipsoid heights',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final id = await repository.saveRoute(
        name: 'Unsupported datum',
        waypoints: const [
          RouteWaypointInput(
            position: first,
            height: AbsoluteWaypointHeight(
              ReferencedElevation(
                meters: 500,
                reference: VerticalReference.ln02,
              ),
            ),
          ),
          RouteWaypointInput(position: last, height: absolute),
        ],
      );
      final route = (await repository.getRoute(id))!;
      expect(
        () => RoutePlaybackRequest(route, const SimulationSettings()),
        throwsFormatException,
      );
    },
  );

  test(
    'missing heights remain explicit fallbacks for the replay renderer',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final id = await repository.saveRoute(
        name: 'Unspecified altitudes',
        waypoints: const [
          RouteWaypointInput(position: first),
          RouteWaypointInput(position: last),
        ],
      );
      final payload = RoutePlaybackRequest(
        (await repository.getRoute(id))!,
        const SimulationSettings(agl: 28, maxSpeed: 11),
      ).command;
      expect((payload['points'] as List).first['heightMode'], 'unspecified');
      expect(
        (payload['points'] as List).first.containsKey('heightMeters'),
        isFalse,
      );
      expect(payload['defaultAglMeters'], 28);
      expect(payload['defaultSpeedMetersPerSecond'], 11);
    },
  );
}
