import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_models.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_parser.dart';

const stationMetadata = '''station_abbr;station_name;station_canton;station_coordinates_wgs84_lat;station_coordinates_wgs84_lon;station_height_masl;station_url_de
PZH;Zürich;ZH;47.40;8.55;408;https://www.meteoschweiz.admin.ch/station
PLS;Lausanne;VD;46.52;6.62;520;
PZH;Other;ZH;47.40;8.55;408;
BAD;Outside;XX;88;200;0;
''';

const hourly = '''station_abbr;reference_timestamp;kabetuh0;khpoach0;kaalnuh0;kacoryh0;kafaguh0;kafraxh0;kaquerh0;unknownh0
PZH;03.11.2026 12:00;0;3;12;1;;7;-1;55
PZH;03.11.2026 11:00;5;5;5;5;5;5;5;66
PLS;03.11.2026 12:00;80;80;80;80;80;80;80;80
PZH;32.11.2026 10:00;6;6;6;6;6;6;6;6
PZH;03.11.2022 12:00;9;9;9;9;9;9;9;9
''';

void main() {
  test(
    'official station metadata preserves ID, coordinates, canton and URL',
    () {
      final stations = parsePollenStations(stationMetadata);
      expect(stations, hasLength(2));
      final zurich = stations.first;
      expect(zurich.id, 'PZH');
      expect(zurich.name, 'Zürich');
      expect(zurich.canton, 'ZH');
      expect(zurich.latitude, 47.4);
      expect(zurich.heightMeters, 408);
      expect(zurich.detailsUrl?.scheme, 'https');
    },
  );

  test('hourly units and 7 supported types are distinct from missing data', () {
    final result = parsePollenHourlyCsv(hourly, 'PZH');
    expect(result.samples, hasLength(2));
    final sample = result.samples.first;
    expect(sample.timeUtc, DateTime.utc(2026, 11, 3, 12));
    expect(sample.values[PollenTaxon.birch], 0);
    expect(sample.values[PollenTaxon.beech], isNull);
    expect(sample.values[PollenTaxon.oak], isNull);
    expect(sample.values[PollenTaxon.alder], 12);
    expect(PollenTaxon.birch.hourlyCode, 'kabetuh0');
    expect(PollenTaxon.values, hasLength(7));
    expect(result.unknownParameters, ['unknownh0']);
  });

  test('manual 2022 observations cannot leak into hourly automatic data', () {
    expect(
      pollenMethodAt(DateTime.utc(2022, 12, 31)),
      PollenMeasurementMethod.manual,
    );
    expect(
      pollenMethodAt(DateTime.utc(2023)),
      PollenMeasurementMethod.automatic,
    );
    expect(
      parsePollenHourlyCsv(hourly, 'PZH').samples,
      everyElement(
        predicate<PollenSample>(
          (s) => s.method == PollenMeasurementMethod.automatic,
        ),
      ),
    );
  });

  test('bad schema, unsafe STAC URL and missing h_now are rejected', () {
    expect(
      () => parsePollenHourlyCsv('bad;header\na;b', 'PZH'),
      throwsFormatException,
    );
    expect(
      () => pollenAssetFromStac({
        'assets': {
          'h_now': {
            'href': 'https://elsewhere.example/ogd-pollen_pzh_h_now.csv',
          },
        },
      }, 'PZH'),
      throwsFormatException,
    );
    expect(
      () => pollenAssetFromStac({'assets': {}}, 'PZH'),
      throwsFormatException,
    );
  });

  test('STAC discovery retains official URL and publication time', () {
    final asset = pollenAssetFromStac({
      'properties': {'updated': '2026-11-03T12:22:00Z'},
      'assets': {
        'h_now': {
          'href': 'https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/pzh/ogd-pollen_pzh_h_now.csv',
        },
      },
    }, 'PZH');
    expect(asset.url.host, 'data.geo.admin.ch');
    expect(asset.updatedUtc, DateTime.utc(2026, 11, 3, 12, 22));
  });

  test(
    'snapshot serialization retains distinct source and observation times',
    () {
      final station = parsePollenStations(stationMetadata).first;
      final snap = PollenSnapshot(
        station: station,
        samples: parsePollenHourlyCsv(hourly, 'PZH').samples,
        fetchedUtc: DateTime.utc(2026, 11, 3, 12, 30),
        publishedUtc: DateTime.utc(2026, 11, 3, 12, 25),
        assetUrl: Uri.parse(
          'https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/pzh/ogd-pollen_pzh_h_now.csv',
        ),
      );
      final restored = decodePollenSnapshot(encodePollenSnapshot(snap));
      expect(restored.station.id, 'PZH');
      expect(restored.latestObservedUtc, DateTime.utc(2026, 11, 3, 12));
      expect(restored.publishedUtc, DateTime.utc(2026, 11, 3, 12, 25));
      expect(restored.samples.first.values[PollenTaxon.birch], 0);
      expect(restored.samples.first.values[PollenTaxon.beech], isNull);
    },
  );
}
