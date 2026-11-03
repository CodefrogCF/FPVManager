import 'dart:convert';

import '../../observations/meteo_station_provider.dart' show stationCsv;
import 'pollen_models.dart';

/// Official metadata CSV contains WGS84 station positions, not measured exposure.
List<PollenStation> parsePollenStations(String csv) {
  final rows = stationCsv(csv);
  final stations = <String, PollenStation>{};
  for (final row in rows) {
    final id = (row['station_abbr'] ?? '').toUpperCase();
    final lat = double.tryParse(row['station_coordinates_wgs84_lat'] ?? '');
    final lon = double.tryParse(row['station_coordinates_wgs84_lon'] ?? '');
    if (!RegExp(r'^[A-Z0-9]{3,5}$').hasMatch(id) ||
        lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < 45 ||
        lat > 48.5 ||
        lon < 5 ||
        lon > 11.5) {
      continue;
    }
    final url = Uri.tryParse(row['station_url_de'] ?? '');
    stations.putIfAbsent(
      id,
      () => PollenStation(
        id: id,
        name: (row['station_name'] ?? '').isEmpty ? id : row['station_name']!,
        canton: row['station_canton'],
        latitude: lat,
        longitude: lon,
        heightMeters: double.tryParse(row['station_height_masl'] ?? ''),
        detailsUrl: url?.scheme == 'https' ? url : null,
      ),
    );
  }
  if (stations.isEmpty || stations.length > 100) {
    throw const FormatException(
      'Unsupported MeteoSwiss pollen station metadata',
    );
  }
  return stations.values.toList(growable: false);
}

DateTime? _parseReferenceUtc(String raw) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})$')
      .firstMatch(raw);
  if (match == null) {
    return null;
  }
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final parsed = DateTime.utc(year, month, day, hour, minute);
  if (parsed.day != day ||
      parsed.month != month ||
      parsed.year != year ||
      parsed.hour != hour ||
      parsed.minute != minute) {
    return null;
  }
  return parsed;
}

/// Only current automatic, hourly h0 concentration is accepted.
/// Metadata taxon classification thresholds are *not* inferred from values.
({List<PollenSample> samples, List<String> unknownParameters})
parsePollenHourlyCsv(String text, String stationId) {
  final rows = stationCsv(text);
  if (rows.isEmpty || rows.length > 500) {
    throw const FormatException('Unsupported pollen h_now data volume');
  }
  final header = rows.first.keys.toSet();
  if (!header.contains('reference_timestamp') ||
      !header.contains('station_abbr')) {
    throw const FormatException('Pollen h_now schema unsupported');
  }
  final known = PollenTaxon.values.map((e) => e.hourlyCode).toSet();
  if (!header.any(known.contains)) {
    throw const FormatException('No supported pollen parameters');
  }
  final unknown = header
      .where(
        (c) =>
            c != 'reference_timestamp' &&
            c != 'station_abbr' &&
            !known.contains(c),
      )
      .toList(growable: false);
  final byTime = <DateTime, PollenSample>{};
  for (final row in rows) {
    if ((row['station_abbr'] ?? '').toUpperCase() != stationId.toUpperCase()) {
      continue;
    }
    final time = _parseReferenceUtc(row['reference_timestamp'] ?? '');
    if (time == null ||
        pollenMethodAt(time) != PollenMeasurementMethod.automatic) {
      continue;
    }
    final values = <PollenTaxon, double?>{};
    for (final taxon in PollenTaxon.values) {
      final raw = row[taxon.hourlyCode]?.trim();
      final value = raw == null || raw.isEmpty ? null : double.tryParse(raw);
      values[taxon] = value == null || !value.isFinite || value < 0
          ? null
          : value;
    }
    byTime[time] = PollenSample(timeUtc: time, values: values);
  }
  final times = byTime.keys.toList()..sort((a, b) => b.compareTo(a));
  return (
    samples: [for (final t in times.take(24)) byTime[t]!],
    unknownParameters: unknown,
  );
}

/// STAC item assets are trusted only when their original source is MeteoSwiss.
({Uri url, DateTime? updatedUtc}) pollenAssetFromStac(
  Map<String, dynamic> item,
  String stationId,
) {
  final assets = item['assets'];
  if (assets is! Map<String, dynamic>) {
    throw const FormatException('STAC item without assets');
  }
  final id = stationId.toLowerCase();
  Uri? match;
  for (final entry in assets.entries) {
    if (entry.value is! Map) {
      continue;
    }
    final href = (entry.value as Map)['href'];
    if (href is! String) {
      continue;
    }
    final uri = Uri.tryParse(href);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'data.geo.admin.ch' ||
        uri.hasQuery ||
        !uri.path.startsWith('/ch.meteoschweiz.ogd-pollen/') ||
        !uri.path.toLowerCase().endsWith('/ogd-pollen_${id}_h_now.csv')) {
      continue;
    }
    match = uri;
    break;
  }
  if (match == null) {
    throw const FormatException('Official h_now asset not published');
  }
  DateTime? updated;
  final properties = item['properties'];
  if (properties is Map<String, dynamic>) {
    final raw = properties['updated'];
    if (raw is String) {
      updated = DateTime.tryParse(raw)?.toUtc();
    }
  }
  return (url: match, updatedUtc: updated);
}

String encodePollenSnapshot(PollenSnapshot snapshot) =>
    jsonEncode(snapshot.toJson());
PollenSnapshot decodePollenSnapshot(String raw) =>
    PollenSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
