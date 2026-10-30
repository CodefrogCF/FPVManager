import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_source.dart';
import '../mobility/road_routing.dart';
import 'station_observation.dart';

String decodeStationCsv(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    const cp1252 = <int, int>{
      0x80: 0x20ac,
      0x82: 0x201a,
      0x83: 0x0192,
      0x84: 0x201e,
      0x85: 0x2026,
      0x86: 0x2020,
      0x87: 0x2021,
      0x88: 0x02c6,
      0x89: 0x2030,
      0x8a: 0x0160,
      0x8b: 0x2039,
      0x8c: 0x0152,
      0x8e: 0x017d,
      0x91: 0x2018,
      0x92: 0x2019,
      0x93: 0x201c,
      0x94: 0x201d,
      0x95: 0x2022,
      0x96: 0x2013,
      0x97: 0x2014,
      0x98: 0x02dc,
      0x99: 0x2122,
      0x9a: 0x0161,
      0x9b: 0x203a,
      0x9c: 0x0153,
      0x9e: 0x017e,
      0x9f: 0x0178,
    };
    return String.fromCharCodes(bytes.map((b) => cp1252[b] ?? b));
  }
}

List<Map<String, String>> stationCsv(String text) {
  if (text.length > 2 * 1024 * 1024) {
    throw const FormatException('Stationsdatei ist zu groß');
  }
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && (c == ';' || c == '\n')) {
      row.add(field.toString().replaceAll('\r', ''));
      field = StringBuffer();
      if (row.length > 100) {
        throw const FormatException('Zu viele Stationsspalten');
      }
      if (c == '\n') {
        if (row.any((f) => f.isNotEmpty)) rows.add(row);
        row = [];
        if (rows.length > 1001) {
          throw const FormatException('Zu viele Messstationen');
        }
      }
    } else {
      field.write(c);
      if (field.length > 4000) {
        throw const FormatException('Stationsfeld ist zu groß');
      }
    }
  }
  if (quoted) throw const FormatException('Unvollständiges CSV-Feld');
  row.add(field.toString().replaceAll('\r', ''));
  if (row.any((f) => f.isNotEmpty)) rows.add(row);
  if (rows.isEmpty || rows.length > 1001) {
    throw const FormatException('Leere oder zu große Stationsdatei');
  }
  final header = rows.first
      .map((h) => h.replaceFirst('\ufeff', '').trim())
      .toList();
  if (header.toSet().length != header.length) {
    throw const FormatException('Doppelte Stationsspalten');
  }
  return [
    for (final r in rows.skip(1))
      if (r.length == header.length)
        {for (var i = 0; i < header.length; i++) header[i]: r[i].trim()}
      else
        throw const FormatException('Unvollständige Stationszeile'),
  ];
}

Map<String, dynamic> parseMeteoStations((String, String) input) {
  final metadata = stationCsv(input.$1), values = stationCsv(input.$2);
  if (metadata.isEmpty ||
      !metadata.first.containsKey('station_abbr') ||
      !metadata.first.containsKey('station_coordinates_wgs84_lat') ||
      values.isEmpty ||
      !values.first.containsKey('Station/Location') ||
      !values.first.containsKey('Date')) {
    throw const FormatException('Nicht unterstütztes MeteoSwiss-CSV-Schema');
  }
  final byId = <String, Map<String, String>>{};
  for (final m in metadata) {
    final id = m['station_abbr']!;
    if (byId.containsKey(id)) {
      throw const FormatException('Doppelte Stationsmetadaten');
    }
    byId[id] = m;
  }
  final stations = <Map<String, dynamic>>[];
  var unlocated = 0;
  const fields = {
    'tre200s0': ('Temperatur', '°C'),
    'rre150z0': ('Niederschlagssumme', 'mm'),
    'dkl010z0': ('Windrichtung', '°'),
    'fu3010z0': ('Wind', 'km/h'),
    'fu3010z1': ('Böen', 'km/h'),
  };
  for (final v in values) {
    final id = v['Station/Location']!, m = byId[id];
    if (m == null) {
      unlocated++;
      continue;
    }
    final lat = double.tryParse(m['station_coordinates_wgs84_lat'] ?? ''),
        lon = double.tryParse(m['station_coordinates_wgs84_lon'] ?? '');
    if (lat == null || lon == null) {
      unlocated++;
      continue;
    }
    final rawTime = v['Date']!;
    if (!RegExp(r'^\d{12}$').hasMatch(rawTime)) {
      throw const FormatException('Ungültige MeteoSwiss-Messzeit');
    }
    final at = DateTime.parse(
      '${rawTime.substring(0, 4)}-${rawTime.substring(4, 6)}-${rawTime.substring(6, 8)}T${rawTime.substring(8, 10)}:${rawTime.substring(10, 12)}:00Z',
    );
    final canonical =
        '${at.year.toString().padLeft(4, '0')}${at.month.toString().padLeft(2, '0')}${at.day.toString().padLeft(2, '0')}${at.hour.toString().padLeft(2, '0')}${at.minute.toString().padLeft(2, '0')}';
    if (canonical != rawTime) {
      throw const FormatException('Ungültiger MeteoSwiss-Kalendertag');
    }
    final readings = <StationReading>[];
    for (final e in fields.entries) {
      final number = double.tryParse(v[e.key] ?? '');
      if (number == null || !number.isFinite) continue;
      if ((e.key != 'tre200s0' && number < 0) ||
          (e.key == 'dkl010z0' && number > 360)) {
        continue;
      }
      readings.add(
        StationReading(
          parameter: e.value.$1,
          value: number,
          unit: e.value.$2,
          atUtc: at,
          quality: 'Qualitätsflag im Produkt nicht bereitgestellt',
          intervalMinutes: e.key == 'rre150z0' ? 10 : null,
        ),
      );
    }
    stations.add(
      ObservationStation(
        id: id,
        name: m['station_name'] ?? id,
        position: MobilityPoint(lat, lon),
        elevation: double.tryParse(m['station_height_masl'] ?? ''),
        readings: readings,
        metadata: {
          'wigos': m['station_wigos_id'],
          'canton': m['station_canton'],
          'sourceFields': v,
          'stationMetadata': m,
          'reference': m['station_url_de'],
        },
      ).toJson(),
    );
  }
  final result = <String, dynamic>{
    'stations': stations,
    'unlocated': unlocated,
    'coverage': 'Publizierte SwissMetNet-Messstationen; keine flächige Wind- oder Wetteranalyse.',
  };
  readStations(result);
  return result;
}

class MeteoStationProvider extends CachedOsintProvider<Map<String, dynamic>> {
  MeteoStationProvider({http.Client? client, super.persistentCache, super.now})
    : transport = MobilityHttp(client: client),
      super(cacheDuration: const Duration(minutes: 10));
  final MobilityHttp transport;
  static final defaultSource = OsintSource(
    id: 'meteoswiss-station-observations-v1',
    name: 'MeteoSwiss Stationsmessungen',
    publisher: 'MeteoSchweiz',
    dataUri: Uri.parse(
      'https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv',
    ),
    metadataUri: Uri.parse(
      'https://opendatadocs.meteoswiss.ch/a-data-groundbased/a1-automatic-weather-stations',
    ),
    licenseName: 'CC BY 4.0',
    licenseUri: Uri.parse(
      'https://opendatadocs.meteoswiss.ch/general/terms-of-use',
    ),
    attribution: 'Quelle: MeteoSchweiz · SwissMetNet · CC BY 4.0',
    coordinateReference:
        'EPSG:4326; station elevation m above sea level, source reference',
  );
  @override
  OsintSource get source => defaultSource;
  @override
  void validateData(Map<String, dynamic> data) {
    readStations(data);
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final time = nowUtc, previous = cached;
    if (previous != null &&
        time.isBefore(previous.cacheExpiresAtUtc) &&
        !previous.requiresRevalidation) {
      return previous;
    }
    final metadataTime = DateTime.tryParse(
      '${previous?.data['metadataFetchedAtUtc']}',
    );
    var metadata = previous?.data['metadataCsv'] as String?;
    var metadataCacheable = previous?.data['metadataCacheable'] != false;
    var metadataRefreshed = false;
    if (metadata == null ||
        metadataTime == null ||
        time.difference(metadataTime) >= const Duration(days: 1)) {
      metadata = await _csv(
        Uri.parse(
          'https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/ogd-smn_meta_stations.csv',
        ),
        onHeaders: (h) => metadataCacheable = !(h['cache-control'] ?? '')
            .toLowerCase()
            .contains('no-store'),
      );
      metadataRefreshed = true;
    }
    Map<String, String> headers = const {};
    var unchanged = false;
    // geo.admin.ch rejects the browser preflight for If-Modified-Since.
    // Web uses ordinary CORS GETs; observation time remains the freshness evidence.
    final body = await _csv(
      sourceUri,
      headers: {
        if (!kIsWeb && previous?.httpLastModified != null)
          'If-Modified-Since': previous!.httpLastModified!,
      },
      onHeaders: (h) => headers = h,
      onNotModified:
          previous == null || kIsWeb || previous.httpLastModified == null
          ? null
          : () {
              unchanged = true;
              return '';
            },
    );
    final data = unchanged
        ? {...previous!.data}
        : await compute(parseMeteoStations, (metadata, body));
    data['metadataCsv'] = metadata;
    data['metadataCacheable'] = metadataCacheable;
    data['metadataFetchedAtUtc'] = metadataRefreshed
        ? time.toIso8601String()
        : metadataTime!.toIso8601String();
    return OsintDataset(
      source: source,
      data: data,
      fetchedAtUtc: unchanged ? previous!.fetchedAtUtc : time,
      lastCheckedAtUtc: time,
      cacheExpiresAtUtc: time.add(cacheDuration),
      httpLastModified: headers['last-modified'] ?? previous?.httpLastModified,
      persistable:
          metadataCacheable &&
          !(headers['cache-control'] ?? '').toLowerCase().contains('no-store'),
    );
  }

  Future<String> _csv(
    Uri uri, {
    Map<String, String> headers = const {},
    void Function(Map<String, String>)? onHeaders,
    String Function()? onNotModified,
  }) => transport.read(
    uri,
    maxBytes: 2 * 1024 * 1024,
    headers: headers,
    onHeaders: onHeaders,
    onNotModified: onNotModified,
    consume: (chunks) async {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in chunks) {
        bytes.add(chunk);
      }
      return decodeStationCsv(bytes.takeBytes());
    },
  );
  @override
  void dispose() {
    transport.dispose();
    super.dispose();
  }
}
