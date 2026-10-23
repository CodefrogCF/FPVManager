import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/fpv_database.dart';
import 'fpv_suitability.dart';
import 'weather_models.dart';

class WeatherPreferences {
  const WeatherPreferences({
    this.provider = WeatherProviderId.openMeteo,
    this.criteriaByDrone = const {},
  });
  final WeatherProviderId provider;
  final Map<int, FpvWeatherCriteria> criteriaByDrone;

  FpvWeatherCriteria criteriaFor(int? droneId) =>
      criteriaByDrone[droneId ?? 0] ?? const FpvWeatherCriteria();
}

/// Reuses the existing local key-value settings table; no DB migration or cloud account.
class WeatherPreferencesRepository {
  const WeatherPreferencesRepository(this.database);
  final FpvDatabase database;
  static const key = 'weather.settings.v1';

  Future<WeatherPreferences> load() async {
    final row = await (database.select(
      database.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) {
      return const WeatherPreferences();
    }
    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      final provider = WeatherProviderId.values.byName(
        json['provider'] as String,
      );
      final criteria = <int, FpvWeatherCriteria>{};
      final values = json['criteria'] as Map<String, dynamic>? ?? {};
      for (final entry in values.entries) {
        final droneId = int.tryParse(entry.key);
        if (droneId == null || entry.value is! Map) {
          continue;
        }
        final v = entry.value as Map;
        double? number(String name) => (v[name] as num?)?.toDouble();
        final maxWind = number('wind'),
            maxGust = number('gust'),
            maxRain = number('rain');
        if (maxWind == null ||
            maxGust == null ||
            maxRain == null ||
            !maxWind.isFinite ||
            !maxGust.isFinite ||
            !maxRain.isFinite ||
            maxWind <= 0 ||
            maxGust <= 0 ||
            maxRain < 0) {
          continue;
        }
        criteria[droneId] = FpvWeatherCriteria(
          maximumWindMs: maxWind,
          maximumGustMs: maxGust,
          maximumPrecipitationMm: maxRain,
          minimumVisibilityMeters: number('visibility'),
        );
      }
      return WeatherPreferences(provider: provider, criteriaByDrone: criteria);
    } catch (_) {
      return const WeatherPreferences();
    }
  }

  Future<void> save(WeatherPreferences preferences) async {
    final text = jsonEncode({
      'provider': preferences.provider.name,
      'criteria': {
        for (final e in preferences.criteriaByDrone.entries)
          '${e.key}': {
            'wind': e.value.maximumWindMs,
            'gust': e.value.maximumGustMs,
            'rain': e.value.maximumPrecipitationMm,
            'visibility': e.value.minimumVisibilityMeters,
          },
      },
    });
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: text,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }
}
