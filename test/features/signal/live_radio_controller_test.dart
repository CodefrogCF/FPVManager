import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/signal/live_radio_controller.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';
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
  test('live terrain bridge requires explicit WGS84 level-12 heights and keeps failures separate from terrain availability', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    var datum = 'wgs84Ellipsoid';
    peer.onCommand = (command) {
      if (command['type'] == 'query-live-radio-terrain') {
        peer.acknowledge(
          command,
          result: {
            'heightReference': datum,
            'samplingMethod': 'level-12',
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
    datum = 'ln02';
    await globe.liveRadio.configure(globe.liveRadio.settings);
    peer.emit({'type': 'flight-radio-position', ...pose()});
    await globe.liveRadio.settled;
    expect(globe.liveRadio.current, false);
    expect(globe.terrainAvailable, true);
  });
  test('preview is opt-in, bounded to 25m / 6km profiles and respects the update interval', () async {
    var time = DateTime.utc(2026), calls = 0, maxPoints = 0;
    final messages = <Map<String, dynamic>>[];
    final c = LiveRadioController(
      now: () => time,
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
    expect(calls, 2);
    expect(c.current, false);
    expect(c.status, contains('6 km'));
    expect(messages.last['rays'], isEmpty);
    c.telemetry(pose(id: 2, lon: 8.0));
    await c.settled;
    expect(c.status, contains('vertical'));
    expect(c.current, false);
  });

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
          await c.configure(const LiveRadioSettings());
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
}
