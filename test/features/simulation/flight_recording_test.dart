import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/analysis/route_analysis.dart';
import 'package:fpvmanager/features/simulation/flight_recording.dart';

import '../../helpers/fake_globe_renderer.dart';

RecordedFlightPoint point(
  int i, {
  int segment = 0,
  double? height,
  double? ground = 1000,
  double? lat,
  double? lon,
}) => RecordedFlightPoint(
  sequence: i + 1,
  segment: segment,
  seconds: i * .5,
  position: Wgs84Coordinate(
    latitude: lat ?? 46.7 + i * .00001,
    longitude: lon ?? 8.4,
  ),
  height: height ?? 1040 + i.toDouble(),
  ground: ground,
);

void main() {
  test('bridge capture retains bounded samples through stop, renderer loss and a new renderer session', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await globe.recording.control('start');
    final id = globe.recording.id;
    void sample(int i, int segment) => peer.emit({
      'type': 'flight-recording-sample',
      'id': id,
      'sample': [
        i,
        segment,
        (i - 1) * .5,
        46.7 + i * .00001,
        8.4,
        1040.0,
        1000.0,
      ],
    });
    sample(1, 0);
    sample(2, 0);
    sample(3, 1);
    expect(globe.recording.count, 3);
    expect(globe.recording.snapshot().segments.map((s) => s.length), [2, 1]);
    globe.rendererLoading();
    expect(globe.recording.phase, RecordingPhase.stopped);
    expect(globe.recording.count, 3);
    peer.sessionId = 'renderer-2';
    peer.ready();
    await Future<void>.delayed(Duration.zero);
    final restored = peer.commands.lastWhere(
      (c) =>
          c['type'] == 'flight-recording-control' && c['action'] == 'restore',
    );
    expect(restored['count'], 3);
    expect(restored['id'], id);
    sample(4, 1);
    expect(globe.recording.count, 3);
    await globe.discardFlightRecording();
    expect(globe.recording.hasSamples, false);
    sample(1, 0);
    expect(globe.recording.hasSamples, false);
  });

  test('corrupt, missing and obsolete recording data never joins an unverified trajectory', () async {
    for (final raw in [
      [3, 0, 1.0, 46.7, 8.4, 1040.0, null],
      [2, 0, -1, 46.7, 8.4, 1040.0, null],
      [2, 0, 1, 91, 8.4, 1040.0, null],
      [2, 0, 1, 46.7, 8.4, double.nan, null],
    ]) {
      final recording = FlightRecording((_) async {});
      addTearDown(recording.dispose);
      await recording.control('start');
      recording.handle({
        'type': 'flight-recording-sample',
        'id': recording.id,
        'sample': [1, 0, 0, 46.7, 8.4, 1040, 1000],
      });
      recording.handle({
        'type': 'flight-recording-sample',
        'id': 'old',
        'sample': raw,
      });
      expect(recording.count, 1);
      recording.handle({
        'type': 'flight-recording-sample',
        'id': recording.id,
        'sample': raw,
      });
      expect(recording.count, 1);
      expect(recording.phase, RecordingPhase.stopped);
      expect(recording.message, contains('retained'));
    }
  });

  test('3D simplification preserves a vertical peak, a turn and endpoints without changing raw samples', () {
    final raw = [
      for (var i = 0; i <= 100; i++)
        point(
          i,
          height: i <= 50 ? 1040 + i.toDouble() : 1140 - i.toDouble(),
          lon: i < 50 ? 8.4 : 8.4 + (i - 50) * .00002,
        ),
    ];
    final copy = List.of(raw), reduced = simplifyRecording(raw, 2);
    expect(reduced.first, same(raw.first));
    expect(reduced.last, same(raw.last));
    expect(reduced, contains(raw[50]));
    expect(reduced.length, lessThan(10));
    expect(raw, copy);
    final vertical = [
      point(0, lat: 46.7, height: 1000),
      point(1, lat: 46.7, height: 1100),
      point(2, lat: 46.7, height: 1000),
    ];
    expect(simplifyRecording(vertical, 2).length, 3);
    expect(recordedDistance(vertical), closeTo(200, .01));
    expect(simplifyRecording(raw, 0), raw);
    expect(() => simplifyRecording(raw, double.nan), throwsArgumentError);
    final single = [point(0)];
    expect(() => recordingWaypoints(single, agl: false), throwsArgumentError);
    expect(
      () => recordingWaypoints([point(0), point(1, segment: 1)], agl: false),
      throwsArgumentError,
    );
  });

  test('simplified track remains within the selected 3D deviation at every observed point', () {
    final raw = [
      for (var i = 0; i < 500; i++)
        point(i, lat: 0, lon: i * .00001, height: 100 + 10 * math.sin(i * .1)),
    ];
    final reduced = simplifyRecording(raw, 2);
    for (var j = 1; j < reduced.length; j++) {
      final a = reduced[j - 1], b = reduced[j];
      for (final p in raw.where(
        (p) => p.sequence > a.sequence && p.sequence < b.sequence,
      )) {
        final x = (p.position.longitude - a.position.longitude) * 111319.5,
            z = p.height - a.height,
            bx = (b.position.longitude - a.position.longitude) * 111319.5,
            bz = b.height - a.height;
        final t = ((x * bx + z * bz) / (bx * bx + bz * bz)).clamp(0, 1);
        expect(
          math.sqrt(math.pow(x - t * bx, 2) + math.pow(z - t * bz, 2)),
          lessThan(2.01),
        );
      }
    }
  });

  test('saved route keeps explicit height references, preserves existing routes and supports route sampling', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FlightPlanRepository(db);
    final existing = await repo.saveRoute(name: 'Existing', waypoints: []);
    final raw = [
      point(0, height: 1080),
      point(1, height: 1120, ground: null),
      point(2, height: 1100),
    ];
    final absolute = recordingWaypoints(raw, agl: false);
    expect(() => recordingWaypoints(raw, agl: true), throwsArgumentError);
    final save = RecordingRouteSave(),
        id = await save.save(repo, name: 'Simulated ridge', points: absolute);
    expect(await save.save(repo, name: 'Duplicate', points: absolute), id);
    final route = (await repo.getRoute(id!))!;
    expect(route.waypoints.map((p) => p.height!.meters), [1080, 1120, 1100]);
    for (final p in route.waypoints) {
      expect(
        (p.height as AbsoluteWaypointHeight).elevation.reference,
        VerticalReference.wgs84Ellipsoid,
      );
      expect(p.speedMetersPerSecond, isNull);
    }
    expect(RouteSamplingPlan.create(absolute).samples, isNotEmpty);
    expect((await repo.getRoute(existing))!.plan.name, 'Existing');
    expect((await repo.getAllFlightPlans()).length, 2);
    final agl = recordingWaypoints([
      point(0, height: 1080),
      point(1, height: 1100, ground: 1050),
    ], agl: true);
    expect(agl.map((p) => p.height!.meters), [80, 50]);
    expect(agl.first.height, isA<AglWaypointHeight>());
  });

  test('failed and concurrent saves retain the recording and create only one successful route', () async {
    final repo = DelayedRecordingRepository(),
        save = RecordingRouteSave(),
        points = recordingWaypoints([point(0), point(1)], agl: false);
    final first = save.save(repo, name: 'Track', points: points);
    expect(await save.save(repo, name: 'Track', points: points), isNull);
    expect(repo.calls, 1);
    repo.pending.completeError(StateError('Storage full'));
    await expectLater(first, throwsStateError);
    expect(save.savedId, isNull);
    expect(save.saving, false);
    repo.pending = Completer<int>();
    final retry = save.save(repo, name: 'Track', points: points);
    repo.pending.complete(42);
    expect(await retry, 42);
    expect(await save.save(repo, name: 'Again', points: points), 42);
    expect(repo.calls, 2);
  });
}

class DelayedRecordingRepository implements FlightPlanRepository {
  Completer<int> pending = Completer<int>();
  int calls = 0;
  @override
  Future<int> saveRoute({
    int? id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    Set<int>? batteryIds,
    dynamic planning,
    required List<RouteWaypointInput> waypoints,
  }) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
