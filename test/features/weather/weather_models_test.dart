import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/weather/weather_models.dart';
import 'package:fpvmanager/features/weather/weather_providers.dart';
import 'package:fpvmanager/features/weather/fpv_suitability.dart';
import 'package:fpvmanager/features/weather/weather_overlay_service.dart';

void main() {
  final instant = DateTime.utc(2026, 10, 23, 12);
  test('Open-Meteo parser keeps provider and SI values separate', () {
    final result = parseOpenMeteoForecast({
      'hourly': {
        'time': ['2026-10-23T12:00', '2026-10-23T13:00'],
        'wind_speed_10m': [4.2, null],
        'wind_gusts_10m': [7, 8],
        'wind_direction_10m': [200, 210],
        'precipitation': [0, 0.5],
        'temperature_2m': [5, 7],
        'visibility': [8000, 9000],
        'wind_speed_80m': [9, 10],
      },
    }, instant);
    expect(result.provider, WeatherProviderId.openMeteo);
    expect(result.samples.first.windMs, 4.2);
    expect(result.samples.first.wind80mMs, 9);
    expect(result.samples[1].windMs, isNull);
    expect(result.samples.first.timeUtc.isUtc, isTrue);
    expect(result.at(instant.add(const Duration(hours: 4))), isNull);
  });

  test('Missing and stale forecasts cannot be rated favorable', () {
    WeatherForecast forecast(
      List<WeatherSample> samples, {
      DateTime? retrieved,
    }) => WeatherForecast(
      provider: WeatherProviderId.meteoSwiss,
      source: 'Source: MeteoSwiss',
      sourceUrl: 'https://example.org',
      retrievedUtc: retrieved ?? instant,
      samples: samples,
      modelResolution: '1 hour',
      locationDescription: 'fixture',
    );
    final sample = WeatherSample(
      timeUtc: instant,
      windMs: 4,
      gustMs: 7,
      precipitationMm: 0,
      temperatureC: 8,
    );
    final good = evaluateFpvWeather(
      forecast([sample]),
      instant,
      const FpvWeatherCriteria(),
      nowUtc: instant,
    );
    expect(good.assessment, FpvWeatherAssessment.favorableForecast);
    expect(good.legallyCleared, isFalse);
    final missing = evaluateFpvWeather(
      forecast([
        WeatherSample(
          timeUtc: instant,
          windMs: 3,
          gustMs: null,
          precipitationMm: 0,
        ),
      ]),
      instant,
      const FpvWeatherCriteria(),
      nowUtc: instant,
    );
    expect(missing.assessment, FpvWeatherAssessment.insufficient);
    final rain = evaluateFpvWeather(
      forecast([
        WeatherSample(
          timeUtc: instant,
          windMs: 4,
          gustMs: 7,
          precipitationMm: 2,
        ),
      ]),
      instant,
      const FpvWeatherCriteria(),
      nowUtc: instant,
    );
    expect(rain.assessment, FpvWeatherAssessment.unsuitable);
    final stale = evaluateFpvWeather(
      forecast([sample], retrieved: instant.subtract(const Duration(days: 2))),
      instant,
      const FpvWeatherCriteria(),
      nowUtc: instant,
    );
    expect(stale.assessment, FpvWeatherAssessment.insufficient);
    final visibilityMissing = evaluateFpvWeather(
      forecast([sample]),
      instant,
      const FpvWeatherCriteria(minimumVisibilityMeters: 1000),
      nowUtc: instant,
    );
    expect(visibilityMissing.assessment, FpvWeatherAssessment.insufficient);
  });

  test('Official MeteoSwiss metadata uses combined point ID and type', () {
    final metadata =
        'point_id;point_type_id;point_name;point_coordinates_wgs84_lat;point_coordinates_wgs84_lon\n'
        '100;1;Mountain;46.0;8.0\n100;2;Village;47.0;9.0\n';
    final nearest = nearestMeteoSwissPoint({
      'csv': metadata,
      'lat': 47.0,
      'lon': 9.0,
    });
    expect(nearest!['type'], '2');
    final rows = extractMeteoSwissRows({
      'csv':
          'point_id;point_type_id;Date;fu3010h0\n'
          '100;1;202610231200;36\n'
          '100;2;202610231200;18\n',
      'pointId': '100',
      'pointType': '2',
      'parameter': 'fu3010h0',
    });
    expect(rows.length, 1);
    expect(finiteWeatherNumber(rows.single['value'])! / 3.6, closeTo(5, 0.01));
    expect(parseWeatherUtc(rows.single['time']!), instant);
  });

  test(
    'HTTP errors are informative and do not result in forecast values',
    () async {
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((_) async => http.Response('rate limit', 429)),
      );
      await expectLater(
        provider.forecast(47, 8),
        throwsA(isA<WeatherException>()),
      );
    },
  );

  test('Cache shares concurrent identical forecast calls', () async {
    var calls = 0;
    final completer = Completer<http.Response>();
    final provider = CachedWeatherProvider(
      OpenMeteoWeatherProvider(
        client: MockClient((_) {
          calls++;
          return completer.future;
        }),
      ),
    );
    final first = provider.forecast(47, 8);
    final second = provider.forecast(47, 8);
    // Coalescing is synchronous, while MockClient dispatches its request
    // asynchronously. Give the HTTP callback a turn before counting calls.
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    completer.complete(
      http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2026-10-23T12:00'],
            'wind_speed_10m': [4],
          },
        }),
        200,
      ),
    );
    expect((await first).samples.length, 1);
    expect((await second).samples.length, 1);
    await provider.forecast(47, 8);
    expect(calls, 1);
  });

  test('Weather map uses 49 point samples without interpolation', () async {
    final service = WeatherOverlayService(
      now: () => instant,
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('apikey'), isFalse);
        expect(request.url.queryParameters['latitude']!.split(',').length, 49);
        final series = List.generate(
          49,
          (_) => {
            'hourly_units': {'wind_speed_10m': 'm/s'},
            'hourly': {
              'time': ['2026-10-23T12:00'],
              'wind_speed_10m': [5.0],
            },
          },
        );
        return http.Response(jsonEncode(series), 200);
      }),
    );
    final grid = await service.load(
      latitude: 47,
      longitude: 8,
      timeUtc: instant,
      kind: WeatherOverlayKind.wind,
    );
    expect(grid.cells.length, 49);
    expect(grid.cells.first.value, 5);
    expect(grid.toGlobeCommand()['source'], contains('Open-Meteo'));
  });
}
