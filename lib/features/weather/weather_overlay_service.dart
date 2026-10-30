import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_source.dart';
import '../mobility/road_routing.dart';

import 'weather_models.dart';

List<dynamic> _decodeWeatherGrid(String body) {
  final raw = jsonDecode(body);
  return raw is List ? raw : [raw];
}

enum WeatherOverlayKind {
  wind('Wind 10 m', 'wind_speed_10m', 'm/s', false),
  precipitation('Niederschlagssumme (1 h)', 'precipitation', 'mm', true),
  cloudCover('Bewölkung', 'cloud_cover', '%', false),
  rain('Regen · großräumig (1 h)', 'rain', 'mm', true),
  snowfall('Neuschneesumme (1 h)', 'snowfall', 'cm', true),
  snowDepth('Schneehöhe', 'snow_depth', 'm', false),
  temperature('Temperatur 2 m', 'temperature_2m', '°C', false);

  const WeatherOverlayKind(
    this.label,
    this.parameter,
    this.unit,
    this.hourlyTotal,
  );
  final String label, parameter, unit;
  final bool hourlyTotal;
  bool accepts(num value) =>
      value.isFinite &&
      (this == temperature
          ? value >= -100 && value <= 70
          : value >= 0 && (this != cloudCover || value <= 100));
}

class WeatherOverlayCell {
  const WeatherOverlayCell({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.value,
  });
  final double west, south, east, north, value;
  Map<String, dynamic> toJson() => {
    'west': west,
    'south': south,
    'east': east,
    'north': north,
    'value': value,
  };
}

class WeatherMapOverlay {
  WeatherMapOverlay({
    required this.kind,
    required this.atUtc,
    required this.cells,
    required this.stepLatitudeDegrees,
    required this.stepLongitudeDegrees,
    required this.spacingMeters,
    DateTime? fetchedAtUtc,
    this.cacheable = true,
    this.missingSamples = 0,
  }) : fetchedAtUtc = fetchedAtUtc ?? DateTime.now().toUtc();
  final WeatherOverlayKind kind;
  final DateTime atUtc;
  final List<WeatherOverlayCell> cells;
  final double stepLatitudeDegrees, stepLongitudeDegrees;
  final double spacingMeters;
  final DateTime fetchedAtUtc;
  final bool cacheable;
  final int missingSamples;
  static final source = OsintSource(
    id: 'open-meteo-sampled-overlays',
    name: 'Open-Meteo Modellraster',
    publisher: 'Open-Meteo',
    dataUri: Uri.parse('https://api.open-meteo.com/v1/forecast'),
    metadataUri: Uri.parse('https://open-meteo.com/en/docs'),
    licenseName: 'CC BY 4.0',
    licenseUri: Uri.parse('https://open-meteo.com/en/terms'),
    attribution: 'Open-Meteo · CC BY 4.0',
    coordinateReference:
        'EPSG:4326; bounded display sample cells, no native resolution claim',
  );
  OsintDataset<WeatherMapOverlay> get dataset => OsintDataset(
    source: source,
    data: this,
    fetchedAtUtc: fetchedAtUtc,
    lastCheckedAtUtc: fetchedAtUtc,
    cacheExpiresAtUtc: fetchedAtUtc.add(const Duration(minutes: 10)),
    persistable: cacheable,
  );

  Map<String, dynamic> toGlobeCommand() => {
    'type': 'set-weather-overlay',
    'kind': kind.name,
    'timestampUtc': atUtc.toUtc().toIso8601String(),
    'source': 'Open-Meteo (independent model grid samples; CC BY 4.0)',
    'sourceType': 'forecast',
    'units': kind.unit,
    'intervalMinutes': kind.hourlyTotal ? 60 : 0,
    'expiresAtUtc': dataset.cacheExpiresAtUtc.toIso8601String(),
    'retrievedAtUtc': fetchedAtUtc.toIso8601String(),
    'missingSamples': missingSamples,
    'opacity': .4,
    'gridSpacingLatitudeDegrees': stepLatitudeDegrees,
    'gridSpacingLongitudeDegrees': stepLongitudeDegrees,
    'gridSpacingMeters': spacingMeters,
    'cells': cells.map((cell) => cell.toJson()).toList(),
  };
}

/// Samples a small grid around the chosen spot. No interpolation and no
/// claim of native-model resolution; each drawn cell reports its sample extent.
class WeatherOverlayService {
  WeatherOverlayService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _now = now ?? DateTime.now;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final _requests = <MobilityHttp>{};
  final _pending = <String, Future<WeatherMapOverlay>>{};
  final _cached = <String, WeatherMapOverlay>{};
  bool _disposed = false;
  int _generation = 0;
  void cancel() {
    _generation++;
    _pending.clear();
    for (final request in _requests.toList()) {
      request.dispose();
    }
    _requests.clear();
    _cached.clear();
  }

  void dispose() {
    _disposed = true;
    cancel();
    if (_ownsClient) _client.close();
  }

  Future<WeatherMapOverlay> load({
    required double latitude,
    required double longitude,
    required DateTime timeUtc,
    required WeatherOverlayKind kind,
    double spacingMeters = 1000,
  }) {
    if (_disposed) return Future.error(StateError('Wetterraster geschlossen'));
    final key =
        '$latitude:$longitude:${timeUtc.toUtc().toIso8601String()}:${kind.name}:$spacingMeters';
    if (_pending.containsKey(key)) return _pending[key]!;
    final cached = _cached[key];
    if (cached != null &&
        cached.dataset.freshnessAt(_now()) == OsintFreshness.fresh) {
      return Future.value(cached);
    }
    if (_pending.length >= 3) {
      return Future.error(
        const WeatherException('Höchstens drei gleichzeitige Rasterabrufe'),
      );
    }
    final future = _load(
      latitude: latitude,
      longitude: longitude,
      timeUtc: timeUtc,
      kind: kind,
      spacingMeters: spacingMeters,
    );
    final generation = _generation;
    _pending[key] = future;
    future.then(
      (result) {
        if (generation != _generation) return;
        _pending.remove(key);
        if (result.cacheable && !_disposed) {
          if (_cached.length >= 12) _cached.remove(_cached.keys.first);
          _cached[key] = result;
        }
      },
      onError: (Object _, StackTrace _) {
        if (generation == _generation) _pending.remove(key);
      },
    );
    return future;
  }

  Future<WeatherMapOverlay> _load({
    required double latitude,
    required double longitude,
    required DateTime timeUtc,
    required WeatherOverlayKind kind,
    required double spacingMeters,
  }) async {
    if (!validWeatherPosition(latitude, longitude)) {
      throw const WeatherException('Invalid overlay center');
    }
    if (latitude < 45.8 ||
        latitude > 47.9 ||
        longitude < 5.9 ||
        longitude > 10.6) {
      throw const WeatherException(
        'Weather overlays are limited to Switzerland',
      );
    }
    if (spacingMeters != 1000 && spacingMeters != 5000) {
      throw const WeatherException('Unsupported weather sample spacing');
    }
    const columns = 7, rows = 7;
    final latStep = spacingMeters / 111320;
    final lonStep =
        spacingMeters / (111320 * math.cos(latitude * math.pi / 180));
    final latitudes = <String>[], longitudes = <String>[];
    final bounds = <({double south, double north, double west, double east})>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final south = latitude + (y - rows ~/ 2 - 0.5) * latStep;
        final west = longitude + (x - columns ~/ 2 - 0.5) * lonStep;
        bounds.add((
          south: south,
          north: south + latStep,
          west: west,
          east: west + lonStep,
        ));
        latitudes.add((south + latStep / 2).toStringAsFixed(4));
        longitudes.add((west + lonStep / 2).toStringAsFixed(4));
      }
    }
    final parameter = kind.parameter;
    final now = _now().toUtc();
    if (timeUtc.isBefore(now.subtract(const Duration(hours: 1))) ||
        timeUtc.isAfter(now.add(const Duration(days: 7)))) {
      throw const WeatherException(
        'Prognosezeit außerhalb des unterstützten Zeitraums',
      );
    }
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitudes.join(','),
      'longitude': longitudes.join(','),
      'hourly': parameter,
      'timezone': 'GMT',
      'wind_speed_unit': 'ms',
      'precipitation_unit': 'mm',
      'forecast_days': '8',
    });
    late String body;
    Map<String, String> responseHeaders = const {};
    final transport = MobilityHttp(client: _client);
    _requests.add(transport);
    try {
      body = await transport.read<String>(
        uri,
        maxBytes: 4 * 1024 * 1024,
        timeout: const Duration(seconds: 35),
        onHeaders: (h) => responseHeaders = h,
        consume: (chunks) async {
          final bytes = BytesBuilder(copy: false);
          await for (final c in chunks) {
            bytes.add(c);
          }
          return utf8.decode(bytes.takeBytes());
        },
      );
    } finally {
      _requests.remove(transport);
      transport.dispose();
    }
    List<dynamic> forecasts;
    try {
      forecasts = body.length < 65536
          ? _decodeWeatherGrid(body)
          : await compute(_decodeWeatherGrid, body);
    } catch (_) {
      throw const WeatherException('Invalid weather grid response');
    }
    if (forecasts.length != bounds.length) {
      throw const WeatherException('Incomplete weather grid response');
    }
    final cells = <WeatherOverlayCell>[];
    DateTime? actualTime;
    for (var index = 0; index < bounds.length; index++) {
      final item = forecasts[index];
      if (item is! Map || item['hourly'] is! Map) {
        continue;
      }
      if (item['hourly_units'] is! Map ||
          item['hourly_units'][parameter] != kind.unit) {
        throw const WeatherException(
          'Fehlende oder nicht unterstützte Einheit im Wetterraster',
        );
      }
      final hourly = item['hourly'] as Map;
      final dates = hourly['time'], values = hourly[parameter];
      if (dates is! List || values is! List) {
        continue;
      }
      int? best;
      var closestMs = const Duration(minutes: 35).inMilliseconds + 1;
      for (var j = 0; j < dates.length && j < values.length; j++) {
        final step = parseWeatherUtc('${dates[j]}');
        if (step == null) {
          continue;
        }
        final ms = step.difference(timeUtc.toUtc()).inMilliseconds.abs();
        if (ms < closestMs) {
          best = j;
          closestMs = ms;
        }
      }
      if (best == null) {
        continue;
      }
      final value = finiteWeatherNumber(values[best]);
      if (value == null || !kind.accepts(value)) {
        continue;
      }
      final cellTime = parseWeatherUtc('${dates[best]}');
      actualTime ??= cellTime;
      if (cellTime != actualTime) continue;
      final b = bounds[index];
      cells.add(
        WeatherOverlayCell(
          west: b.west,
          south: b.south,
          east: b.east,
          north: b.north,
          value: value,
        ),
      );
    }
    if (cells.isEmpty || actualTime == null) {
      throw const WeatherException('No data at this forecast time');
    }
    return WeatherMapOverlay(
      kind: kind,
      atUtc: actualTime,
      cells: cells,
      stepLatitudeDegrees: latStep,
      stepLongitudeDegrees: lonStep,
      spacingMeters: spacingMeters,
      fetchedAtUtc: now,
      cacheable: !(responseHeaders['cache-control'] ?? '')
          .toLowerCase()
          .contains('no-store'),
      missingSamples: bounds.length - cells.length,
    );
  }
}
