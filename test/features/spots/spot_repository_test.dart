import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

void main() {
  late FpvDatabase database;
  late SpotRepository repository;

  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('SpotRepository', () {
    test(
      'favorite changes preserve spot data and survive full edits',
      () async {
        final id = await repository.createSpot(
          name: ' Original ',
          latitude: 47,
          longitude: 8,
          notes: 'Private',
        );
        final original = (await repository.getSpot(id))!;
        expect(original.name, 'Original');
        final changed = repository.watchSpots().firstWhere(
          (rows) => rows.any((spot) => spot.isFavorite),
        );
        expect(await repository.setFavorite(id: id, isFavorite: true), isTrue);
        expect((await changed).single.id, id);
        final favorite = (await repository.getSpot(id))!;
        expect(favorite.name, original.name);
        expect(favorite.notes, original.notes);
        expect(favorite.latitude, original.latitude);
        expect(favorite.longitude, original.longitude);
        expect(favorite.createdAt, original.createdAt);
        await repository.updateSpot(
          id: id,
          name: 'Edited',
          latitude: 46,
          longitude: 7,
        );
        final updated = (await repository.getSpot(id))!;
        expect(updated.isFavorite, isTrue);
        expect(updated.notes, isNull);
        expect(updated.createdAt, original.createdAt);
        expect(
          await repository.setFavorite(id: 999, isFavorite: true),
          isFalse,
        );
      },
    );

    test('invalid edits and IDs cannot overwrite a saved spot', () async {
      final id = await repository.createSpot(
        name: 'Original',
        latitude: 47,
        longitude: 8,
      );
      for (final operation in <Future<Object?> Function()>[
        () => repository.updateSpot(
          id: id,
          name: 'Changed',
          latitude: double.nan,
          longitude: 8,
        ),
        () => repository.getSpot(0),
        () => repository.deleteSpot(-1),
        () => repository.setFavorite(id: 0, isFavorite: true),
      ]) {
        await expectLater(operation, throwsArgumentError);
      }
      expect((await repository.getSpot(id))!.name, 'Original');
    });

    test('creates and retrieves a spot', () async {
      final id = await repository.createSpot(
        name: 'Test Spot',
        latitude: 46.95108,
        longitude: 7.43863,
        notes: 'First FPVManager spot',
      );

      final spot = await repository.getSpot(id);

      expect(spot, isNotNull);
      expect(spot!.name, 'Test Spot');
      expect(spot.latitude, 46.95108);
      expect(spot.longitude, 7.43863);
      expect(spot.notes, 'First FPVManager spot');
    });

    test('updates an existing spot', () async {
      final id = await repository.createSpot(
        name: 'Original',
        latitude: 46.7,
        longitude: 8.4,
      );

      final updated = await repository.updateSpot(
        id: id,
        name: 'Updated',
        latitude: 47.0,
        longitude: 8.5,
      );

      expect(updated, isTrue);

      final spot = await repository.getSpot(id);
      expect(spot!.name, 'Updated');
      expect(spot.latitude, 47.0);
    });

    test('deletes a spot', () async {
      final id = await repository.createSpot(
        name: 'Delete Me',
        latitude: 46.7,
        longitude: 8.4,
      );

      expect(await repository.deleteSpot(id), 1);
      expect(await repository.getSpot(id), isNull);
    });

    test('rejects invalid coordinates', () {
      expect(
        () =>
            repository.createSpot(name: 'Invalid', latitude: 100, longitude: 8),
        throwsArgumentError,
      );
    });

    test('rejects empty spot names', () {
      expect(
        () =>
            repository.createSpot(name: '   ', latitude: 46.7, longitude: 8.4),
        throwsArgumentError,
      );
    });

    test('returns all saved spots', () async {
      await repository.createSpot(
        name: 'Spot A',
        latitude: 46.7,
        longitude: 8.4,
      );

      await repository.createSpot(
        name: 'Spot B',
        latitude: 47.0,
        longitude: 8.5,
      );

      final spots = await repository.getAllSpots();

      expect(spots.length, 2);
      expect(spots.first.name, 'Spot B');
    });
  });
}
