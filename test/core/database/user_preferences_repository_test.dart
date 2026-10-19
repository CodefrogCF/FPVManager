import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';

void main() {
  late FpvDatabase database;
  late UserPreferencesRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = UserPreferencesRepository(database);
  });
  tearDown(() => database.close());

  test('defaults are returned without creating settings', () async {
    final defaults = await repository.getPreferences();
    expect(defaults.mapStyle, GlobeMapStyle.satellite);
    expect(defaults.uasZonesVisible, isFalse);
    expect(defaults.uasZonesFillOpacity, 0.20);
    expect(await database.select(database.appSettings).get(), isEmpty);
  });

  test(
    'save is an atomic snapshot and upsert; reset preserves unrelated keys',
    () async {
      await database
          .into(database.appSettings)
          .insert(AppSettingsCompanion.insert(key: 'unrelated', value: 'keep'));
      final queue = StreamIterator(repository.watchPreferences());
      addTearDown(queue.cancel);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current.mapStyle, GlobeMapStyle.satellite);
      await repository.savePreferences(
        const UserPreferences(
          mapStyle: GlobeMapStyle.relief,
          uasZonesVisible: true,
          uasZonesFillOpacity: .8,
        ),
      );
      expect(await queue.moveNext(), isTrue);
      expect(queue.current.mapStyle, GlobeMapStyle.relief);
      expect(queue.current.uasZonesVisible, isTrue);
      expect(queue.current.uasZonesFillOpacity, .8);
      final rows = await database.select(database.appSettings).get();
      expect(rows, hasLength(4));
      expect(
        rows
            .where((row) => row.key != 'unrelated')
            .map((row) => row.updatedAt)
            .toSet(),
        hasLength(1),
      );
      await repository.savePreferences(
        const UserPreferences(
          mapStyle: GlobeMapStyle.topographic,
          uasZonesFillOpacity: 0,
        ),
      );
      expect(
        (await repository.getPreferences()).mapStyle,
        GlobeMapStyle.topographic,
      );
      expect(await database.select(database.appSettings).get(), hasLength(4));
      await repository.resetPreferences();
      expect(
        (await repository.getPreferences()).mapStyle,
        GlobeMapStyle.satellite,
      );
      expect(
        (await database.select(database.appSettings).get()).single.key,
        'unrelated',
      );
    },
  );

  test('invalid opacity cannot overwrite saved preferences', () async {
    await repository.savePreferences(
      const UserPreferences(mapStyle: GlobeMapStyle.relief),
    );
    for (final opacity in [-.01, 1.01, double.nan, double.infinity]) {
      await expectLater(
        () => repository.savePreferences(
          UserPreferences(uasZonesFillOpacity: opacity),
        ),
        throwsArgumentError,
      );
      expect(
        (await repository.getPreferences()).mapStyle,
        GlobeMapStyle.relief,
      );
    }
  });

  test('malformed owned settings fail explicitly and can be reset', () async {
    for (final entry in {
      'map.style': 'unknown',
      'map.uas.visible': 'yes',
      'map.uas.fillOpacity': 'NaN',
    }.entries) {
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: entry.key, value: entry.value),
          );
      await expectLater(repository.getPreferences, throwsFormatException);
      await expectLater(
        repository.watchPreferences(),
        emitsError(isFormatException),
      );
      await repository.resetPreferences();
      expect((await repository.getPreferences()).uasZonesFillOpacity, .2);
    }
  });
}
