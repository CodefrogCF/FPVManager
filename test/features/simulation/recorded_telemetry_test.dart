import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/recorded_route_track.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/core/models/route_transfer.dart';
import 'package:fpvmanager/features/routes/transfer/route_file_codec.dart';
import 'package:fpvmanager/features/simulation/flight_recording.dart';

RecordedFlightPoint sample(
  int i, {
  double? ground = 1000,
  double? speed = 8,
  double height = 1040,
}) => RecordedFlightPoint(
  sequence: i + 1,
  segment: 0,
  seconds: i * .5,
  position: Wgs84Coordinate(latitude: 46.7 + i * .00002, longitude: 8.4),
  height: height,
  ground: ground,
  speedMetersPerSecond: speed,
);

void main() {
  test('legacy samples remain readable without inventing speed or AGL', () {
    final old = RecordedFlightPoint.parse([1, 0, 0, 46.7, 8.4, 1040, null]);
    expect(old.ground, isNull);
    expect(old.agl, isNull);
    expect(old.speedMetersPerSecond, isNull);
    final current = RecordedFlightPoint.parse([
      2,
      0,
      .5,
      46.7,
      8.4,
      1040,
      1000,
      14,
    ]);
    expect(current.agl, 40);
    expect(current.speedMetersPerSecond, 14);
    expect(
      current.acquiredAt(DateTime.utc(2026, 11, 4)),
      DateTime.utc(2026, 11, 4).add(const Duration(milliseconds: 500)),
    );
    for (final invalid in [
      [2, 0, .5, 46.7, 8.4, 1040, 1000, -1],
      [2, 0, .5, 46.7, 8.4, 1040, 1000, double.nan],
      [2, 0, .5, 46.7, 8.4, 1040, 1050, 12],
    ]) {
      expect(() => RecordedFlightPoint.parse(invalid), throwsFormatException);
    }
  });

  test('simplification retains motion and terrain-information transitions', () {
    final track = [
      sample(0, speed: 4),
      sample(1, speed: 18),
      sample(2, speed: 4),
      sample(3, speed: 4, ground: null),
      sample(4, speed: 4),
    ];
    final reduced = simplifyRecording(track, 20);
    expect(reduced, contains(track[1]));
    expect(reduced, contains(track[3]));
    expect(track[3].agl, isNull);
    expect(track.length, 5);
  });

  test(
    'simplification keeps data-gap boundaries without retaining whole runs',
    () {
      final values = [
        for (var i = 0; i <= 100; i++)
          sample(
            i,
            height: 1040,
            ground: i == 20 || (i >= 70 && i <= 75) ? null : 1000,
            speed: i >= 40 && i <= 45 ? null : 8,
          ),
      ];
      final reduced = simplifyRecording(values, 2);
      expect(reduced.first, same(values.first));
      expect(reduced.last, same(values.last));
      for (final index in [19, 20, 21, 39, 40, 45, 46, 69, 70, 75, 76]) {
        expect(reduced, contains(values[index]));
      }
      expect(reduced.length, lessThan(20));
      expect(values.length, 101);
    },
  );

  test('route metadata survives SQLite and both transfer formats', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FlightPlanRepository(db);
    final values = [
      sample(0, speed: 2),
      sample(1, speed: 12, ground: null),
      sample(2, speed: 5, height: 1050),
    ];
    final flight = RecordedFlight(
      'flight-test-108',
      DateTime.utc(2026, 11, 4),
      values,
    );
    final waypoints = recordingWaypoints(values, agl: false);
    final id = await RecordingRouteSave().save(
      repository,
      name: 'Recorded demo',
      points: waypoints,
      flight: flight,
      recordedPoints: values,
    );
    final route = (await repository.getRoute(id!))!;
    final track = route.recordedTrack!;
    expect(track.id, flight.id);
    expect(track.startedAtUtc, flight.startedAt);
    expect(track.samples.map((s) => s.seconds), [0, .5, 1]);
    expect(track.samples.map((s) => s.groundSpeedMetersPerSecond), [2, 12, 5]);
    expect(track.samples.map((s) => s.aglMeters), [40, null, 50]);
    expect(track.samples.last.absoluteElevationMeters, 1050);
    expect(track.samples[1].terrainElevationMeters, isNull);
    expect(
      RoutePlanningSettings.decode(route.plan.planningJson).recordedTrack,
      isNotNull,
    );
    expect(
      RoutePlanningSettings.decode(const RoutePlanningSettings().encode())
          .recordedTrack,
      isNull,
    );
    for (final format in RouteFileFormat.values) {
      final bytes = encodeRouteFile(
        ImportedRoute('Recorded demo', waypoints, recordedTrack: track),
        format,
      );
      final decoded = decodeRouteFile(bytes).routes.single;
      final restored = decoded.recordedTrack!;
      expect(restored.samples.map((s) => s.seconds), [0, .5, 1]);
      expect(restored.samples.map((s) => s.groundSpeedMetersPerSecond), [
        2,
        12,
        5,
      ]);
      expect(restored.samples.map((s) => s.aglMeters), [40, null, 50]);
      expect(
        restored.waypointSignature,
        recordedInputSignature(decoded.points),
      );
      final importedIds = await repository.importRoutes([decoded]);
      final storedAgain = (await repository.getRoute(importedIds.single))!;
      expect(
        storedAgain.recordedTrack?.samples.last.groundSpeedMetersPerSecond,
        5,
      );
      expect(storedAgain.recordedTrack?.samples[1].aglMeters, isNull);
    }
  });

  test(
    'time-based interpolation preserves unknown fields and clamps endpoints',
    () {
      final points = recordingWaypoints([
        sample(0),
        sample(1),
        sample(2),
      ], agl: false);
      final track = RecordedRouteTrack(
        id: 'interpolation',
        startedAtUtc: DateTime.utc(2026, 11, 4),
        waypointSignature: recordedInputSignature(points),
        samples: const [
          RecordedTrackSample(
            seconds: 0,
            absoluteElevationMeters: 1000,
            terrainElevationMeters: 950,
            groundSpeedMetersPerSecond: 4,
          ),
          RecordedTrackSample(
            seconds: 1,
            absoluteElevationMeters: 1040,
            terrainElevationMeters: 960,
            groundSpeedMetersPerSecond: 12,
          ),
          RecordedTrackSample(
            seconds: 2,
            absoluteElevationMeters: 1080,
            terrainElevationMeters: null,
            groundSpeedMetersPerSecond: null,
          ),
        ],
      );
      final midpoint = track.sampleAt(.5);
      expect(midpoint.seconds, .5);
      expect(midpoint.absoluteElevationMeters, 1020);
      expect(midpoint.terrainElevationMeters, 955);
      expect(midpoint.aglMeters, 65);
      expect(midpoint.groundSpeedMetersPerSecond, 8);
      expect(track.sampleAt(1.5).absoluteElevationMeters, 1060);
      expect(track.sampleAt(1.5).aglMeters, isNull);
      expect(track.sampleAt(1.5).groundSpeedMetersPerSecond, isNull);
      expect(track.sampleAt(-5), same(track.samples.first));
      expect(track.sampleAt(500), same(track.samples.last));
      expect(() => track.sampleAt(double.nan), throwsArgumentError);
    },
  );

  test('edited route signature invalidates old replay metadata', () {
    final samples = [sample(0), sample(1)];
    final points = recordingWaypoints(samples, agl: false);
    final track = RecordedRouteTrack(
      id: 'flight-test',
      startedAtUtc: DateTime.utc(2026, 11, 4),
      waypointSignature: recordedInputSignature(points),
      samples: [
        for (final value in samples)
          RecordedTrackSample(
            seconds: value.seconds,
            absoluteElevationMeters: value.height,
            terrainElevationMeters: value.ground,
            groundSpeedMetersPerSecond: value.speedMetersPerSecond,
          ),
      ],
    );
    final changed = [
      points.first,
      RouteWaypointInput(
        position: const Wgs84Coordinate(latitude: 46.71, longitude: 8.4),
        height: points.last.height,
      ),
    ];
    expect(track.waypointSignature, isNot(recordedInputSignature(changed)));
    expect(
      () => encodeRouteFile(
        ImportedRoute('Edited', changed, recordedTrack: track),
        RouteFileFormat.geoJson,
      ),
      throwsFormatException,
    );
  });
}
