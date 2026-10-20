import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/spots/data/spot_photo.dart';
import 'package:fpvmanager/features/spots/data/spot_photo_service.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

void main() {
  late FpvDatabase database;
  late SpotRepository repository;
  late PreparedSpotPhoto photo;
  setUpAll(
    () =>
        photo = prepareSpotPhoto(img.encodeJpg(img.Image(width: 8, height: 4))),
  );
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
  });
  tearDown(() => database.close());

  Future<int> create({List<PreparedSpotPhoto> photos = const []}) =>
      repository.createSpot(
        name: 'Private spot',
        latitude: 47,
        longitude: 8,
        notes: 'Private notes',
        photos: photos,
      );

  test('stores photos locally and projects thumbnails separately', () async {
    final id = await create(photos: [photo]);
    final previews = await repository.getPhotos(id);
    expect(previews, hasLength(1));
    expect(previews.single.width, 8);
    expect(previews.single.height, 4);
    expect(previews.single.spotId, id);
    expect(previews.single.thumbnailBytes, photo.thumbnailBytes);
    expect(
      await repository.getPhotoBytes(spotId: id, photoId: previews.single.id),
      photo.imageBytes,
    );
    final otherId = await create();
    expect(
      await repository.getPhotoBytes(
        spotId: otherId,
        photoId: previews.single.id,
      ),
      isNull,
    );
    expect((await repository.getSpot(id))!.notes, 'Private notes');
    expect(await repository.getPhotos(999), isEmpty);
  });

  test(
    'metadata edits preserve photos unless an explicit photo set is supplied',
    () async {
      final id = await create(photos: [photo, photo]);
      final originals = await repository.getPhotos(id);
      await repository.setFavorite(id: id, isFavorite: true);
      await repository.updateSpot(
        id: id,
        name: 'Changed',
        latitude: 46,
        longitude: 7,
      );
      expect(
        (await repository.getPhotos(id)).map((photo) => photo.id),
        originals.map((photo) => photo.id),
      );
      await repository.updateSpot(
        id: id,
        name: 'Changed again',
        latitude: 46,
        longitude: 7,
        retainedPhotoIds: [originals.last.id],
        newPhotos: [photo],
      );
      final replaced = await repository.getPhotos(id);
      expect(replaced, hasLength(2));
      expect(replaced.first.id, originals.last.id);
      expect(
        await repository.getPhotoBytes(spotId: id, photoId: originals.first.id),
        isNull,
      );
      expect((await repository.getSpot(id))!.isFavorite, isTrue);
      await repository.updateSpot(
        id: id,
        name: 'No photos',
        latitude: 46,
        longitude: 7,
        retainedPhotoIds: [],
      );
      expect(await repository.getPhotos(id), isEmpty);
    },
  );

  test(
    'invalid photo counts and foreign photo IDs leave existing data unchanged',
    () async {
      final id = await create(photos: [photo]);
      final foreignId = await create(photos: [photo]);
      final foreignPhoto = (await repository.getPhotos(foreignId)).single.id;
      final ownPhoto = (await repository.getPhotos(id)).single.id;
      for (final ids in [
        [foreignPhoto],
        [ownPhoto, ownPhoto],
        [0],
      ]) {
        await expectLater(
          () => repository.updateSpot(
            id: id,
            name: 'Bad edit',
            latitude: 46,
            longitude: 7,
            retainedPhotoIds: ids,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        () => create(photos: List.filled(7, photo)),
        throwsArgumentError,
      );
      await expectLater(
        () => repository.updateSpot(
          id: id,
          name: 'Too many',
          latitude: 46,
          longitude: 7,
          newPhotos: List.filled(6, photo),
        ),
        throwsArgumentError,
      );
      expect((await repository.getSpot(id))!.name, 'Private spot');
      expect((await repository.getPhotos(id)).single.id, ownPhoto);
      expect(await repository.getAllSpots(), hasLength(2));
    },
  );

  test(
    'a photo write failure rolls back creation, edits and removed photos',
    () async {
      final id = await create(photos: [photo]);
      final original = (await repository.getPhotos(id)).single.id;
      await database.customStatement(
        "CREATE TRIGGER reject_photo BEFORE INSERT ON spot_photos BEGIN SELECT RAISE(ABORT, 'test write failure'); END",
      );
      await expectLater(() => create(photos: [photo]), throwsException);
      expect(await repository.getAllSpots(), hasLength(1));
      await expectLater(
        () => repository.updateSpot(
          id: id,
          name: 'Must roll back',
          latitude: 46,
          longitude: 7,
          retainedPhotoIds: [],
          newPhotos: [photo],
        ),
        throwsException,
      );
      expect((await repository.getSpot(id))!.name, 'Private spot');
      expect((await repository.getPhotos(id)).single.id, original);
    },
  );

  test(
    'watchers receive complete replacements and spot deletion cascades',
    () async {
      final id = await create(photos: [photo]);
      final queue = StreamIterator(repository.watchPhotos(id));
      addTearDown(queue.cancel);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, hasLength(1));
      await repository.updateSpot(
        id: id,
        name: 'Replaced',
        latitude: 47,
        longitude: 8,
        retainedPhotoIds: [],
        newPhotos: [photo, photo],
      );
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, hasLength(2));
      await repository.deleteSpot(id);
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, isEmpty);
      expect(await database.select(database.spotPhotos).get(), isEmpty);
    },
  );
}
