import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/signal/live_radio_controller.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';
import 'package:fpvmanager/features/signal/live_link_assessment.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

const pilot = Wgs84Coordinate(latitude: 47, longitude: 8);
Map<String, dynamic> pose({
  bool active = true,
  bool paused = false,
  int id = 1,
  double lon = 8.005,
  double height = 550,
}) => {
  'active': active,
  'paused': paused,
  'flightId': id,
  'latitude': 47.0,
  'longitude': lon,
  'height': height,
  'homeLatitude': 47.0,
  'homeLongitude': 8.0,
};

void main() {
  test('live terrain bridge requires WGS84 most-detailed heights and rejects stale or low-LOD data', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    var datum = 'wgs84Ellipsoid';
    var method = 'most-detailed-available';
    peer.onCommand = (command) {
      if (command['type'] == 'query-live-radio-terrain') {
        peer.acknowledge(
          command,
          result: {
            'heightReference': datum,
            'samplingMethod': method,
            'heights': List.filled((command['positions'] as List).length, 500),
          },
        );
      }
    };
    await globe.liveRadio.configure(const LiveRadioSettings(enabled: true));
    peer.emit({'type': 'flight-radio-position', ...pose()});
    await globe.liveRadio.settled;
    expect(globe.liveRadio.current, true);
    expect(
      peer.commands.lastWhere(
        (c) =>
            c['type'] == 'set-live-radio-result' &&
            (c['rays'] as List).isNotEmpty,
      )['expiresAtMs'],
      isA<int>(),
    );
    // The old level-12 results are not enough to certify a mountain link.
    method = 'level-12';
    await globe.liveRadio.configure(globe.liveRadio.settings);
    peer.emit({'type': 'flight-radio-position', ...pose()});
    await globe.liveRadio.settled;
    expect(globe.liveRadio.current, false);
    expect(globe.terrainAvailable, true);

    method = 'most-detailed-available';
    datum = 'ln02';
    await globe.liveRadio.configure(globe.liveRadio.settings);
    peer.emit({'type': 'flight-radio-position', ...pose()});
    await globe.liveRadio.settled;
    expect(globe.liveRadio.current, false);
    expect(globe.terrainAvailable, true);
  });
  test('preview is bounded per request and continues beyond 6km', () async {
    var time = DateTime.utc(2026), calls = 0, maxPoints = 0;
    final messages = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      now: () => time,
      elapsed: () => Duration(milliseconds: time.millisecondsSinceEpoch),
      send: (m) async {
        messages.add(m);
      },
      sample: (points) async {
        calls++;
        maxPoints = points.length;
        return List.filled(points.length, 500);
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: false));
    c.telemetry(pose());
    expect(calls, 0);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry(pose());
    await c.settled;
    expect(c.current, true);
    expect(c.result!.state, RadioPathState.noSampledObstruction);
    expect(maxPoints, lessThanOrEqualTo(256));
    c.telemetry(pose());
    await c.settled;
    expect(calls, 1);
    time = time.add(const Duration(seconds: 2));
    c.telemetry(pose(lon: 8.006));
    await c.settled;
    expect(calls, 2);
    time = time.add(const Duration(seconds: 2));
    c.telemetry(pose(lon: 8.2));
    await c.settled;
    expect(calls, greaterThan(2));
    expect(maxPoints, lessThanOrEqualTo(256));
    expect(c.current, true);
    expect(c.status, isNot(contains('6 km')));
    expect(messages.last['rays'], hasLength(1));
    c.telemetry(pose(id: 2, lon: 8.0));
    await c.settled;
    expect(c.current, true);
    expect(c.result!.state, RadioPathState.noSampledObstruction);
  });

  test(
    'fast flight retains its full precision budget after a failed profile',
    () async {
      var time = DateTime.utc(2026, 11, 23);
      final requests = <int>[];
      final messages = <Map<String, dynamic>>[];
      final c = LiveRadioController(
        now: () => time,
        elapsed: () => Duration(milliseconds: time.millisecondsSinceEpoch),
        send: (event) async {
          messages.add(event);
        },
        sample: (positions) async {
          requests.add(positions.length);
          if (requests.length == 1) {
            throw TimeoutException('Terrain request timed out');
          }
          final heights = List.filled(positions.length, 500.0);
          heights[positions.length ~/ 2] = 800.0;
          return heights;
        },
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings(enabled: true));
      c.telemetry({...pose(lon: 8.015), 'speed': 38.0});
      await c.settled;
      expect(
        requests.single,
        greaterThan(96),
        reason: 'Keep the original single-pass fast path initially',
      );
      expect(c.current, false);
      expect(c.status, contains('timed out'));
      time = time.add(const Duration(seconds: 2));
      c.telemetry({...pose(lon: 8.015), 'speed': 38.0});
      await c.settled;
      expect(
        requests.last,
        requests.first,
        reason: 'A timeout must not reduce the next precise terrain pass',
      );
      expect(c.current, true);
      expect(c.result!.state, RadioPathState.obstructed);
      expect(c.samplingDiagnostics!.queryCount, 1);
      expect(
        messages.lastWhere(
          (m) =>
              m['type'] == 'set-live-radio-result' &&
              m['state'] == 'obstructed',
        )['assessment']['source'],
        'sampledTerrain',
      );
      time = time.add(const Duration(seconds: 2));
      c.telemetry({...pose(lon: 8.01505), 'speed': 38.0});
      await c.settled;
      expect(
        requests.last,
        greaterThan(96),
        reason: 'Confirmed blockage must retain the precise first-pass budget',
      );
      expect(c.result!.state, RadioPathState.obstructed);
    },
  );

  test('moving flight skips refinement of a stale clear ray and immediately retries newest pose', () async {
    var time = DateTime.utc(2026, 11, 23);
    final first = Completer<List<double>>();
    var calls = 0;
    final batches = <int>[];
    final events = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      now: () => time,
      elapsed: () => Duration(milliseconds: time.millisecondsSinceEpoch),
      send: (event) async {
        events.add(event);
      },
      sample: (positions) {
        ++calls;
        batches.add(positions.length);
        if (calls == 1) return first.future;
        return Future.value(List.filled(positions.length, 500.0));
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry({...pose(lon: 8.015), 'speed': 40.0});
    expect(
      batches.single,
      greaterThan(96),
      reason: 'Do not slow down a working first near-field query',
    );
    time = time.add(const Duration(seconds: 2));
    c.telemetry({...pose(lon: 8.017), 'speed': 40.0});
    first.complete(List.filled(batches.first, 500.0));
    await c.settled;
    await Future<void>.delayed(Duration.zero);
    await c.settled;
    expect(calls, greaterThan(1));
    expect(c.current, true);
    expect(c.result!.target.longitude, closeTo(8.017, 0.000001));
    expect(
      events.where(
        (event) =>
            event['state'] == 'noSampledObstruction' &&
            (event['rays'] as List).isNotEmpty,
      ),
      hasLength(1),
      reason: 'The overtaken clear ray must never be published as current',
    );
  });

  test('fast motion expires the old HUD profile but does not cancel a newer in-flight sample', () async {
    var time = DateTime.utc(2026, 11, 23);
    Completer<List<double>>? pending;
    var requestedPoints = 0;
    final emitted = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      now: () => time,
      elapsed: () => Duration(milliseconds: time.millisecondsSinceEpoch),
      send: (message) async {
        emitted.add(message);
      },
      sample: (positions) {
        requestedPoints = positions.length;
        return pending?.future ??
            Future.value(List.filled(positions.length, 500.0));
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry(pose(lon: 8.005));
    await c.settled;
    expect(c.current, true);

    time = time.add(const Duration(seconds: 2));
    pending = Completer<List<double>>();
    c.telemetry(pose(lon: 8.00510)); // Below the old 12 m limit.
    expect(c.loading, true);
    c.telemetry(pose(lon: 8.00522)); // Past old result, still near new query.
    expect(c.current, false);
    pending.complete(List.filled(requestedPoints, 500.0));
    await c.settled;
    expect(
      c.current,
      true,
      reason: 'The newer in-flight request must survive the old profile expiry',
    );
    expect(c.result!.state, RadioPathState.noSampledObstruction);
    final unknown = emitted.lastWhere(
      (m) => m['type'] == 'set-live-radio-result' && m['state'] == 'unknown',
    );
    final published = emitted.lastWhere(
      (m) =>
          m['type'] == 'set-live-radio-result' &&
          m['state'] == 'noSampledObstruction',
    );
    expect(published['revision'], greaterThan(unknown['revision'] as int));
  });

  test('delayed but deep sampled ridge is rechecked against a faster aircraft on the same ray', () async {
    final pending = Completer<List<double>>();
    var count = 0;
    final messages = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      send: (message) async {
        messages.add(message);
      },
      sample: (points) {
        count = points.length;
        return pending.future;
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry(pose(lon: 8.004, height: 550));
    c.telemetry(pose(lon: 8.006, height: 550));
    final heights = List<double>.filled(count, 500.0);
    heights[count ~/ 2] = 650;
    pending.complete(heights);
    await c.settled;
    expect(c.current, true);
    expect(c.result!.target.longitude, closeTo(8.006, 0.000001));
    expect(c.result!.state, RadioPathState.obstructed);
    expect(c.assessment.confidence, LiveAssessmentConfidence.limited);
    final published = messages.lastWhere(
      (message) =>
          message['state'] == 'obstructed' &&
          message['type'] == 'set-live-radio-result',
    );
    expect((published['sampling'] as Map)['recheckedMovingPath'], true);
    expect(
      (published['rays'] as List).single['longitude'],
      closeTo(8.006, 0.000001),
    );
  });

  test('moving aircraft queues a fresh precise terrain pass while the old pass is in flight', () async {
    var time = DateTime.utc(2026, 11, 23);
    final first = Completer<List<double>>();
    var calls = 0;
    var firstCount = 0;
    final c = LiveRadioController(
      now: () => time,
      elapsed: () => Duration(milliseconds: time.millisecondsSinceEpoch),
      send: (_) async {},
      sample: (points) {
        ++calls;
        if (calls == 1) {
          firstCount = points.length;
          return first.future;
        }
        return Future.value(List.filled(points.length, 500.0));
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry({...pose(lon: 8.005), 'speed': 60.0});
    expect(calls, 1);
    // The first profile is still pending. The new aircraft position must be
    // queued, not used to certify the old ray as the current one.
    time = time.add(const Duration(seconds: 1));
    c.telemetry({...pose(lon: 8.00515), 'speed': 60.0});
    expect(calls, 1);
    first.complete(List.filled(firstCount, 500.0));
    await c.settled;
    await Future<void>.delayed(Duration.zero);
    await c.settled;
    expect(calls, 2, reason: 'refresh immediately after a delayed first pass');
    expect(c.result!.target.longitude, closeTo(8.00515, 0.000001));
    expect(c.current, true);
  });

  test(
    'a sharp turn cannot reuse blockage sampled on a different ray',
    () async {
      final pending = Completer<List<double>>();
      var count = 0;
      final c = LiveRadioController(
        send: (_) async {},
        sample: (points) {
          count = points.length;
          return pending.future;
        },
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings(enabled: true));
      c.telemetry(pose(lon: 8.004, height: 550));
      final turning = pose(lon: 8.006, height: 550);
      turning['latitude'] = 47.003;
      c.telemetry(turning);
      final heights = List<double>.filled(count, 500.0);
      heights[count ~/ 2] = 650;
      pending.complete(heights);
      await c.settled;
      expect(c.current, false);
      expect(c.assessment.visibility, LivePathVisibility.unknown);
    },
  );

  test('beyond 50 km remains unknown but provides range for free-space diagnostics', () async {
    final messages = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      send: (m) async {
        messages.add(m);
      },
      sample: (_) async => fail('No terrain query expected beyond 50 km'),
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry(pose(lon: 9.0));
    await c.settled;
    expect(c.current, false);
    expect(c.status, contains('50 km'));
    final unknown = messages.lastWhere(
      (m) => m['type'] == 'set-live-radio-result' && m['state'] == 'unknown',
    );
    expect(unknown['distanceMeters'], greaterThan(50000));
    expect(unknown['rays'], isEmpty);
  });

  test(
    'terrain outage provides free-space distance but not RC/video quality',
    () async {
      final events = <Map<String, dynamic>>[];
      final c = LiveRadioController(
        send: (m) async {
          events.add(m);
        },
        sample: (points) async => List.filled(points.length, 500),
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings(enabled: true));
      c.terrainChanged(false);
      c.telemetry(pose(lon: 8.3));
      await Future<void>.delayed(Duration.zero);
      expect(c.current, false);
      expect(c.assessment.rcQuality.name, 'unknown');
      expect(c.assessment.videoQuality.name, 'unknown');
      final unknown = events.lastWhere(
        (m) => m['type'] == 'set-live-radio-result' && m['state'] == 'unknown',
      );
      expect(unknown['distanceMeters'], greaterThan(1000));
      expect(unknown['rays'], isEmpty);
    },
  );

  test('ridge and Fresnel intrusion remain distinct and a fixed transmitter uses its own terrain reference', () async {
    var ridge = true;
    final c = LiveRadioController(
      send: (_) async {},
      sample: (p) async {
        final h = List.filled(p.length, 500.0);
        if (ridge) h[h.length ~/ 2] = 650;
        return h;
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(
      const LiveRadioSettings(
        enabled: true,
        useSpawn: false,
        signal: SignalSettings(
          pilot: Wgs84Coordinate(latitude: 47, longitude: 7.999),
          antennaHeight: 2,
        ),
      ),
    );
    c.telemetry(pose());
    await c.settled;
    expect(c.result!.state, RadioPathState.obstructed);
    expect(c.result!.minimumClearance, lessThan(0));
    expect(c.transmitter!.longitude, 7.999);
    expect(c.transmitterHeight, 502);
    ridge = false;
    await c.configure(
      const LiveRadioSettings(
        enabled: true,
        signal: SignalSettings(pilot: pilot, frequencyMhz: 100),
      ),
    );
    c.telemetry(pose(height: 502));
    await c.settled;
    expect(c.result!.state, RadioPathState.fresnelIntrusion);
    expect(c.result!.minimumClearance, greaterThan(0));
  });

  test('late replies cannot restore geometry after disabling, a pause, respawn or renderer loss', () async {
    for (final interrupt in ['disabled', 'pause', 'respawn', 'renderer']) {
      final pending = Completer<List<double>>(),
          messages = <Map<String, dynamic>>[];
      var count = 0;
      final c = LiveRadioController(
        send: (m) async {
          messages.add(m);
        },
        sample: (p) {
          count = p.length;
          return pending.future;
        },
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings(enabled: true));
      c.telemetry(pose());
      final settled = c.settled;
      switch (interrupt) {
        case 'disabled':
          await c.configure(const LiveRadioSettings(enabled: false));
        case 'pause':
          c.telemetry(pose(paused: true));
        case 'respawn':
          c.telemetry(pose(id: 2, paused: true));
        case 'renderer':
          c.renderer(false);
      }
      pending.complete(List.filled(count, 500));
      await settled;
      expect(c.current, false, reason: interrupt);
      expect(
        messages
            .where((m) => m['type'] == 'set-live-radio-result')
            .every((m) => (m['rays'] as List).isEmpty),
        true,
        reason: interrupt,
      );
    }
  });

  testWidgets(
    'an old result expires even while a replacement query is still pending',
    (tester) async {
      Completer<List<double>>? slow;
      var length = 0;
      final c = LiveRadioController(
        now: () => tester.binding.clock.now(),
        elapsed: () => Duration(
          milliseconds: tester.binding.clock.now().millisecondsSinceEpoch,
        ),
        send: (_) async {},
        sample: (p) async {
          length = p.length;
          return slow == null ? List.filled(p.length, 500) : slow.future;
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings(enabled: true));
        c.telemetry(pose());
        await c.settled;
        expect(c.current, true);
        await tester.pump(const Duration(seconds: 2));
        slow = Completer<List<double>>();
        c.telemetry(pose());
        await tester.pump(const Duration(seconds: 4));
        expect(c.current, false);
        expect(c.status, contains('older than 5'));
        slow.complete(List.filled(length, 500));
        await c.settled;
        expect(c.current, true);
      } finally {
        c.dispose();
      }
    },
  );

  test('missing or failed terrain never yields a clear status and observations are explicitly optional', () async {
    var fail = true;
    final c = LiveRadioController(
      send: (_) async {},
      sample: (p) async {
        if (fail) throw StateError('Offline');
        return List.filled(p.length, 500);
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    const observation = SurfaceObservation(
      position: Wgs84Coordinate(latitude: 47, longitude: 8.0025),
      height: 100,
      radius: 60,
      kind: 'vegetation',
      source: 'Local observation',
    );
    await c.configure(
      const LiveRadioSettings(
        enabled: true,
        signal: SignalSettings(
          pilot: pilot,
          useSurfaces: true,
          surfaces: [observation],
        ),
      ),
    );
    c.telemetry(pose());
    await c.settled;
    expect(c.current, false);
    expect(c.status, contains('unavailable'));
    fail = false;
    await c.configure(c.settings);
    c.telemetry(pose());
    await c.settled;
    expect(c.result!.state, RadioPathState.obstructed);
    await c.configure(const LiveRadioSettings(enabled: true));
    c.telemetry(pose());
    await c.settled;
    expect(c.result!.state, RadioPathState.noSampledObstruction);
    c.telemetry({...pose(), 'height': double.nan});
    expect(c.current, false);
    expect(c.status, contains('invalid'));
  });

  test('station marker follows the launch point, supports fixed coordinates and keeps RC/video unknown', () async {
    final sent = <Map<String, dynamic>>[];
    final controller = LiveRadioController(
      send: (message) async {
        sent.add(message);
      },
      sample: (positions) async => List.filled(positions.length, 500),
    );
    addTearDown(controller.dispose);
    controller.renderer(true);
    await controller.configure(const LiveRadioSettings(enabled: true));
    controller.telemetry(pose());
    await controller.settled;
    expect(controller.groundStation?.longitude, 8);
    expect(
      sent
          .where((m) => m['type'] == 'set-live-radio-ground-station')
          .last['position']['longitude'],
      8,
    );
    expect(controller.assessment.visibility, LivePathVisibility.clear);
    expect(controller.assessment.source, LiveAssessmentSource.sampledTerrain);
    expect(controller.assessment.rcQuality, LiveRadioQuality.unknown);
    expect(controller.assessment.videoQuality, LiveRadioQuality.unknown);
    controller.telemetry(pose(paused: true));
    expect(controller.assessment.hasCurrentGeometry, false);
    expect(
      controller.groundStation?.longitude,
      8,
      reason: 'pause keeps transmitter location',
    );
    await controller.configure(
      const LiveRadioSettings(
        enabled: true,
        useSpawn: false,
        showGroundStationMarker: false,
        showSignalPath: false,
        signal: SignalSettings(
          pilot: Wgs84Coordinate(latitude: 47, longitude: 8.002),
        ),
      ),
    );
    expect(controller.groundStation?.longitude, 8.002);
    final monitor = sent.lastWhere(
      (m) => m['type'] == 'set-flight-radio-monitor',
    );
    expect(monitor['showGroundStationMarker'], false);
    expect(monitor['showSignalPath'], false);
    controller.telemetry(pose(id: 2));
    await controller.settled;
    expect(controller.groundStation?.longitude, 8.002);
    await controller.configure(const LiveRadioSettings(enabled: true));
    controller.telemetry(pose(id: 3, lon: 8.006));
    await controller.settled;
    expect(controller.groundStation?.longitude, 8);
    expect(controller.assessment.hasCurrentGeometry, true);
  });
  testWidgets(
    'watchdog releases a hung slot and publishes only the latest pose',
    (tester) async {
      final origin = tester.binding.clock.now();
      final old = Completer<List<double>>();
      var calls = 0, oldCount = 0;
      final messages = <Map<String, dynamic>>[];
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        now: () => tester.binding.clock.now(),
        requestTimeout: const Duration(seconds: 1),
        send: (m) async {
          messages.add(m);
        },
        sample: (p) {
          if (++calls == 1) {
            oldCount = p.length;
            return old.future;
          }
          return Future.value(List.filled(p.length, 500.0));
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry(pose());
        await tester.pump(const Duration(milliseconds: 200));
        c.telemetry(pose(lon: 8.006));
        expect(c.diagnostics['active'], 1);
        expect(c.diagnostics['queued'], 1);
        await tester.pump(const Duration(milliseconds: 801));
        await c.settled;
        expect(c.current, true);
        expect(c.result!.target.longitude, 8.006);
        expect(calls, 2);
        expect(c.diagnostics['active'], 0);
        expect(
          (c.diagnostics['history'] as List).first['errorCategory'],
          'TIMEOUT',
        );
        old.complete(List.filled(oldCount, 900.0));
        await tester.pump();
        expect(c.result!.target.longitude, 8.006);
        expect(messages.where((m) => m['state'] == 'obstructed'), isEmpty);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'queued latest pose wakes after throttle without more telemetry',
    (tester) async {
      final origin = tester.binding.clock.now();
      final first = Completer<List<double>>();
      var calls = 0, count = 0;
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        send: (_) async {},
        sample: (p) {
          count = p.length;
          return ++calls == 1
              ? first.future
              : Future.value(List.filled(p.length, 500.0));
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry(pose());
        await tester.pump(const Duration(milliseconds: 100));
        c.telemetry(pose(lon: 8.0052));
        first.complete(List.filled(count, 500.0));
        await tester.pump();
        expect(calls, 1);
        await tester.pump(const Duration(milliseconds: 701));
        await c.settled;
        expect(calls, 2);
        expect(c.result!.target.longitude, 8.0052);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'provider generation releases old work and rejects its late reply',
    (tester) async {
      final first = Completer<List<double>>();
      var calls = 0, count = 0;
      final c = LiveRadioController(
        send: (_) async {},
        sample: (p) {
          if (++calls == 1) {
            count = p.length;
            return first.future;
          }
          return Future.value(List.filled(p.length, 500.0));
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry(pose());
        final generation = c.generation;
        c.terrainChanged(true);
        c.telemetry(pose(lon: 8.007));
        await tester.pump();
        await c.settled;
        expect(c.generation, greaterThan(generation));
        expect(c.current, true);
        expect(calls, 2);
        first.complete(List.filled(count, 950.0));
        await tester.pump();
        expect(c.result!.target.longitude, 8.007);
        expect(c.result!.state, RadioPathState.noSampledObstruction);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'latency consumes freshness and wall-clock jumps do not change scheduling',
    (tester) async {
      final origin = tester.binding.clock.now();
      var wall = DateTime.utc(2026), calls = 0, count = 0;
      final slow = Completer<List<double>>();
      final messages = <Map<String, dynamic>>[];
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        now: () => wall,
        send: (m) async {
          messages.add(m);
        },
        sample: (p) {
          calls++;
          count = p.length;
          return slow.future;
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry(pose());
        await tester.pump(const Duration(seconds: 3));
        wall = wall.subtract(const Duration(days: 10));
        slow.complete(List.filled(count, 500.0));
        await tester.pump();
        await c.settled;
        final valid = messages.lastWhere(
          (m) => m['state'] == 'noSampledObstruction',
        );
        expect(valid['observation']['ageMs'], 3000);
        expect(
          valid['expiresAtMs'],
          wall.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
        );
        expect(c.current, true);
        await tester.pump(const Duration(milliseconds: 2001));
        expect(c.current, false);
        expect(c.diagnostics['quality'], 'stale');
        c.telemetry(pose());
        await tester.pump();
        await c.settled;
        expect(
          calls,
          2,
          reason: 'Backward wall time must not starve the scheduler',
        );
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets('response beyond freshness horizon is explicitly stale', (
    tester,
  ) async {
    final origin = tester.binding.clock.now();
    final slow = Completer<List<double>>();
    var count = 0;
    final c = LiveRadioController(
      elapsed: () => tester.binding.clock.now().difference(origin),
      send: (_) async {},
      sample: (p) {
        count = p.length;
        return slow.future;
      },
    );
    try {
      c.renderer(true);
      await c.configure(const LiveRadioSettings());
      c.telemetry(pose());
      await tester.pump(const Duration(seconds: 6));
      slow.complete(List.filled(count, 500.0));
      await tester.pump();
      await c.settled;
      expect(c.current, false);
      expect(c.diagnostics['quality'], 'stale');
      expect(c.diagnostics['error'], 'STALE');
    } finally {
      c.dispose();
    }
  });

  test(
    'missing samples and repeated errors retain bounded diagnostics',
    () async {
      var tick = Duration.zero;
      final c = LiveRadioController(
        elapsed: () => tick,
        send: (_) async {},
        sample: (p) async => List.filled(p.length - 1, 500.0),
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings());
      for (var i = 0; i < 80; ++i) {
        c.telemetry(pose());
        await c.settled;
        tick += const Duration(seconds: 1);
      }
      expect(c.current, false);
      expect(c.diagnostics['failures'], 80);
      expect(c.diagnostics['missingSamples'], 1);
      expect(c.diagnostics['error'], 'INVALID_RESULT');
      expect(c.diagnostics['history'], hasLength(64));
    },
  );
  testWidgets('pause and resume replace a cancelled throttle wakeup', (
    tester,
  ) async {
    final origin = tester.binding.clock.now();
    var calls = 0;
    final c = LiveRadioController(
      elapsed: () => tester.binding.clock.now().difference(origin),
      send: (_) async {},
      sample: (p) async {
        calls++;
        return List.filled(p.length, 500.0);
      },
    );
    try {
      c.renderer(true);
      await c.configure(const LiveRadioSettings());
      c.telemetry(pose());
      await c.settled;
      await tester.pump(const Duration(milliseconds: 100));
      c.telemetry(pose(lon: 8.0051));
      c.telemetry(pose(paused: true));
      await tester.pump(const Duration(milliseconds: 100));
      c.telemetry(pose(lon: 8.0052));
      await tester.pump(const Duration(milliseconds: 601));
      await c.settled;
      expect(calls, 2);
      expect(c.result!.target.longitude, 8.0052);
    } finally {
      c.dispose();
    }
  });

  testWidgets(
    'an old queued aircraft pose cannot become a fresh observation after a timeout',
    (tester) async {
      final origin = tester.binding.clock.now();
      final old = Completer<List<double>>();
      var calls = 0, count = 0;
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        send: (_) async {},
        sample: (p) {
          calls++;
          count = p.length;
          return old.future;
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry(pose());
        await tester.pump(const Duration(milliseconds: 100));
        c.telemetry(pose(lon: 8.0052));
        await tester.pump(const Duration(seconds: 12));
        await c.settled;
        expect(calls, 1);
        expect(c.current, false);
        expect(c.diagnostics['active'], 0);
        expect(c.diagnostics['queued'], 0);
        expect(c.diagnostics['quality'], 'stale');
        old.complete(List.filled(count, 500.0));
        await tester.pump();
        expect(c.current, false);
      } finally {
        c.dispose();
      }
    },
  );

  test('invalid telemetry publishes its explicit error quality', () async {
    final events = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      send: (m) async {
        events.add(m);
      },
      sample: (p) async => List.filled(p.length, 500.0),
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings());
    c.telemetry({...pose(), 'height': double.nan});
    await Future<void>.delayed(Duration.zero);
    final observation = events.lastWhere(
      (m) => m['type'] == 'set-live-radio-result',
    )['observation'];
    expect(observation['quality'], 'error');
    expect(observation['errorCategory'], 'INVALID_RESULT');
  });
  test(
    'regional RF coverage loss invalidates and reentry resumes sampling',
    () async {
      var tick = Duration.zero, calls = 0;
      final c = LiveRadioController(
        elapsed: () => tick,
        send: (_) async {},
        sample: (positions) async {
          calls++;
          return List.filled(positions.length, 500.0);
        },
      );
      addTearDown(c.dispose);
      c.renderer(true);
      await c.configure(const LiveRadioSettings());
      c.telemetry(pose());
      await c.settled;
      expect(c.current, true);
      final sampled = calls;
      for (var i = 0; i < 3; i++) {
        tick += const Duration(seconds: 1);
        c.telemetry({...pose(), 'height': null, 'rfHeightUnavailable': true});
        await c.settled;
      }
      expect(c.current, false);
      expect(calls, sampled);
      expect(c.status, contains('regional RF height coverage unavailable'));
      tick += const Duration(seconds: 1);
      c.telemetry(pose());
      await c.settled;
      expect(calls, greaterThan(sampled));
      expect(c.current, true);
    },
  );

  test('BKG beta unverified datum is an explicit notice and is not retried until provider change', () async {
    var tick = Duration.zero, calls = 0;
    final events = <Map<String, dynamic>>[];
    var unsupported = true;
    final c = LiveRadioController(
      elapsed: () => tick,
      send: (m) async {
        events.add(m);
      },
      sample: (p) async {
        calls++;
        if (unsupported) {
          throw StateError(
            'TERRAIN_UNAVAILABLE: BKG beta terrain vertical datum is not verified for RF planning',
          );
        }
        return List.filled(p.length, 500.0);
      },
    );
    addTearDown(c.dispose);
    c.renderer(true);
    await c.configure(const LiveRadioSettings());
    for (var i = 0; i < 10; i++) {
      c.telemetry(pose());
      await c.settled;
      tick += const Duration(seconds: 1);
    }
    expect(calls, 1);
    expect(c.current, false);
    expect(c.diagnostics['provider'], 'BKG 3D Beta');
    expect(c.diagnostics['quality'], 'unknown');
    expect(c.diagnostics['error'], 'TERRAIN_UNAVAILABLE');
    final message = events.lastWhere(
      (m) => m['type'] == 'set-live-radio-result',
    );
    expect(
      message['observation']['reason'],
      contains('height reference unverified'),
    );
    expect(message['rays'], isEmpty);
    unsupported = false;
    c.terrainChanged(true);
    c.telemetry(pose());
    await c.settled;
    expect(calls, 2);
    expect(c.current, true);
  });

  test(
    'fast 6km terrain crosses the real Dart bridge in one complete first pass',
    () async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final sizes = <int>[];
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.onCommand = (command) {
        if (command['type'] != 'query-live-radio-terrain') {
          return;
        }
        final size = (command['positions'] as List).length;
        sizes.add(size);
        peer.acknowledge(
          command,
          result: {
            'heightReference': 'wgs84Ellipsoid',
            'samplingMethod': 'most-detailed-available',
            'heights': List.filled(size, 500),
          },
        );
      };
      await globe.liveRadio.configure(const LiveRadioSettings());
      peer.emit({
        'type': 'flight-radio-position',
        ...pose(lon: 8.078, height: 1200),
        'speed': 140 / 3.6,
      });
      await globe.liveRadio.settled;
      expect(sizes, hasLength(1));
      expect(sizes.single, greaterThan(256));
      expect(sizes.single, lessThanOrEqualTo(256 + 384));
      expect(globe.liveRadio.current, true);
      expect(
        globe.liveRadio.samplingDiagnostics!.maximumGapMeters,
        lessThanOrEqualTo(16),
      );
    },
  );
  testWidgets(
    'new telemetry at the same monotonic timestamp still replaces a queued pose',
    (tester) async {
      final origin = tester.binding.clock.now();
      final first = Completer<List<double>>();
      var calls = 0, count = 0;
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        send: (_) async {},
        sample: (p) {
          count = p.length;
          return ++calls == 1
              ? first.future
              : Future.value(List.filled(p.length, 500.0));
        },
      );
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        c.telemetry({...pose(height: 1200), 'speed': 140 / 3.6});
        c.telemetry({...pose(lon: 8.006, height: 1200), 'speed': 140 / 3.6});
        first.complete(List.filled(count, 500.0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 201));
        await c.settled;
        expect(calls, 2);
        expect(c.current, true);
        expect(c.result!.target.longitude, 8.006);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    '140kmh with frame-jittered telemetry keeps fresh 5km clear coverage',
    (tester) async {
      final origin = tester.binding.clock.now();
      const speed = 140 / 3.6;
      final c = LiveRadioController(
        elapsed: () => tester.binding.clock.now().difference(origin),
        send: (_) async {},
        sample: (p) async {
          await Future<void>.delayed(const Duration(milliseconds: 160));
          return List.filled(p.length, 500.0);
        },
      );
      var warmUnknown = 0;
      try {
        c.renderer(true);
        await c.configure(const LiveRadioSettings());
        for (var ms = 0; ms < 6000; ms += 12) {
          if (ms % 216 == 0) {
            c.telemetry({
              ...pose(lon: 8.066, height: 1200),
              'latitude': 47 + speed * (ms / 1000) / 111195,
              'speed': speed,
            });
          }
          await tester.pump(const Duration(milliseconds: 12));
          if (ms >= 2000 && !c.current) warmUnknown++;
        }
        expect(warmUnknown, 0);
        expect(c.samplingDiagnostics!.maximumGapMeters, lessThanOrEqualTo(16));
        expect(c.result!.state, RadioPathState.noSampledObstruction);
      } finally {
        c.dispose();
        await tester.pump(const Duration(milliseconds: 200));
      }
    },
  );
}
