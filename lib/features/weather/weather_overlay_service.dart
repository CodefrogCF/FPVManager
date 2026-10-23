import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'weather_models.dart';

enum WeatherOverlayKind { wind, precipitation }

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
  });
  final WeatherOverlayKind kind;
  final DateTime atUtc;
  final List<WeatherOverlayCell> cells;
  final double stepLatitudeDegrees, stepLongitudeDegrees;
  final double spacingMeters;

  Map<String, dynamic> toGlobeCommand() => {
    'type': 'set-weather-overlay',
    'kind': kind.name,
    'timestampUtc': atUtc.toUtc().toIso8601String(),
    'source': 'Open-Meteo (independent model grid samples; CC BY 4.0)',
    'gridSpacingLatitudeDegrees': stepLatitudeDegrees,
    'gridSpacingLongitudeDegrees': stepLongitudeDegrees,
    'gridSpacingMeters': spacingMeters,
    'cells': cells.map((cell) => cell.toJson()).toList(),
  };
}

/// Samples a small grid around the chosen spot. No interpolation and no
/// claim of native-model resolution; each drawn cell reports its sample extent.
class WeatherOverlayService {
  WeatherOverlayService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  Completer<void>? _abort;
  void cancel() {
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  void dispose() {
    cancel();
    if (_ownsClient) _client.close();
  }

  Future<WeatherMapOverlay> load({
    required double latitude,
    required double longitude,
    required DateTime timeUtc,
    required WeatherOverlayKind kind,
    double spacingMeters = 1000,
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
    final parameter = kind == WeatherOverlayKind.wind
        ? 'wind_speed_10m'
        : 'precipitation';
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitudes.join(','),
      'longitude': longitudes.join(','),
      'hourly': parameter,
      'timezone': 'GMT',
      'wind_speed_unit': 'ms',
      'precipitation_unit': 'mm',
      'forecast_days': '8',
    });
    http.Response response;
    cancel();
    final abort = _abort = Completer<void>();
    try {
      final stream = await _client
          .send(http.AbortableRequest('GET', uri, abortTrigger: abort.future))
          .timeout(const Duration(seconds: 35));
      response = await http.Response.fromStream(stream)
          .timeout(const Duration(seconds: 35));
      if (abort.isCompleted) {
        throw const WeatherException('Weather grid request cancelled');
      }
    } catch (_) {
      if (!abort.isCompleted) abort.complete();
      if (identical(_abort, abort)) _abort = null;
      throw const WeatherException('Weather grid network request failed');
    }
    if (response.statusCode != 200) {
      throw WeatherException('Weather grid HTTP ${response.statusCode}');
    }
    List<dynamic> forecasts;
    try {
      final result = jsonDecode(response.body);
      forecasts = result is List ? result : [result];
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
      if (value == null || value < 0) {
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
    if (identical(_abort, abort)) _abort = null;
    if (!abort.isCompleted) abort.complete();
    return WeatherMapOverlay(
      kind: kind,
      atUtc: actualTime,
      cells: cells,
      stepLatitudeDegrees: latStep,
      stepLongitudeDegrees: lonStep,
      spacingMeters: spacingMeters,
    );
  }
}
