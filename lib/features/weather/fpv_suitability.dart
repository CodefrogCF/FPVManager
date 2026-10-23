import 'weather_models.dart';

enum FpvWeatherAssessment {
  favorableForecast,
  caution,
  unsuitable,
  insufficient,
}

class FpvWeatherCriteria {
  const FpvWeatherCriteria({
    this.maximumWindMs = 8,
    this.maximumGustMs = 12,
    this.maximumPrecipitationMm = 0.2,
    this.minimumVisibilityMeters,
  });
  final double maximumWindMs, maximumGustMs, maximumPrecipitationMm;
  final double? minimumVisibilityMeters;
}

class FpvWeatherFactor {
  const FpvWeatherFactor(
    this.label,
    this.value,
    this.limit,
    this.unit,
    this.passes,
  );
  final String label, unit;
  final double? value, limit;
  final bool? passes;
}

class FpvWeatherResult {
  const FpvWeatherResult({
    required this.assessment,
    required this.factors,
    required this.explanation,
    required this.forecast,
    required this.forecastTime,
  });
  final FpvWeatherAssessment assessment;
  final List<FpvWeatherFactor> factors;
  final String explanation;
  final WeatherForecast forecast;
  final DateTime forecastTime;

  /// This is intentionally always false; legal clearance is a separate check.
  bool get legallyCleared => false;
}

FpvWeatherResult evaluateFpvWeather(
  WeatherForecast forecast,
  DateTime target,
  FpvWeatherCriteria criteria, {
  DateTime? nowUtc,
}) {
  final sample = forecast.at(target);
  FpvWeatherFactor maximum(
    String label,
    double? value,
    double limit,
    String unit,
  ) => FpvWeatherFactor(
    label,
    value,
    limit,
    unit,
    value == null ||
            !value.isFinite ||
            value < 0 ||
            !limit.isFinite ||
            limit < 0
        ? null
        : value <= limit,
  );
  final factors = <FpvWeatherFactor>[
    maximum('Mean wind', sample?.windMs, criteria.maximumWindMs, 'm/s'),
    maximum('Wind gusts', sample?.gustMs, criteria.maximumGustMs, 'm/s'),
    maximum(
      'Precipitation (hour)',
      sample?.precipitationMm,
      criteria.maximumPrecipitationMm,
      'mm',
    ),
    if (criteria.minimumVisibilityMeters != null)
      FpvWeatherFactor(
        'Visibility',
        sample?.visibilityMeters,
        criteria.minimumVisibilityMeters,
        'm',
        sample?.visibilityMeters == null ||
                !sample!.visibilityMeters!.isFinite ||
                sample.visibilityMeters! < 0 ||
                !criteria.minimumVisibilityMeters!.isFinite ||
                criteria.minimumVisibilityMeters! < 0
            ? null
            : sample.visibilityMeters! >= criteria.minimumVisibilityMeters!,
      ),
  ];
  final now = nowUtc?.toUtc() ?? DateTime.now().toUtc();
  final oldestAllowed = now.subtract(const Duration(hours: 24));
  final latestAllowed = now.add(const Duration(minutes: 5));
  final issued = forecast.sourceIssuedUtc;
  final stale =
      forecast.retrievedUtc.isBefore(oldestAllowed) ||
      issued != null && issued.isBefore(oldestAllowed);
  final clockSkew =
      forecast.retrievedUtc.isAfter(latestAllowed) ||
      issued != null && issued.isAfter(latestAllowed);
  final missing =
      factors.any((factor) => factor.passes == null) || sample == null;
  final failed = factors.any((factor) => factor.passes == false);
  final outOfRange = target.toUtc().isBefore(
    now.subtract(const Duration(minutes: 90)),
  );
  final assessment = stale || clockSkew || outOfRange || missing
      ? FpvWeatherAssessment.insufficient
      : failed
      ? FpvWeatherAssessment.unsuitable
      : FpvWeatherAssessment.favorableForecast;
  return FpvWeatherResult(
    assessment: assessment,
    factors: factors,
    explanation: stale
        ? 'Forecast download or source run is outdated; refresh required.'
        : clockSkew
        ? 'Forecast timestamps are in the future; check the device clock and source.'
        : outOfRange
        ? 'Selected flight time is in the past.'
        : missing
        ? 'Required parameters are missing or invalid, or no nearby forecast hour is available. No positive assessment.'
        : failed
        ? 'At least one configured weather threshold is exceeded.'
        : 'Forecast values are within your selected limits; this is NOT a flight safety clearance.',
    forecast: forecast,
    forecastTime: target,
  );
}
