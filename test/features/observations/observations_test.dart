import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/core/osint/osint_dataset_store.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/observations/meteo_station_provider.dart';
import 'package:fpvmanager/features/observations/hydro_station_provider.dart';
import 'package:fpvmanager/features/observations/station_observation.dart';

const metadata =
    'station_abbr;station_name;station_canton;station_wigos_id;station_height_masl;station_coordinates_wgs84_lat;station_coordinates_wgs84_lon;station_url_de\nABO;Adelboden;BE;0-20000-06735;1321;46.491703;7.560703;https://www.meteoschweiz.admin.ch/\nAEG;Oberägeri;ZG;0-20000-06676;724;47.133636;8.608206;https://www.meteoschweiz.admin.ch/\n';
const measured =
    'Station/Location;Date;tre200s0;rre150z0;dkl010z0;fu3010z0;fu3010z1\nABO;202610301200;-4.2;0;150;36;72\nAEG;202610301150;-;-;-;-;-\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('MeteoSwiss preserves source units, altitude, time and missing measurements', () {
    final snapshot = parseMeteoStations((metadata, measured)),
        stations = readStations(snapshot);
    expect(stations.first.id, 'ABO');
    expect(stations.first.elevation, 1321);
    expect(
      stations.first.readings.singleWhere((r) => r.parameter == 'Wind').unit,
      'km/h',
    );
    expect(
      stations.first.readings.singleWhere((r) => r.parameter == 'Wind').value,
      36,
    );
    expect(
      stations.first.readings
          .singleWhere((r) => r.parameter == 'Niederschlagssumme')
          .intervalMinutes,
      10,
    );
    expect(stations.first.readings.first.value, -4.2);
    expect(stations.last.readings, isEmpty);
    expect(stations.first.readings.first.atUtc, DateTime.utc(2026, 10, 30, 12));
    expect(
      stations.first.readings.first.quality,
      contains('nicht bereitgestellt'),
    );
    expect(decodeStationCsv(latin1.encode('Oberägeri')), 'Oberägeri');
    expect(stationCsv('name;value\n"a;b";"1"\n').single['name'], 'a;b');
    expect(
      () => parseMeteoStations((
        metadata,
        measured.replaceAll('202610301200', '202602311200'),
      )),
      throwsFormatException,
    );
    expect(() => stationCsv('a;b\n"unterminated;2'), throwsFormatException);
  });

  test('MeteoSwiss coalesces retrievals, respects cadence and conditionally revalidates native snapshots', () async {
    var now = DateTime.utc(2026, 10, 30, 12, 5), calls = 0, notModified = false;
    final p = MeteoStationProvider(
      now: () => now,
      client: MockClient((r) async {
        calls++;
        if (r.url.path.endsWith('stations.csv')) {
          return http.Response.bytes(latin1.encode(metadata), 200);
        }
        if (notModified) {
          expect(
            r.headers['If-Modified-Since'],
            'Fri, 30 Oct 2026 12:00:00 GMT',
          );
          return http.Response('', 304);
        }
        return http.Response(
          measured,
          200,
          headers: {'last-modified': 'Fri, 30 Oct 2026 12:00:00 GMT'},
        );
      }),
    );
    addTearDown(p.dispose);
    final first = p.fetch(), second = p.fetch();
    expect(identical(first, second), isTrue);
    final initial = await first;
    await second;
    expect(calls, 2);
    await p.fetch(forceRefresh: true);
    expect(calls, 2);
    now = now.add(const Duration(minutes: 11));
    notModified = true;
    final updated = await p.fetch(forceRefresh: true);
    expect(calls, 3);
    expect(updated.fetchedAtUtc, initial.fetchedAtUtc);
    expect(updated.lastCheckedAtUtc, now);
    expect(
      readStations(updated.data).first.readings.first.atUtc,
      DateTime.utc(2026, 10, 30, 12),
    );
  });

  test('licensed stations survive restart; refresh errors retain dated previous data and no-store is honored', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = JsonOsintDatasetStore(
      database: () => db,
      storageTerms: MeteoStationProvider.defaultSource.licenseUri!,
    );
    var now = DateTime.utc(2026, 10, 30, 12, 5), fail = false, noStore = false;
    http.Client client() => MockClient((r) async {
      if (r.url.path.endsWith('stations.csv')) {
        return http.Response(metadata, 200, headers: ifHeader(noStore));
      }
      return fail ? http.Response('down', 503) : http.Response(measured, 200);
    });
    var p = MeteoStationProvider(
      now: () => now,
      persistentCache: store,
      client: client(),
    );
    await p.fetch();
    p.dispose();
    now = now.add(const Duration(minutes: 40));
    p = MeteoStationProvider(
      now: () => now,
      persistentCache: store,
      client: client(),
    );
    await p.loadCached();
    expect(p.status.dataState, OsintDataState.stale);
    final previous = p.status.dataset;
    fail = true;
    await expectLater(
      p.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(p.status.dataset, same(previous));
    expect(p.status.dataState, OsintDataState.refreshFailed);
    p.dispose();
    fail = false;
    noStore = true;
    final fresh = MeteoStationProvider(
      now: () => now,
      persistentCache: store,
      client: client(),
    );
    await fresh.clearCache();
    final downloaded = await fresh.fetch(forceRefresh: true);
    expect(downloaded.persistable, isFalse);
    fresh.dispose();
    final offline = MeteoStationProvider(
      now: () => now,
      persistentCache: store,
      client: client(),
    );
    addTearDown(offline.dispose);
    await offline.loadCached();
    expect(offline.status.dataset, isNull);
  });

  test('hydrology keeps units, validation status, independent live values and unknown references', () {
    final stations = parseHydroMetadata([
      {
        'no': '2004',
        'name': 'Station',
        'latitude': 47.0,
        'longitude': 8.0,
        'elevation': null,
        'status': 'Aufgebaut',
      },
    ]);
    final now = DateTime.utc(2026, 10, 30, 12);
    final data = parseHydroReadings(stations, {
      'data_10min_mean': [
        {
          'station': {'no': '2004'},
          'parameterName': 'W',
          'value': 420.125,
          'unitSymbol': 'm ü.M.',
          'timestamp': '2026-10-30T11:40:00Z',
          'releaseState': '1',
        },
      ],
      'data_live': [
        {
          'stationNo': '2004',
          'parameterName': 'W',
          'value': 420.2,
          'timestamp': '2026-10-30T11:50:00Z',
          'releaseStatus': 0,
        },
        {
          'stationNo': '2004',
          'parameterName': 'WT',
          'value': null,
          'timestamp': '2026-10-30T11:50:00Z',
          'releaseStatus': 0,
        },
      ],
    }, now: now);
    final values = readStations(data).single.readings;
    expect(values, hasLength(2));
    expect(values.first.unit, 'm ü.M.');
    expect(values.first.quality, contains('provisorisch'));
    expect(values.last.unit, 'm ü.M.');
    expect(values.last.quality, contains('unkorrigierter'));
    expect(readStations(data).single.elevation, isNull);
    expect(() => observationUtc('2026-10-30T12:00:00'), throwsFormatException);
  });

  test('unchanged station metadata is checked once per day rather than on every later observation refresh', () async {
    var now = DateTime.utc(2026, 10, 30, 12, 5), metadataCalls = 0;
    final provider = MeteoStationProvider(
      now: () => now,
      client: MockClient((r) async {
        if (r.url.path.endsWith('stations.csv')) {
          metadataCalls++;
          return http.Response(metadata, 200);
        }
        return http.Response(measured, 200);
      }),
    );
    addTearDown(provider.dispose);
    await provider.fetch();
    now = now.add(const Duration(hours: 25));
    final checked = await provider.fetch(forceRefresh: true);
    expect(checked.data['metadataFetchedAtUtc'], now.toIso8601String());
    now = now.add(const Duration(minutes: 11));
    await provider.fetch(forceRefresh: true);
    expect(metadataCalls, 2);
  });

  test('BAFU no-store metadata stays excluded from persistence when reused for later readings', () async {
    var now = DateTime.utc(2026, 10, 30, 12, 5), metadataCalls = 0;
    final provider = HydroStationProvider(
      path: [MobilityPoint(47, 8)],
      now: () => now,
      client: MockClient((r) async {
        final query = (jsonDecode(r.body) as Map)['query'] as String;
        final metadataQuery = query.contains('stations(');
        if (metadataQuery) metadataCalls++;
        return http.Response(
          jsonEncode({
            'data': {
              'water': {
                'observations': metadataQuery
                    ? {
                        'stations': [
                          {
                            'no': '2004',
                            'name': 'Fixture',
                            'latitude': 47,
                            'longitude': 8,
                            'status': 'Aufgebaut',
                          },
                        ],
                      }
                    : {'data_10min_mean': [], 'data_live': []},
              },
            },
          }),
          200,
          headers: metadataQuery ? {'cache-control': 'no-store'} : {},
        );
      }),
    );
    addTearDown(provider.dispose);
    expect((await provider.fetch()).persistable, isFalse);
    now = now.add(const Duration(minutes: 11));
    expect((await provider.fetch(forceRefresh: true)).persistable, isFalse);
    expect(metadataCalls, 1);
  });

  test('BAFU provider uses bounded filtered products and recovers its last snapshot after restart', () async {
    final db = OsintCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = JsonOsintDatasetStore(
      database: () => db,
      storageTerms: HydroStationProvider.termsUri,
    );
    var now = DateTime.utc(2026, 10, 30, 12), calls = 0, fail = false;
    http.Client client() => MockClient((r) async {
      calls++;
      expect(r.url.toString(), 'https://data.bafu.admin.ch/api');
      if (fail) return http.Response('down', 503);
      final query = (jsonDecode(r.body) as Map)['query'] as String;
      if (query.contains('stations(where:')) {
        return http.Response(
          jsonEncode({
            'data': {
              'water': {
                'observations': {
                  'stations': [
                    {
                      'no': '2004',
                      'name': 'Station',
                      'latitude': 47,
                      'longitude': 8,
                      'elevation': null,
                      'status': 'Aufgebaut',
                    },
                  ],
                },
              },
            },
          }),
          200,
        );
      }
      expect(query, contains('stationNo:{_in:["2004"]}'));
      expect(query, contains('station:{no:{_in:["2004"]}}'));
      expect(query, contains('limit:2000'));
      expect(query, contains('timestamp:{_gte:'));
      return http.Response(
        jsonEncode({
          'data': {
            'water': {
              'observations': {
                'data_10min_mean': [
                  {
                    'station': {'no': '2004'},
                    'parameterName': 'Q',
                    'value': 12.5,
                    'unitSymbol': 'm³/s',
                    'timestamp': '2026-10-30T11:40:00Z',
                    'releaseState': '2',
                  },
                ],
                'data_live': [],
              },
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final path = [MobilityPoint(47, 8)];
    var p = HydroStationProvider(
      path: path,
      client: client(),
      now: () => now,
      persistentCache: store,
    );
    await p.fetch();
    expect(calls, 2);
    expect(
      readStations(p.status.dataset!.data).single.readings.single.unit,
      'm³/s',
    );
    await p.fetch(forceRefresh: true);
    expect(calls, 2);
    p.dispose();
    now = now.add(const Duration(minutes: 30));
    fail = true;
    p = HydroStationProvider(
      path: path,
      client: client(),
      now: () => now,
      persistentCache: store,
    );
    addTearDown(p.dispose);
    await p.loadCached();
    expect(p.status.dataset, isNotNull);
    await expectLater(
      p.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(
      readStations(p.status.dataset!.data).single.readings.single.value,
      12.5,
    );
    expect(p.status.dataState, OsintDataState.refreshFailed);
  });
}

Map<String, String> ifHeader(bool noStore) =>
    noStore ? {'cache-control': 'no-store'} : {};
