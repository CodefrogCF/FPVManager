import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/weather/wind_field.dart';
import 'package:fpvmanager/features/weather/wind_field_service.dart';
import 'package:fpvmanager/features/weather/wind_map_controller.dart';
import 'package:fpvmanager/features/weather/wind_settings_sheet.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

final now = DateTime.utc(2026, 10, 28, 12);
List<Map<String, dynamic>> response({
  DateTime? at,
  bool hourly = false,
  double speed = 8,
}) => List.generate(
  9,
  (i) => {
    'latitude': 46.7,
    'longitude': 8.4,
    hourly ? 'hourly_units' : 'current_units': {
      for (final h in WindFieldService.heights) ...{
        'wind_speed_${h}m': 'm/s',
        'wind_direction_${h}m': '°',
      },
    },
    hourly ? 'hourly' : 'current': <String, dynamic>{
      'time': hourly
          ? [(at ?? now).toIso8601String()]
          : (at ?? now).toIso8601String(),
      for (final h in WindFieldService.heights) ...{
        'wind_speed_${h}m': hourly ? [speed] : speed,
        'wind_direction_${h}m': hourly ? [270] : 270,
      },
    },
  },
);
http.Response reply(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class ImmediateWindService extends WindFieldService {
  ImmediateWindService(this.clock, this.onLoad)
    : super(client: MockClient((_) async => reply(response())));
  final DateTime Function() clock;
  final void Function() onLoad;
  @override
  Future<WindFieldSnapshot> load({
    required double latitude,
    required double longitude,
    required WindTimeMode mode,
    DateTime? forecastUtc,
    double radiusMeters = 1500,
  }) async {
    onLoad();
    return WindFieldSnapshot(
      mode: mode,
      validAtUtc: clock(),
      retrievedUtc: clock(),
      expiresUtc: clock().add(const Duration(minutes: 30)),
      nodes: const [],
      centerLatitude: latitude,
      centerLongitude: longitude,
      radiusMeters: radiusMeters,
    );
  }
}

void main() {
  test('current model uses one bounded nine-point request and retains heights, provenance and timestamps', () async {
    final requests = <http.Request>[];
    final service = WindFieldService(
      client: MockClient((r) async {
        requests.add(r);
        return reply(response());
      }),
      now: () => now,
    );
    addTearDown(service.dispose);
    final data = await service.load(
      latitude: 46.7,
      longitude: 8.4,
      mode: WindTimeMode.current,
    );
    expect(requests.length, 1);
    expect(
      requests.single.url.queryParameters['current'],
      contains('wind_direction_180m'),
    );
    expect(requests.single.url.queryParameters['hourly'], isNull);
    expect(data.nodes.length, 9);
    expect(data.nodes[4].levels.length, 4);
    expect(data.nodes[4].levels[0].fromDegrees, 270);
    expect(data.nodes[4].sourceLatitude, 46.7);
    expect(data.validAtUtc, now);
    expect(data.expiresUtc, now.add(const Duration(minutes: 30)));
    expect(data.toJson()['source'], contains('Open-Meteo'));
  });
  test('forecast loads a UTC hour without substituting current wind; invalid horizon is rejected before fetching', () async {
    var calls = 0;
    final target = now.add(const Duration(hours: 2));
    final service = WindFieldService(
      client: MockClient((r) async {
        calls++;
        expect(r.url.queryParameters['start_hour'], '2026-10-28T14:00');
        expect(r.url.queryParameters['current'], isNull);
        return reply(response(hourly: true, at: target));
      }),
      now: () => now,
    );
    addTearDown(service.dispose);
    final data = await service.load(
      latitude: 46.7,
      longitude: 8.4,
      mode: WindTimeMode.forecast,
      forecastUtc: target.add(const Duration(minutes: 20)),
    );
    expect(data.validAtUtc, target);
    expect(data.mode, WindTimeMode.forecast);
    expect(data.expiresUtc, now.add(const Duration(hours: 3)));
    await expectLater(
      service.load(
        latitude: 46.7,
        longitude: 8.4,
        mode: WindTimeMode.forecast,
        forecastUtc: now.add(const Duration(days: 10)),
      ),
      throwsException,
    );
    expect(calls, 1);
    await expectLater(
      service.load(
        latitude: 84,
        longitude: 179.8,
        radiusMeters: 5000,
        mode: WindTimeMode.current,
      ),
      throwsException,
    );
    expect(calls, 1);
  });
  test('missing levels stay unknown and different times never merge into one field', () async {
    final body = response();
    body[0]['current']['wind_speed_80m'] = null;
    body[1]['current']['time'] = now
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    final service = WindFieldService(
      client: MockClient((_) async => reply(body)),
      now: () => now,
    );
    addTearDown(service.dispose);
    final data = await service.load(
      latitude: 46.7,
      longitude: 8.4,
      mode: WindTimeMode.current,
    );
    expect(data.nodes[0].levels.map((l) => l.agl), [10, 120, 180]);
    expect(data.nodes[1].levels, isEmpty);
    expect(data.usableNodes, 8);
  });
  test('unsupported units, oversized data, bad counts and old current values are rejected', () async {
    final wrong = response();
    wrong[0]['current_units']['wind_speed_10m'] = 'km/h';
    for (final body in [
      jsonEncode(wrong),
      jsonEncode(response().take(8).toList()),
      jsonEncode(response(at: now.subtract(const Duration(hours: 2)))),
      ' ' * (2 * 1024 * 1024 + 1),
    ]) {
      final service = WindFieldService(
        client: MockClient((_) async => http.Response(body, 200)),
        now: () => now,
      );
      await expectLater(
        service.load(
          latitude: 46.7,
          longitude: 8.4,
          mode: WindTimeMode.current,
        ),
        throwsException,
      );
      service.dispose();
    }
  });
  test('wind is opt-in; flags and renderer reload reuse the snapshot, and failed refresh retains it until expiry', () async {
    var fail = false, calls = 0;
    var time = now;
    final commands = <Map<String, dynamic>>[];
    final service = WindFieldService(
      client: MockClient((_) async {
        calls++;
        return fail ? http.Response('', 503) : reply(response());
      }),
      now: () => time,
    );
    final wind = WindMapController(
      service: service,
      now: () => time,
      send: (c) async => commands.add(c),
    );
    addTearDown(wind.dispose);
    await wind.rendererReady();
    expect(calls, 0);
    expect(commands, isEmpty);
    await wind.load(
      latitude: 46.7,
      longitude: 8.4,
      timeMode: WindTimeMode.current,
    );
    final initial = wind.snapshot;
    await wind.flags(physics: true);
    await wind.rendererReady();
    expect(calls, 1);
    expect(commands.last['affectFlight'], true);
    fail = true;
    await wind.refresh();
    expect(identical(wind.snapshot, initial), true);
    expect(wind.refreshFailed, true);
    time = now.add(const Duration(minutes: 31));
    expect(wind.expired, true);
    await wind.load(
      latitude: 46.7,
      longitude: 8.4,
      timeMode: WindTimeMode.forecast,
      timeUtc: time.add(const Duration(hours: 2)),
    );
    expect(wind.snapshot, isNull);
    expect(commands.last['field'], isNull);
  });
  test(
    'cancelled old requests cannot replace newer coordinates or data',
    () async {
      final old = Completer<http.Response>();
      var calls = 0;
      final wind = WindMapController(
        send: (_) async {},
        service: WindFieldService(
          client: MockClient((_) async {
            calls++;
            return calls == 1 ? old.future : reply(response(speed: 4));
          }),
          now: () => now,
        ),
        now: () => now,
      );
      addTearDown(wind.dispose);
      final first = wind.load(
        latitude: 46.7,
        longitude: 8.4,
        timeMode: WindTimeMode.current,
      );
      await Future<void>.delayed(Duration.zero);
      await wind.load(
        latitude: 47,
        longitude: 9,
        timeMode: WindTimeMode.current,
      );
      old.complete(reply(response(speed: 20)));
      await first;
      expect(wind.snapshot!.centerLongitude, 9);
      expect(wind.snapshot!.nodes[4].levels[0].speedMs, 4);
      expect(wind.loading, false);
    },
  );
  test('a superseded renderer acknowledgement cannot start an old download and cancel the new one', () async {
    var pushes = 0, loads = 0;
    final gate = Completer<void>();
    final wind = WindMapController(
      now: () => now,
      send: (_) async {
        if (++pushes == 1) await gate.future;
      },
      service: ImmediateWindService(() => now, () => loads++),
    );
    addTearDown(wind.dispose);
    final old = wind.load(
      latitude: 46.7,
      longitude: 8.4,
      timeMode: WindTimeMode.current,
    );
    await Future<void>.delayed(Duration.zero);
    await wind.load(latitude: 47, longitude: 9, timeMode: WindTimeMode.current);
    gate.complete();
    await old;
    expect(loads, 1);
    expect(wind.snapshot!.centerLongitude, 9);
  });
  testWidgets(
    'automatic current refresh keeps its deadline across flag changes and pauses in background',
    (tester) async {
      var time = now, calls = 0;
      final wind = WindMapController(
        send: (_) async {},
        now: () => time,
        service: ImmediateWindService(() => time, () => calls++),
      );
      addTearDown(wind.dispose);
      await wind.flags(arrows: true);
      await wind.load(
        latitude: 46.7,
        longitude: 8.4,
        timeMode: WindTimeMode.current,
      );
      time = time.add(const Duration(minutes: 14));
      await tester.pump(const Duration(minutes: 14));
      await wind.flags(physics: true);
      time = time.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();
      expect(calls, 2);
      wind.foreground(false);
      time = time.add(const Duration(minutes: 20));
      await tester.pump(const Duration(minutes: 20));
      expect(calls, 2);
      wind.foreground(true);
      time = time.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(calls, 3);
      wind.foreground(false);
    },
  );
  test('flight wind queries the current drone instead of a previous selected map point; HUD events reach controls', () async {
    final globe = GlobeController(
      windService: WindFieldService(
        client: MockClient((_) async => reply(response())),
        now: () => now,
      ),
    );
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    peer.emit({
      'type': 'point-selected',
      'latitude': 46.7,
      'longitude': 8.4,
      'altitude': 1000,
    });
    peer.emit({'type': 'simulation-state', 'active': true, 'pending': false});
    expect(globe.simulationActive, true);
    peer.onCommand = (command) {
      if (command['type'] == 'query-wind-center') {
        peer.acknowledge(command, result: {'latitude': 47, 'longitude': 9});
      }
    };
    await globe.loadWindAtSelection(mode: WindTimeMode.current);
    expect(globe.wind.snapshot!.centerLatitude, 47);
    expect(globe.wind.snapshot!.centerLongitude, 9);
    var requests = 0;
    globe.onWindSettingsRequested = () => requests++;
    peer.emit({'type': 'wind-settings-request'});
    peer.emit({
      'type': 'wind-flags-changed',
      'visible': true,
      'affectFlight': true,
    });
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(globe.wind.visible, true);
    expect(globe.wind.affectFlight, true);
    peer.emit({'type': 'wind-layer-status', 'state': 'terrainPending'});
    expect(globe.wind.rendererState, 'terrainPending');
    await globe.wind.flags(arrows: false, physics: false);
  });
  testWidgets(
    'narrow wind sheet loads only on request and enables independent display and physics flags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      final globe = GlobeController(
        windService: WindFieldService(
          client: MockClient((_) async {
            calls++;
            return reply(response());
          }),
          now: () => now,
        ),
      );
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.emit({
        'type': 'point-selected',
        'latitude': 46.7,
        'longitude': 8.4,
        'altitude': 1000,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WindControlsLauncher(globe: globe)),
        ),
      );
      await tester.tap(find.text('3D-Wind und Prognose'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(
        find.widgetWithText(SwitchListTile, '3D-Windpfeile anzeigen'),
      );
      await tester.pumpAndSettle();
      final load = find.text('Winddaten für Punkt / Ansicht laden');
      await tester.ensureVisible(load);
      await tester.runAsync(() async {
        await tester.tap(load);
        await Future.doWhile(() async {
          if (!globe.wind.loading) return false;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          return true;
        }).timeout(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(globe.wind.snapshot, isNotNull);
      expect(peer.commands.last['type'], 'set-wind-field');
      expect(peer.commands.last['visible'], true);
      final force = find.widgetWithText(
        SwitchListTile,
        'Wind im Flugsimulator berücksichtigen',
      );
      await tester.ensureVisible(force);
      await tester.tap(force);
      await tester.pumpAndSettle();
      expect(globe.wind.affectFlight, true);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await globe.wind.flags(arrows: false, physics: false);
    },
  );
}
