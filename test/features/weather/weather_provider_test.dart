import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/weather/weather_models.dart';
import 'package:fpvmanager/features/weather/weather_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> assetsFor(String timestamp, {Iterable<String>? codes}) => {
  for (final code in codes ?? MeteoSwissWeatherProvider.codes.keys)
    'vnut12.lssw.$timestamp.$code.csv': {
      'href':
          'https://data.geo.admin.ch/forecasts/vnut12.lssw.$timestamp.$code.csv',
    },
};

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);
  Object listing(Map<String, Object?> assets) => {
    'features': [
      {
        'id': '20261023-ch',
        'properties': {'datetime': '2026-10-23T04:00:00Z'},
        'assets': assets,
      },
    ],
  };

  test(
    'latest complete run wins independently of asset order and item timestamp',
    () {
      final result = selectMeteoSwissForecastRun(
        listing({
          ...assetsFor('202610230000'),
          ...assetsFor('202610231100'),
          ...assetsFor('202610231200', codes: ['fu3010h0']),
        }),
        nowUtc: now,
      );
      expect(result.issuedUtc, DateTime.utc(2026, 10, 23, 11));
      expect(result.assets, hasLength(5));
      expect(
        result.assets.values.every((uri) => uri.path.contains('202610231100')),
        isTrue,
      );
    },
  );

  test('incomplete runs cannot be combined into a supposedly complete run', () {
    expect(
      () => selectMeteoSwissForecastRun(
        listing({
          ...assetsFor('202610231100', codes: ['fu3010h0', 'fu3010h1']),
          ...assetsFor(
            '202610231200',
            codes: ['dkl010h0', 'rre150h0', 'tre200h0'],
          ),
        }),
        nowUtc: now,
      ),
      throwsA(isA<WeatherException>()),
    );
  });

  test(
    'unsupported hosts and implausibly future issue times cannot supply a run',
    () {
      final assets = assetsFor('202610231100');
      assets['vnut12.lssw.202610231100.fu3010h0.csv'] = {
        'href': 'https://example.invalid/forecast.csv',
      };
      expect(
        () => selectMeteoSwissForecastRun(listing(assets), nowUtc: now),
        throwsA(isA<WeatherException>()),
      );
      expect(
        () => selectMeteoSwissForecastRun(
          listing(assetsFor('202610231300')),
          nowUtc: now,
        ),
        throwsA(isA<WeatherException>()),
      );
      expect(
        () => selectMeteoSwissForecastRun({'features': 'bad'}, nowUtc: now),
        throwsA(isA<WeatherException>()),
      );
    },
  );

  test('MeteoSwiss live-shaped fixtures retain issue time, point identity, SI units and nulls', () async {
    var catalogRequests = 0, csvRequests = 0;
    var run = '202610231100';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/items')) {
        catalogRequests++;
        return http.Response(
          jsonEncode(
            listing({...assetsFor('202610230000'), ...assetsFor(run)}),
          ),
          200,
        );
      }
      if (request.url.path.endsWith('_meta_point.csv')) {
        return http.Response(
          'point_id;point_type_id;point_name;point_coordinates_wgs84_lat;point_coordinates_wgs84_lon\n100;1;Hill;46;8\n100;2;Village;47;8\n',
          200,
        );
      }
      csvRequests++;
      expect(request.url.path, contains(run));
      final code = request.url.path.split('.')[3];
      final value = switch (code) {
        'fu3010h0' => '18',
        'fu3010h1' => '36',
        'dkl010h0' => '240',
        'rre150h0' => '-',
        'tre200h0' => '-5',
        _ => throw StateError(code),
      };
      return http.Response(
        'point_id;point_type_id;Date;$code\n100;1;202610231300;999\n100;2;202610231300;$value\n',
        200,
      );
    });
    final provider = CachedWeatherProvider(
      MeteoSwissWeatherProvider(client: client, now: () => now),
    );
    addTearDown(client.close);
    addTearDown(provider.dispose);
    final first = await provider.forecast(47, 8);
    expect(first.sourceIssuedUtc, DateTime.utc(2026, 10, 23, 11));
    expect(first.samples.single.windMs, 5);
    expect(first.samples.single.gustMs, 10);
    expect(first.samples.single.precipitationMm, isNull);
    expect(first.samples.single.temperatureC, -5);
    expect(first.samples.single.visibilityMeters, isNull);
    expect(first.samples.single.wind80mMs, isNull);
    expect(first.locationDescription, contains('type 2'));
    await provider.forecast(47, 8);
    // Different requested coordinates mapping to the same official point reuse
    // its parsed result without downloading the five national CSVs again.
    final nearby = await provider.forecast(47.002, 8);
    expect(first.distanceToSourceKm, 0);
    expect(nearby.distanceToSourceKm, greaterThan(.2));
    expect(catalogRequests, 1);
    expect(csvRequests, 5);
    run = '202610231200';
    final refreshed = await provider.forecast(47, 8, forceRefresh: true);
    expect(refreshed.sourceIssuedUtc, now);
    expect(catalogRequests, 2);
    expect(csvRequests, 10);
  });

  test(
    'failed forced refresh retains valid cached data and can recover',
    () async {
      var fail = false, calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (fail) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2026-10-23T13:00'],
              'wind_speed_10m': [4],
            },
          }),
          200,
        );
      });
      final provider = CachedWeatherProvider(
        OpenMeteoWeatherProvider(client: client),
      );
      addTearDown(client.close);
      addTearDown(provider.dispose);
      final first = await provider.forecast(47, 8);
      fail = true;
      await expectLater(
        provider.forecast(47, 8, forceRefresh: true),
        throwsA(isA<WeatherException>()),
      );
      expect(await provider.forecast(47, 8), same(first));
      fail = false;
      expect(
        await provider.forecast(47, 8, forceRefresh: true),
        isNot(same(first)),
      );
      expect(calls, 3);
    },
  );

  test(
    'MeteoSwiss malformed metadata and HTTP errors remain explicit',
    () async {
      for (final response in [
        http.Response('error', 429),
        http.Response('unknown;columns\n1;2', 200),
      ]) {
        final client = MockClient((_) async => response);
        final provider = MeteoSwissWeatherProvider(
          client: client,
          now: () => now,
        );
        await expectLater(
          provider.forecast(47, 8),
          throwsA(isA<WeatherException>()),
        );
        client.close();
        provider.dispose();
      }
    },
  );
}
