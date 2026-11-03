import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/weather/radar/meteo_radar_catalog.dart';

Map<String, dynamic> asset(String filename) => {
  'href': 'https://data.geo.admin.ch/radar/$filename',
  'type': 'application/x-hdf5',
};

Map<String, dynamic> day(Map<String, dynamic> assets, {String? updated}) => {
  'type': 'Feature',
  'id': '2026-11-03',
  'properties': {'updated': updated ?? '2026-11-03T12:45:00Z'},
  'assets': assets,
};

void main() {
  test(
    'supported STAC assets keep original URL, UTC time, product and quality',
    () {
      final frames = MeteoRadarCatalog.parseFeatures([
        day({
          'a': asset('RZC263071230VL.x01.h5'),
          'b': asset('CPC2630712258_00060.x01.h5'),
          'c': asset('TZC263071225VL.x01.h5'),
          'd': asset('CPCH2630712258_00060.x01.h5'),
          'e': asset('RZC263071235VL.x01.nc'),
        }),
      ]);
      expect(frames, hasLength(2));
      final radar = frames.firstWhere(
        (f) => f.product == MeteoRadarProduct.intensity,
      );
      final cpc = frames.firstWhere(
        (f) => f.product == MeteoRadarProduct.accumulation,
      );
      expect(radar.timestampUtc, DateTime.utc(2026, 11, 3, 12, 30));
      expect(radar.product.unit, 'mm/h');
      expect(radar.assetUrl.host, 'data.geo.admin.ch');
      expect(cpc.timestampUtc, DateTime.utc(2026, 11, 3, 12, 25));
      expect(cpc.product.unit, 'mm');
      expect(cpc.quality, 8);
      expect(cpc.toGlobeCommand()['source'], contains('MeteoSwiss'));
    },
  );

  test('duplicate observations and unsafe STAC hosts are excluded', () {
    final frames = MeteoRadarCatalog.parseFeatures([
      day({
        'a': asset('CPC2630712253_00060.x01.h5'),
        'b': asset('CPC2630712259_00060.x01.h5'),
        'c': {'href': 'https://evil.example/RZC263071230VL.x01.h5'},
      }),
    ]);
    expect(frames, hasLength(1));
    expect(frames.single.quality, 9);
  });

  test('gaps are not synthesized and missing assets remain missing', () {
    final frames = MeteoRadarCatalog.parseFeatures([
      day({
        'a': asset('RZC263071200VL.x01.h5'),
        'b': asset('RZC263071215VL.x01.h5'),
      }),
      day({}),
    ]);
    expect(frames, hasLength(2));
    expect(
      frames[0].timestampUtc.difference(frames[1].timestampUtc),
      const Duration(minutes: 15),
    );
    expect(MeteoRadarCatalog.parseFeatures([day({})]), isEmpty);
  });

  test('STAC requests are coalesced and cached without refetching', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'data.geo.admin.ch');
      expect(request.url.queryParameters['limit'], '3');
      return http.Response(
        jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            day({'a': asset('RZC263071230VL.x01.h5')}),
          ],
        }),
        200,
      );
    });
    final catalog = MeteoRadarCatalog(
      client: client,
      now: () => DateTime.utc(2026, 11, 3, 13),
    );
    final results = await Future.wait([catalog.discover(), catalog.discover()]);
    expect(results[0], hasLength(1));
    expect(calls, 1);
    await catalog.discover();
    expect(calls, 1);
    catalog.dispose();
  });

  test(
    'HTTP 429 and malformed responses fail rather than reuse false coverage',
    () async {
      final throttled = MeteoRadarCatalog(
        client: MockClient((_) async => http.Response('busy', 429)),
      );
      await expectLater(throttled.discover(), throwsA(isA<StateError>()));
      throttled.dispose();
      final malformed = MeteoRadarCatalog(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(malformed.discover(), throwsA(isA<FormatException>()));
      malformed.dispose();
    },
  );
}
