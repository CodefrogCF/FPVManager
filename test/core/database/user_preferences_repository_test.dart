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
    expect(defaults.savedSpotsVisible, isTrue);
    expect(defaults.obstacleModelsVisible, isFalse);
    expect(defaults.overlayOrder, [
      GlobeOverlay.uasZones,
      GlobeOverlay.savedSpots,
    ]);
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
          savedSpotsVisible: false,
          roadsVisible: true,
          roadsOpacity: .6,
          avalancheVisible: true,
          avalancheOpacity: .4,
          buildings3dVisible: true,
          vegetation3dVisible: true,
          realisticLighting: true,
          hazardAreasVisible: true,
          obstacleModelsVisible: true,
          obstacleBufferMeters: 75,
          overlayOrder: [GlobeOverlay.savedSpots, GlobeOverlay.uasZones],
        ),
      );
      expect(await queue.moveNext(), isTrue);
      expect(queue.current.mapStyle, GlobeMapStyle.relief);
      expect(queue.current.uasZonesVisible, isTrue);
      expect(queue.current.uasZonesFillOpacity, .8);
      expect(queue.current.savedSpotsVisible, isFalse);
      expect(queue.current.roadsVisible, isTrue);
      expect(queue.current.roadsOpacity, .6);
      expect(queue.current.avalancheVisible, true);
      expect(queue.current.avalancheOpacity, .4);
      expect(queue.current.buildings3dVisible, isTrue);
      expect(queue.current.vegetation3dVisible, isTrue);
      expect(queue.current.realisticLighting, isTrue);
      expect(queue.current.hazardAreasVisible, isTrue);
      expect(queue.current.obstacleModelsVisible, isTrue);
      expect(
        (await UserPreferencesRepository(
          database,
        ).getPreferences()).obstacleModelsVisible,
        isTrue,
      );
      expect(queue.current.obstacleBufferMeters, 75);
      expect(queue.current.overlayOrder.first, GlobeOverlay.savedSpots);
      final rows = await database.select(database.appSettings).get();
      expect(rows, hasLength(20));
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
      expect(await database.select(database.appSettings).get(), hasLength(20));
      await repository.resetPreferences();
      expect(
        (await repository.getPreferences()).obstacleModelsVisible,
        isFalse,
      );
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
      'map.spots.visible': 'yes',
      'map.overlayOrder': '["savedSpots","savedSpots"]',
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

  test(
    'old three-key settings gain defaults without being rewritten',
    () async {
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'map.style', value: 'relief'),
          );
      final preferences = await repository.getPreferences();
      expect(preferences.mapStyle, GlobeMapStyle.relief);
      expect(preferences.savedSpotsVisible, isTrue);
      expect(preferences.overlayOrder, const UserPreferences().overlayOrder);
      expect(await database.select(database.appSettings).get(), hasLength(1));
    },
  );

  test('invalid overlay orders cannot overwrite preferences', () async {
    for (final order in [
      <GlobeOverlay>[],
      [GlobeOverlay.savedSpots],
      [GlobeOverlay.uasZones, GlobeOverlay.uasZones],
    ]) {
      await expectLater(
        () => repository.savePreferences(UserPreferences(overlayOrder: order)),
        throwsArgumentError,
      );
    }
    for (final raw in [
      'null',
      '{}',
      '[]',
      '["unknown","savedSpots"]',
      '[1,2]',
    ]) {
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: 'map.overlayOrder', value: raw),
          );
      await expectLater(repository.getPreferences, throwsFormatException);
    }
  });

  test('saving snapshots a caller-owned mutable overlay list', () async {
    final order = [GlobeOverlay.savedSpots, GlobeOverlay.uasZones];
    final saving = repository.savePreferences(
      UserPreferences(overlayOrder: order),
    );
    order.clear();
    await saving;
    expect((await repository.getPreferences()).overlayOrder, [
      GlobeOverlay.savedSpots,
      GlobeOverlay.uasZones,
    ]);
  });
}
