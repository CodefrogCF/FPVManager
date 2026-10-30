import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/weather/weather_overlay_service.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/weather/weather_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 30, 12);
  String body(WeatherOverlayKind kind, {String? unit, int missing = 0}) =>
      jsonEncode(
        List.generate(
          49,
          (i) => {
            'hourly_units': {kind.parameter: unit ?? kind.unit},
            'hourly': {
              'time': ['2026-10-30T12:00'],
              kind.parameter: [
                i < missing
                    ? null
                    : kind == WeatherOverlayKind.temperature
                    ? -12.5
                    : kind == WeatherOverlayKind.cloudCover
                    ? 80
                    : 2.0,
              ],
            },
          },
        ),
      );
  test('all supported raster variables retain their units, interval semantics and missing coverage', () async {
    for (final kind in WeatherOverlayKind.values) {
      final service = WeatherOverlayService(
        now: () => now,
        client: MockClient((r) async {
          expect(r.url.queryParameters['hourly'], kind.parameter);
          return http.Response(
            body(kind, missing: 2),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final layer = await service.load(
        latitude: 47,
        longitude: 8,
        timeUtc: now,
        kind: kind,
      );
      expect(layer.cells, hasLength(47));
      expect(layer.missingSamples, 2);
      expect(layer.toGlobeCommand()['units'], kind.unit);
      expect(layer.toGlobeCommand()['sourceType'], 'forecast');
      expect(
        layer.toGlobeCommand()['intervalMinutes'],
        kind.hourlyTotal ? 60 : 0,
      );
      if (kind == WeatherOverlayKind.temperature) {
        expect(layer.cells.first.value, -12.5);
      }
      expect(
        layer.dataset.cacheExpiresAtUtc,
        now.add(const Duration(minutes: 10)),
      );
      service.dispose();
    }
  });
  test(
    'unknown units, absent data and unsupported times are explicit errors',
    () async {
      final wrong = WeatherOverlayService(
        now: () => now,
        client: MockClient(
          (_) async =>
              http.Response(body(WeatherOverlayKind.snowfall, unit: 'mm'), 200),
        ),
      );
      await expectLater(
        wrong.load(
          latitude: 47,
          longitude: 8,
          timeUtc: now,
          kind: WeatherOverlayKind.snowfall,
        ),
        throwsA(isA<WeatherException>()),
      );
      wrong.dispose();
      final missing = WeatherOverlayService(
        now: () => now,
        client: MockClient(
          (_) async =>
              http.Response(body(WeatherOverlayKind.rain, missing: 49), 200),
        ),
      );
      await expectLater(
        missing.load(
          latitude: 47,
          longitude: 8,
          timeUtc: now,
          kind: WeatherOverlayKind.rain,
        ),
        throwsA(isA<WeatherException>()),
      );
      await expectLater(
        missing.load(
          latitude: 47,
          longitude: 8,
          timeUtc: now.add(const Duration(days: 10)),
          kind: WeatherOverlayKind.rain,
        ),
        throwsA(isA<WeatherException>()),
      );
      missing.dispose();
    },
  );
  test('duplicate requests are coalesced and bounded in-memory caching follows cache-control and expiration', () async {
    var time = now, calls = 0, noStore = false;
    final firstResponse = Completer<http.Response>();
    final service = WeatherOverlayService(
      now: () => time,
      client: MockClient((r) async {
        calls++;
        if (calls == 1) return firstResponse.future;
        return http.Response(
          body(WeatherOverlayKind.wind),
          200,
          headers: noStore ? {'cache-control': 'no-store'} : {},
        );
      }),
    );
    addTearDown(service.dispose);
    final first = service.load(
          latitude: 47,
          longitude: 8,
          timeUtc: now,
          kind: WeatherOverlayKind.wind,
        ),
        second = service.load(
          latitude: 47,
          longitude: 8,
          timeUtc: now,
          kind: WeatherOverlayKind.wind,
        );
    expect(identical(first, second), isTrue);
    firstResponse.complete(http.Response(body(WeatherOverlayKind.wind), 200));
    await first;
    await second;
    await service.load(
      latitude: 47,
      longitude: 8,
      timeUtc: now,
      kind: WeatherOverlayKind.wind,
    );
    expect(calls, 1);
    time = now.add(const Duration(minutes: 11));
    noStore = true;
    await service.load(
      latitude: 47,
      longitude: 8,
      timeUtc: now,
      kind: WeatherOverlayKind.wind,
    );
    expect(calls, 2);
    await service.load(
      latitude: 47,
      longitude: 8,
      timeUtc: now,
      kind: WeatherOverlayKind.wind,
    );
    expect(calls, 3);
  });
  test('renderer reload retains each variable and opacity without accepting incompatible forecast times', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await Future<void>.delayed(Duration.zero);
    Map<String, dynamic> command(
      String kind, {
      String time = '2026-10-30T14:00:00Z',
    }) => {
      'type': 'set-weather-overlay',
      'kind': kind,
      'timestampUtc': time,
      'source': 'Open-Meteo',
      'sourceType': 'forecast',
      'gridSpacingMeters': 1000,
      'opacity': .4,
      'cells': [
        {
          'west': 8.0,
          'south': 47.0,
          'east': 8.01,
          'north': 47.01,
          'value': 1.0,
        },
      ],
    };
    await globe.showWeatherOverlay(command('rain'));
    await globe.showWeatherOverlay(command('temperature'));
    await globe.setWeatherOpacity('rain', .2);
    expect(globe.weatherOverlays['rain']!['opacity'], .2);
    await expectLater(
      globe.showWeatherOverlay(
        command('snowfall', time: '2026-10-30T15:00:00Z'),
      ),
      throwsStateError,
    );
    peer.sessionId = 'renderer-2';
    peer.sequence = 0;
    peer.commands.clear();
    peer.ready();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      peer.commands
          .where((c) => c['type'] == 'set-weather-overlay')
          .map((c) => c['kind']),
      containsAll(['rain', 'temperature']),
    );
    await globe.clearWeatherOverlay(kind: 'rain');
    expect(globe.weatherOverlays.keys, ['temperature']);
    await globe.clearWeatherOverlay();
    expect(globe.weatherOverlayVisible, isFalse);
  });
}
