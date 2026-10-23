/// All meteorological values use SI units, UTC timestamps and explicit sources.
enum WeatherVariable {
  wind,
  gust,
  windDirection,
  precipitation,
  temperature,
  visibility,
  wind80m,
}

enum WeatherProviderId { meteoSwiss, openMeteo }

class WeatherCapabilities {
  const WeatherCapabilities({
    required this.variables,
    required this.forecast,
    required this.spatialOverlay,
    required this.description,
  });
  final Set<WeatherVariable> variables;
  final bool forecast;
  final bool spatialOverlay;
  final String description;
}

class WeatherSample {
  const WeatherSample({
    required this.timeUtc,
    this.windMs,
    this.gustMs,
    this.directionDegrees,
    this.precipitationMm,
    this.temperatureC,
    this.visibilityMeters,
    this.wind80mMs,
  });
  final DateTime timeUtc;
  final double? windMs,
      gustMs,
      directionDegrees,
      precipitationMm,
      temperatureC,
      visibilityMeters,
      wind80mMs;
}

class WeatherForecast {
  const WeatherForecast({
    required this.provider,
    required this.source,
    required this.sourceUrl,
    required this.retrievedUtc,
    required this.samples,
    required this.modelResolution,
    required this.locationDescription,
    this.sourceIssuedUtc,
    this.distanceToSourceKm,
  });
  final WeatherProviderId provider;
  final String source, sourceUrl, modelResolution, locationDescription;
  final DateTime retrievedUtc;
  final DateTime? sourceIssuedUtc;
  final double? distanceToSourceKm;
  final List<WeatherSample> samples;

  /// Never extrapolate beyond a nearby documented forecast time-step.
  WeatherSample? at(
    DateTime time, {
    Duration tolerance = const Duration(minutes: 35),
  }) {
    if (samples.isEmpty) return null;
    WeatherSample? nearest;
    var delta = tolerance.inMilliseconds + 1;
    for (final sample in samples) {
      final difference = sample.timeUtc
          .difference(time.toUtc())
          .inMilliseconds
          .abs();
      if (difference < delta) {
        delta = difference;
        nearest = sample;
      }
    }
    return nearest;
  }
}

class WeatherException implements Exception {
  const WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Provider-specific scientific quantities are never silently combined.
abstract interface class WeatherProvider {
  WeatherProviderId get id;
  String get title;
  String get termsUrl;
  WeatherCapabilities get capabilities;
  Future<WeatherForecast> forecast(double latitude, double longitude);
}

bool validWeatherPosition(double lat, double lon) =>
    lat.isFinite &&
    lon.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180;

DateTime? parseWeatherUtc(String raw) {
  final value = raw.trim();
  if (RegExp(r'^\d{12}$').hasMatch(value)) {
    return DateTime.tryParse(
      '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}T${value.substring(8, 10)}:${value.substring(10, 12)}:00Z',
    );
  }
  if (RegExp(r'^\d{4}-\d\d-\d\dT').hasMatch(value) &&
      !RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(value)) {
    return DateTime.tryParse('${value}Z');
  }
  return DateTime.tryParse(value)?.toUtc();
}

double? finiteWeatherNumber(Object? raw) {
  if (raw == null || raw == '-' || raw == '') return null;
  final n = raw is num
      ? raw.toDouble()
      : double.tryParse(raw.toString().replaceAll(',', '.'));
  return n != null && n.isFinite ? n : null;
}
