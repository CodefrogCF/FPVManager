import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/weather/fpv_suitability.dart';
import 'package:fpvmanager/features/weather/weather_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);
  WeatherForecast forecast({
    double? wind = 1,
    double? gust = 2,
    double? rain = 0,
    double? visibility = 10000,
    DateTime? issued,
    DateTime? retrieved,
  }) => WeatherForecast(
    provider: WeatherProviderId.meteoSwiss,
    source: 'Fixture',
    sourceUrl: 'https://example.invalid',
    retrievedUtc: retrieved ?? now,
    sourceIssuedUtc: issued,
    modelResolution: 'Unknown',
    locationDescription: 'Fixture',
    samples: [
      WeatherSample(
        timeUtc: now,
        windMs: wind,
        gustMs: gust,
        precipitationMm: rain,
        visibilityMeters: visibility,
      ),
    ],
  );
  FpvWeatherResult evaluate(
    WeatherForecast value, {
    FpvWeatherCriteria criteria = const FpvWeatherCriteria(),
  }) => evaluateFpvWeather(value, now, criteria, nowUtc: now);

  test('negative and nonfinite required values never produce a favorable assessment', () {
    for (final value in [
      forecast(wind: -1),
      forecast(gust: -1),
      forecast(rain: -1),
      forecast(wind: double.nan),
      forecast(gust: double.infinity),
    ]) {
      final result = evaluate(value);
      expect(result.assessment, FpvWeatherAssessment.insufficient);
      expect(result.legallyCleared, isFalse);
    }
    expect(
      evaluate(
        forecast(visibility: -1),
        criteria: const FpvWeatherCriteria(minimumVisibilityMeters: 1000),
      ).assessment,
      FpvWeatherAssessment.insufficient,
    );
  });

  test('old source runs remain outdated after a new download', () {
    final result = evaluate(
      forecast(issued: now.subtract(const Duration(days: 7))),
    );
    expect(result.assessment, FpvWeatherAssessment.insufficient);
    expect(result.explanation, contains('source run is outdated'));
  });

  test(
    'future retrieval and issue times require clock/source verification',
    () {
      for (final value in [
        forecast(issued: now.add(const Duration(hours: 1))),
        forecast(retrieved: now.add(const Duration(hours: 1))),
      ]) {
        expect(evaluate(value).assessment, FpvWeatherAssessment.insufficient);
      }
    },
  );

  test(
    'invalid criteria cannot turn weather values into a positive result',
    () {
      expect(
        evaluate(
          forecast(),
          criteria: const FpvWeatherCriteria(maximumWindMs: double.nan),
        ).assessment,
        FpvWeatherAssessment.insufficient,
      );
      expect(
        evaluate(
          forecast(),
          criteria: const FpvWeatherCriteria(maximumPrecipitationMm: -1),
        ).assessment,
        FpvWeatherAssessment.insufficient,
      );
    },
  );

  test(
    'valid values preserve explanations and configurable drone thresholds',
    () {
      expect(
        evaluate(forecast()).assessment,
        FpvWeatherAssessment.favorableForecast,
      );
      final result = evaluate(
        forecast(wind: 5),
        criteria: const FpvWeatherCriteria(maximumWindMs: 4),
      );
      expect(result.assessment, FpvWeatherAssessment.unsuitable);
      expect(result.factors.first.value, 5);
      expect(result.factors.first.limit, 4);
      expect(result.explanation, contains('threshold is exceeded'));
    },
  );
}
