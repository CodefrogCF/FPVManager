import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'weather_models.dart';

/// Free, non-commercial API. Never use the paid customer endpoint or a paid key.
class OpenMeteoWeatherProvider implements WeatherProvider {
  OpenMeteoWeatherProvider({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  WeatherProviderId get id => WeatherProviderId.openMeteo;
  @override
  String get title => 'Open-Meteo';
  @override
  String get termsUrl => 'https://open-meteo.com/en/terms';
  @override
  WeatherCapabilities get capabilities => const WeatherCapabilities(
    variables: {
      WeatherVariable.wind,
      WeatherVariable.gust,
      WeatherVariable.windDirection,
      WeatherVariable.precipitation,
      WeatherVariable.temperature,
      WeatherVariable.visibility,
      WeatherVariable.wind80m,
    },
    forecast: true,
    spatialOverlay: true,
    description: 'Hourly model forecasts. Free only for non-commercial use; CC BY 4.0. Model selected by Open-Meteo.',
  );

  static const fields = [
    'wind_speed_10m',
    'wind_gusts_10m',
    'wind_direction_10m',
    'precipitation',
    'temperature_2m',
    'visibility',
    'wind_speed_80m',
  ];

  Uri uri(double latitude, double longitude) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'hourly': fields.join(','),
        'timezone': 'GMT',
        'wind_speed_unit': 'ms',
        'precipitation_unit': 'mm',
        'temperature_unit': 'celsius',
        'forecast_days': '8',
      });

  @override
  Future<WeatherForecast> forecast(double latitude, double longitude) async {
    if (!validWeatherPosition(latitude, longitude)) {
      throw const WeatherException('Invalid coordinates');
    }
    http.Response reply;
    try {
      reply = await _client
          .get(uri(latitude, longitude))
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const WeatherException('Open-Meteo network request failed');
    }
    if (reply.statusCode != 200) {
      throw WeatherException('Open-Meteo HTTP ${reply.statusCode}');
    }
    try {
      final json = jsonDecode(reply.body) as Map<String, dynamic>;
      if (json['error'] == true) {
        throw WeatherException('Open-Meteo: ${json['reason']}');
      }
      return parseOpenMeteoForecast(json, DateTime.now().toUtc());
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException('Invalid Open-Meteo forecast response');
    }
  }
}

WeatherForecast parseOpenMeteoForecast(
  Map<String, dynamic> body,
  DateTime received,
) {
  final hourly = body['hourly'];
  if (hourly is! Map<String, dynamic> || hourly['time'] is! List) {
    throw const WeatherException(
      'Open-Meteo response has no hourly time series',
    );
  }
  final timestamps = hourly['time'] as List;
  double? at(String key, int index) {
    final values = hourly[key];
    return values is List && index < values.length
        ? finiteWeatherNumber(values[index])
        : null;
  }

  final samples = <WeatherSample>[];
  for (var i = 0; i < timestamps.length; i++) {
    final time = parseWeatherUtc('${timestamps[i]}');
    if (time == null) {
      continue;
    }
    samples.add(
      WeatherSample(
        timeUtc: time,
        windMs: at('wind_speed_10m', i),
        gustMs: at('wind_gusts_10m', i),
        directionDegrees: at('wind_direction_10m', i),
        precipitationMm: at('precipitation', i),
        temperatureC: at('temperature_2m', i),
        visibilityMeters: at('visibility', i),
        wind80mMs: at('wind_speed_80m', i),
      ),
    );
  }
  if (samples.isEmpty) {
    throw const WeatherException('No valid Open-Meteo forecast steps');
  }
  return WeatherForecast(
    provider: WeatherProviderId.openMeteo,
    source: 'Open-Meteo (forecast models)',
    sourceUrl: 'https://open-meteo.com/en/docs',
    retrievedUtc: received,
    sourceIssuedUtc: null,
    modelResolution:
        'Model-dependent; coordinates are sampled, not on-site measurements',
    locationDescription: 'Model grid for requested coordinates',
    samples: samples,
  );
}

/// MeteoSwiss official local forecasts (E4). One file per meteorological
/// parameter, ~6,000 points per file: downloading is bandwidth intensive.
/// We fetch only the minimum variables and filter rows by unique (type,id).
class MeteoSwissWeatherProvider implements WeatherProvider {
  MeteoSwissWeatherProvider({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const base = 'https://data.geo.admin.ch';
  static const collection = 'ch.meteoschweiz.ogd-local-forecasting';
  static const codes = <String, String>{
    'fu3010h0': 'wind',
    'fu3010h1': 'gust',
    'dkl010h0': 'direction',
    'rre150h0': 'precipitation',
    'tre200h0': 'temperature',
  };
  @override
  WeatherProviderId get id => WeatherProviderId.meteoSwiss;
  @override
  String get title => 'MeteoSwiss (official)';
  @override
  String get termsUrl =>
      'https://opendatadocs.meteoswiss.ch/e-forecast-data/e4-local-forecast-data';
  @override
  WeatherCapabilities get capabilities => const WeatherCapabilities(
    variables: {
      WeatherVariable.wind,
      WeatherVariable.gust,
      WeatherVariable.windDirection,
      WeatherVariable.precipitation,
      WeatherVariable.temperature,
    },
    forecast: true,
    spatialOverlay: false,
    description: 'Official hourly forecasts for the nearest MeteoSwiss forecast point. Large CSV downloads; 80 m wind and visibility unavailable.',
  );

  String? _pointsCsv;
  DateTime? _pointsFetched;
  DateTime? _sourceIssuedUtc;
  Map<String, dynamic>? _assetCatalog;
  DateTime? _catalogFetched;

  Future<String> _getText(Uri url, {int maxBytes = 36 * 1024 * 1024}) async {
    if (url.scheme != 'https' || url.host != 'data.geo.admin.ch') {
      throw const WeatherException('Unexpected MeteoSwiss asset host');
    }
    http.Response response;
    try {
      response = await _client.get(url).timeout(const Duration(seconds: 55));
    } catch (_) {
      throw const WeatherException('MeteoSwiss Open Data is unreachable');
    }
    if (response.statusCode != 200) {
      throw WeatherException('MeteoSwiss HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const WeatherException('MeteoSwiss file exceeds safety size limit');
    }
    return latin1.decode(response.bodyBytes);
  }

  Future<Map<String, dynamic>> _catalog() async {
    if (_assetCatalog != null &&
        _catalogFetched != null &&
        DateTime.now().difference(_catalogFetched!) <
            const Duration(minutes: 45)) {
      return _assetCatalog!;
    }
    final listing = jsonDecode(
      await _getText(
        Uri.parse('$base/api/stac/v1/collections/$collection/items?limit=12'),
        maxBytes: 3 * 1024 * 1024,
      ),
    );
    if (listing is! Map || listing['features'] is! List) {
      throw const WeatherException('MeteoSwiss STAC listing unavailable');
    }
    final items =
        (listing['features'] as List).whereType<Map<String, dynamic>>().toList()
          ..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
    for (final item in items) {
      final assets = item['assets'];
      if (assets is! Map<String, dynamic>) {
        continue;
      }
      if (codes.keys.every(
        (key) => assets.keys.any((name) => name.contains(key)),
      )) {
        _assetCatalog = assets;
        final properties = item['properties'];
        _sourceIssuedUtc = properties is Map
            ? parseWeatherUtc('${properties['datetime'] ?? ''}')
            : null;
        _catalogFetched = DateTime.now();
        return assets;
      }
    }
    throw const WeatherException(
      'MeteoSwiss forecast run is incomplete; retry later',
    );
  }

  /// Stream ~33 MB E4 CSVs one line at a time. Do not retain full parameter
  /// datasets in memory, even when comparing multiple Swiss mountain sites.
  Future<List<Map<String, String>>> _streamRows(
    Uri uri,
    String pointId,
    String pointType,
    String code,
  ) async {
    if (uri.scheme != 'https' || uri.host != 'data.geo.admin.ch') {
      throw const WeatherException('Unexpected MeteoSwiss asset host');
    }
    http.StreamedResponse reply;
    try {
      reply = await _client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const WeatherException('MeteoSwiss forecast download failed');
    }
    if (reply.statusCode != 200) {
      throw WeatherException('MeteoSwiss forecast HTTP ${reply.statusCode}');
    }
    if ((reply.contentLength ?? 0) > 36 * 1024 * 1024) {
      throw const WeatherException('MeteoSwiss forecast exceeds size limit');
    }
    final rows = <Map<String, String>>[];
    var size = 0, firstLine = true;
    var id = -1, type = -1, time = -1, value = -1;
    try {
      await for (final line
          in reply.stream
              .transform(latin1.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 75))) {
        size += line.length;
        if (size > 36 * 1024 * 1024) {
          throw const WeatherException(
            'MeteoSwiss forecast exceeds size limit',
          );
        }
        if (firstLine) {
          firstLine = false;
          final headers = line.replaceFirst('\ufeff', '').trim().split(';');
          id = headers.indexOf('point_id');
          type = headers.indexOf('point_type_id');
          time = headers.indexOf('Date');
          value = headers.indexOf(code);
          if ([id, type, time, value].any((i) => i < 0)) {
            throw const WeatherException(
              'Unexpected MeteoSwiss forecast schema',
            );
          }
          continue;
        }
        // E4 starts with point_id;point_type_id: skip almost all national
        // records without allocating per-row Dart lists.
        if (id == 0 && type == 1 && !line.startsWith('$pointId;$pointType;')) {
          continue;
        }
        final columns = line.split(';');
        if (columns.length > [id, type, time, value].reduce(math.max) &&
            columns[id] == pointId &&
            columns[type] == pointType) {
          rows.add({'time': columns[time], 'value': columns[value]});
        }
      }
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException('Interrupted MeteoSwiss forecast download');
    }
    return rows;
  }

  Future<String> _points() async {
    if (_pointsCsv != null &&
        _pointsFetched != null &&
        DateTime.now().difference(_pointsFetched!) < const Duration(days: 7)) {
      return _pointsCsv!;
    }
    final csv = await _getText(
      Uri.parse('$base/$collection/ogd-local-forecasting_meta_point.csv'),
      maxBytes: 2 * 1024 * 1024,
    );
    _pointsCsv = csv;
    _pointsFetched = DateTime.now();
    return csv;
  }

  @override
  Future<WeatherForecast> forecast(double latitude, double longitude) async {
    if (!validWeatherPosition(latitude, longitude)) {
      throw const WeatherException('Invalid coordinates');
    }
    if (latitude < 45.7 ||
        latitude > 47.9 ||
        longitude < 5.8 ||
        longitude > 10.7) {
      throw const WeatherException(
        'MeteoSwiss local forecasts only cover Switzerland',
      );
    }
    final point = await compute(nearestMeteoSwissPoint, <String, dynamic>{
      'csv': await _points(),
      'lat': latitude,
      'lon': longitude,
    });
    if (point == null) {
      throw const WeatherException('No nearby MeteoSwiss forecast point');
    }
    final assets = await _catalog();
    final byTime = <DateTime, Map<String, double>>{};
    for (final code in codes.keys) {
      final name = assets.keys.where((key) => key.contains(code)).first;
      final asset = assets[name];
      final url = asset is Map ? asset['href'] : null;
      if (url is! String) {
        continue;
      }
      final rows = await _streamRows(
        Uri.parse(url),
        point['id'] as String,
        point['type'] as String,
        code,
      );
      for (final row in rows) {
        final time = parseWeatherUtc(row['time']!);
        final value = finiteWeatherNumber(row['value']);
        if (time != null && value != null) {
          byTime.putIfAbsent(time, () => {})[code] = value;
        }
      }
    }
    final samples = byTime.entries.map((e) {
      final v = e.value;
      return WeatherSample(
        timeUtc: e.key,
        windMs: v['fu3010h0'] == null ? null : v['fu3010h0']! / 3.6,
        gustMs: v['fu3010h1'] == null ? null : v['fu3010h1']! / 3.6,
        directionDegrees: v['dkl010h0'],
        precipitationMm: v['rre150h0'],
        temperatureC: v['tre200h0'],
      );
    }).toList()..sort((a, b) => a.timeUtc.compareTo(b.timeUtc));
    if (samples.isEmpty) {
      throw const WeatherException(
        'No forecast values for the chosen MeteoSwiss location',
      );
    }
    return WeatherForecast(
      provider: id,
      source: 'Source: MeteoSwiss (local forecast E4)',
      sourceUrl: termsUrl,
      retrievedUtc: DateTime.now().toUtc(),
      sourceIssuedUtc: _sourceIssuedUtc,
      modelResolution: 'Nearest official forecast point (not a measured spot; hourly intervals)',
      locationDescription:
          '${point['name']} (MeteoSwiss point ${point['id']}, type ${point['type']})',
      distanceToSourceKm: point['distance'] as double?,
      samples: samples,
    );
  }
}

/// CSV metadata contains WGS84 decimal coordinates, keyed by (point_type_id, point_id).
Map<String, dynamic>? nearestMeteoSwissPoint(Map<String, dynamic> args) {
  final lines = const LineSplitter().convert(args['csv'] as String);
  if (lines.isEmpty) {
    return null;
  }
  final headers = lines.first.replaceFirst('\ufeff', '').split(';');
  int col(String name) => headers.indexOf(name);
  final id = col('point_id'),
      type = col('point_type_id'),
      name = col('point_name');
  final lat = col('point_coordinates_wgs84_lat'),
      lon = col('point_coordinates_wgs84_lon');
  if ([id, type, name, lat, lon].any((i) => i < 0)) {
    return null;
  }
  final targetLat = args['lat'] as double, targetLon = args['lon'] as double;
  Map<String, dynamic>? closest;
  var distance = double.infinity;
  for (final line in lines.skip(1)) {
    final row = line.split(';');
    if (row.length <= [id, type, name, lat, lon].reduce(math.max)) {
      continue;
    }
    final a = finiteWeatherNumber(row[lat]), b = finiteWeatherNumber(row[lon]);
    if (a == null || b == null) {
      continue;
    }
    final km = haversineKm(a, b, targetLat, targetLon);
    if (km < distance) {
      distance = km;
      closest = {
        'id': row[id],
        'type': row[type],
        'name': row[name],
        'distance': km,
      };
    }
  }
  return closest;
}

double haversineKm(double a, double b, double c, double d) {
  final p = math.pi / 180;
  final dl = (c - a) * p, dn = (d - b) * p;
  final x =
      math.pow(math.sin(dl / 2), 2) +
      math.cos(a * p) * math.cos(c * p) * math.pow(math.sin(dn / 2), 2);
  return 12742 * math.asin(math.sqrt(x.clamp(0, 1)));
}

/// Consumes a MeteoSwiss E4 semicolon-separated hourly file.
/// Filter by both identifiers: point_id alone is NOT unique.
List<Map<String, String>> extractMeteoSwissRows(Map<String, dynamic> args) {
  final lines = const LineSplitter().convert(args['csv'] as String);
  if (lines.isEmpty) {
    return [];
  }
  final headers = lines.first.replaceFirst('\ufeff', '').trim().split(';');
  final id = headers.indexOf('point_id'),
      type = headers.indexOf('point_type_id');
  final time = headers.indexOf('Date'),
      value = headers.indexOf(args['parameter'] as String);
  if ([id, type, time, value].any((i) => i < 0)) {
    return [];
  }
  final target = args['pointId'] as String, kind = args['pointType'] as String;
  final result = <Map<String, String>>[];
  for (final line in lines.skip(1)) {
    // Avoid materialising all of a 33-MB national forecast table as parsed objects.
    final parts = line.split(';');
    if (parts.length > value &&
        parts.length > time &&
        parts[id] == target &&
        parts[type] == kind) {
      result.add({'time': parts[time], 'value': parts[value]});
    }
  }
  return result;
}

/// Memory cache avoids repeated requests during map and spot comparisons.
/// Concurrent identical requests share one in-flight future; failures are not cached.
class CachedWeatherProvider implements WeatherProvider {
  CachedWeatherProvider(
    this.delegate, {
    this.ttl = const Duration(minutes: 45),
  });
  final WeatherProvider delegate;
  final Duration ttl;
  final Map<String, ({DateTime at, WeatherForecast data})> _cache = {};
  final Map<String, Future<WeatherForecast>> _pending = {};
  @override
  WeatherProviderId get id => delegate.id;
  @override
  String get title => delegate.title;
  @override
  String get termsUrl => delegate.termsUrl;
  @override
  WeatherCapabilities get capabilities => delegate.capabilities;
  @override
  Future<WeatherForecast> forecast(double latitude, double longitude) {
    final key =
        '${latitude.toStringAsFixed(3)}|${longitude.toStringAsFixed(3)}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < ttl) {
      return Future.value(cached.data);
    }
    if (_pending.containsKey(key)) {
      return _pending[key]!;
    }
    final call = delegate.forecast(latitude, longitude);
    _pending[key] = call;
    call
        .then((value) {
          _cache[key] = (at: DateTime.now(), data: value);
        }, onError: (Object _) {})
        .whenComplete(() => _pending.remove(key));
    return call;
  }
}
