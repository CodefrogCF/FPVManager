import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'weather_models.dart';
import 'wind_field.dart';

class WindFieldService {
  WindFieldService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _now = now ?? DateTime.now;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  Completer<void>? _abort;
  static const heights = [10, 80, 120, 180];
  static final fields = [
    for (final h in heights) ...['wind_speed_${h}m', 'wind_direction_${h}m'],
  ];
  void cancel() {
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  void dispose() {
    cancel();
    if (_ownsClient) _client.close();
  }

  Future<WindFieldSnapshot> load({
    required double latitude,
    required double longitude,
    required WindTimeMode mode,
    DateTime? forecastUtc,
    double radiusMeters = 1500,
  }) async {
    if (!latitude.isFinite ||
        latitude.abs() > 85 ||
        !longitude.isFinite ||
        longitude.abs() > 179.8 ||
        ![1500.0, 5000.0].contains(radiusMeters)) {
      throw const WeatherException('Unsupported wind area');
    }
    final now = _now().toUtc();
    final chosen = forecastUtc?.toUtc() ?? now;
    if (mode == WindTimeMode.forecast &&
        (chosen.isBefore(now.subtract(const Duration(minutes: 35))) ||
            chosen.isAfter(now.add(const Duration(days: 7))))) {
      throw const WeatherException(
        'Choose a forecast within the next seven days',
      );
    }
    final hour = DateTime.fromMillisecondsSinceEpoch(
      (chosen.millisecondsSinceEpoch / 3600000).round() * 3600000,
      isUtc: true,
    );
    final latStep = radiusMeters / 111320,
        lonStep = radiusMeters / (111320 * math.cos(latitude * math.pi / 180));
    final positions = [
      for (var y = -1; y <= 1; y++)
        for (var x = -1; x <= 1; x++)
          (latitude + y * latStep, longitude + x * lonStep),
    ];
    if (positions.any((p) => p.$1.abs() > 85 || p.$2.abs() > 180)) {
      throw const WeatherException('Unsupported wind area');
    }
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': positions.map((p) => p.$1.toStringAsFixed(4)).join(','),
      'longitude': positions.map((p) => p.$2.toStringAsFixed(4)).join(','),
      mode == WindTimeMode.current ? 'current' : 'hourly': fields.join(','),
      'timezone': 'GMT',
      'wind_speed_unit': 'ms',
      if (mode == WindTimeMode.forecast) ...{
        'start_hour': hour.toIso8601String().substring(0, 16),
        'end_hour': hour.toIso8601String().substring(0, 16),
      },
    });
    cancel();
    final abort = _abort = Completer<void>();
    final deadline = Timer(const Duration(seconds: 35), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final response = await _client
          .send(http.AbortableRequest('GET', uri, abortTrigger: abort.future))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw WeatherException('Open-Meteo HTTP ${response.statusCode}');
      }
      final bytes = BytesBuilder(copy: false);
      var count = 0;
      await for (final part in response.stream.timeout(
        const Duration(seconds: 25),
      )) {
        count += part.length;
        if (count > 2 * 1024 * 1024) {
          abort.complete();
          throw const WeatherException('Wind response exceeds size limit');
        }
        bytes.add(part);
      }
      if (abort.isCompleted) {
        throw const WeatherException('Wind request cancelled');
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is! List || decoded.length != 9) {
        throw const WeatherException('Incomplete wind grid');
      }
      final retrieved = _now().toUtc();
      DateTime? timeAt(dynamic raw) {
        if (raw is! Map) return null;
        final series = raw[mode == WindTimeMode.current ? 'current' : 'hourly'];
        if (series is! Map) return null;
        if (mode == WindTimeMode.current) {
          return parseWeatherUtc('${series['time']}');
        }
        final times = series['time'];
        if (times is! List || times.length > 384) return null;
        for (final t in times) {
          final value = parseWeatherUtc('$t');
          if (value == hour) return value;
        }
        return null;
      }

      final validAt =
          timeAt(decoded[4]) ??
          decoded.map(timeAt).whereType<DateTime>().firstOrNull;
      if (validAt == null ||
          (mode == WindTimeMode.current &&
              (validAt.isBefore(
                    retrieved.subtract(const Duration(minutes: 45)),
                  ) ||
                  validAt.isAfter(
                    retrieved.add(const Duration(minutes: 5)),
                  )))) {
        throw const WeatherException('Wind time is unavailable or outdated');
      }
      final nodes = <WindNode>[];
      for (var i = 0; i < 9; i++) {
        final raw = decoded[i], levels = <WindLevel>[];
        if (raw is Map && timeAt(raw) == validAt) {
          final series =
              raw[mode == WindTimeMode.current ? 'current' : 'hourly'] as Map;
          final units =
              raw[mode == WindTimeMode.current
                  ? 'current_units'
                  : 'hourly_units'];
          final times = series['time'];
          final index = mode == WindTimeMode.current
              ? 0
              : (times as List).indexWhere(
                  (t) => parseWeatherUtc('$t') == validAt,
                );
          for (final h in heights) {
            final speedKey = 'wind_speed_${h}m',
                directionKey = 'wind_direction_${h}m';
            dynamic at(String key) {
              final v = series[key];
              return mode == WindTimeMode.current
                  ? v
                  : v is List && index < v.length
                  ? v[index]
                  : null;
            }

            final speed = nonnegativeWeatherNumber(at(speedKey)),
                direction = nonnegativeWeatherNumber(at(directionKey));
            if (speed == null || direction == null) continue;
            if (speed > 100 ||
                direction > 360 ||
                units is! Map ||
                units[speedKey] != 'm/s' ||
                units[directionKey] != '°') {
              throw const WeatherException('Unsupported wind units or values');
            }
            levels.add(WindLevel(h.toDouble(), speed, direction % 360));
          }
        }
        nodes.add(
          WindNode(
            latitude: positions[i].$1,
            longitude: positions[i].$2,
            levels: List.unmodifiable(levels),
            sourceLatitude: raw is Map
                ? finiteWeatherNumber(raw['latitude'])
                : null,
            sourceLongitude: raw is Map
                ? finiteWeatherNumber(raw['longitude'])
                : null,
          ),
        );
      }
      if (nodes.every((n) => n.levels.isEmpty)) {
        throw const WeatherException('No supported wind layers');
      }
      var expiry = mode == WindTimeMode.current
          ? retrieved.add(const Duration(minutes: 30))
          : retrieved.add(const Duration(hours: 3));
      if (mode == WindTimeMode.current &&
          validAt.add(const Duration(minutes: 45)).isBefore(expiry)) {
        expiry = validAt.add(const Duration(minutes: 45));
      }
      return WindFieldSnapshot(
        mode: mode,
        validAtUtc: validAt,
        retrievedUtc: retrieved,
        expiresUtc: expiry,
        nodes: List.unmodifiable(nodes),
        centerLatitude: latitude,
        centerLongitude: longitude,
        radiusMeters: radiusMeters,
      );
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException('Wind data could not be loaded');
    } finally {
      deadline.cancel();
      if (!abort.isCompleted) abort.complete();
      if (identical(_abort, abort)) _abort = null;
    }
  }
}
