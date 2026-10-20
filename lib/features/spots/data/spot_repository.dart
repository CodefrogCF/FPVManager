import 'package:drift/drift.dart';

import '../../../core/database/fpv_database.dart';
import '../../../core/database/repository_validation.dart';
import 'spot_photo.dart';

abstract interface class SpotRepository {
  const factory SpotRepository(FpvDatabase database) = DriftSpotRepository;

  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<PreparedSpotPhoto> photos = const [],
  });
  Future<List<Spot>> getAllSpots();
  Stream<List<Spot>> watchSpots();
  Future<Spot?> getSpot(int id);
  Future<bool> updateSpot({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<int>? retainedPhotoIds,
    List<PreparedSpotPhoto> newPhotos = const [],
  });
  Future<int> deleteSpot(int id);
  Future<bool> setFavorite({required int id, required bool isFavorite});
  Future<List<SpotPhotoPreview>> getPhotos(int spotId);
  Stream<List<SpotPhotoPreview>> watchPhotos(int spotId);
  Future<Uint8List?> getPhotoBytes({required int spotId, required int photoId});
}

final class DriftSpotRepository implements SpotRepository {
  const DriftSpotRepository(this._database);

  final FpvDatabase _database;

  void _validate({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.coordinates(latitude, longitude);
  }

  @override
  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<PreparedSpotPhoto> photos = const [],
  }) {
    _validate(name: name, latitude: latitude, longitude: longitude);
    final prepared = _validatePhotos(photos);
    return _database.transaction(() async {
      final id = await _database
          .into(_database.spots)
          .insert(
            SpotsCompanion.insert(
              name: name.trim(),
              latitude: latitude,
              longitude: longitude,
              notes: Value(notes),
            ),
          );
      await _insertPhotos(id, prepared);
      return id;
    });
  }

  @override
  Future<List<Spot>> getAllSpots() {
    return (_database.select(_database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Stream<List<Spot>> watchSpots() {
    return (_database.select(_database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<Spot?> getSpot(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.spots,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<bool> updateSpot({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<int>? retainedPhotoIds,
    List<PreparedSpotPhoto> newPhotos = const [],
  }) async {
    RepositoryValidation.id(id);
    _validate(name: name, latitude: latitude, longitude: longitude);

    final prepared = _validatePhotos(newPhotos);
    final retained = retainedPhotoIds == null
        ? null
        : List<int>.unmodifiable(retainedPhotoIds);
    if (retained != null) {
      for (final photoId in retained) {
        RepositoryValidation.id(photoId);
      }
      if (retained.toSet().length != retained.length) {
        throw ArgumentError('Duplicate photo IDs');
      }
    }
    return _database.transaction(() async {
      final table = _database.spotPhotos;
      final existing =
          await (_database.selectOnly(table)
                ..addColumns([table.id])
                ..where(table.spotId.equals(id)))
              .map((row) => row.read(table.id)!)
              .get();
      if (retained != null &&
          !retained.every((photoId) => existing.contains(photoId))) {
        throw ArgumentError(
          'Photo does not belong to this spot or was removed',
        );
      }
      final keptCount = retained?.length ?? existing.length;
      if (keptCount + prepared.length > SpotPhotoLimits.maxPhotos) {
        throw ArgumentError('A spot can have at most six photos');
      }
      final changed =
          await (_database.update(
            _database.spots,
          )..where((table) => table.id.equals(id))).write(
            SpotsCompanion(
              name: Value(name.trim()),
              latitude: Value(latitude),
              longitude: Value(longitude),
              notes: Value(notes),
            ),
          );

      if (changed == 0) return false;
      if (retained != null) {
        await (_database.delete(_database.spotPhotos)..where(
              (table) => table.spotId.equals(id) & table.id.isNotIn(retained),
            ))
            .go();
      }
      await _insertPhotos(id, prepared);
      return true;
    });
  }

  @override
  Future<int> deleteSpot(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.spots,
    )..where((table) => table.id.equals(id))).go();
  }

  @override
  Future<bool> setFavorite({required int id, required bool isFavorite}) async {
    RepositoryValidation.id(id);
    return await (_database.update(_database.spots)
              ..where((table) => table.id.equals(id)))
            .write(SpotsCompanion(isFavorite: Value(isFavorite))) >
        0;
  }

  List<PreparedSpotPhoto> _validatePhotos(List<PreparedSpotPhoto> photos) {
    final snapshot = List<PreparedSpotPhoto>.unmodifiable(photos);
    if (snapshot.length > SpotPhotoLimits.maxPhotos) {
      throw ArgumentError('A spot can have at most six photos');
    }
    for (final photo in snapshot) {
      bool isJpeg(Uint8List bytes, int limit) =>
          bytes.length >= 4 &&
          bytes.length <= limit &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[bytes.length - 2] == 0xff &&
          bytes.last == 0xd9;
      if (photo.width <= 0 ||
          photo.height <= 0 ||
          photo.width > SpotPhotoLimits.maxImageEdge ||
          photo.height > SpotPhotoLimits.maxImageEdge ||
          !isJpeg(photo.imageBytes, SpotPhotoLimits.maxImageBytes) ||
          !isJpeg(photo.thumbnailBytes, SpotPhotoLimits.maxThumbnailBytes)) {
        throw ArgumentError('Invalid prepared spot photo');
      }
    }
    return snapshot;
  }

  Future<void> _insertPhotos(int spotId, List<PreparedSpotPhoto> photos) =>
      _database.batch((batch) {
        batch.insertAll(_database.spotPhotos, [
          for (final photo in photos)
            SpotPhotosCompanion.insert(
              spotId: spotId,
              imageBytes: photo.imageBytes,
              thumbnailBytes: photo.thumbnailBytes,
              width: photo.width,
              height: photo.height,
            ),
        ]);
      });

  Selectable<SpotPhotoPreview> _photoQuery(int spotId) {
    RepositoryValidation.id(spotId);
    final table = _database.spotPhotos;
    return (_database.selectOnly(table)
          ..addColumns([
            table.id,
            table.spotId,
            table.thumbnailBytes,
            table.width,
            table.height,
          ])
          ..where(table.spotId.equals(spotId))
          ..orderBy([OrderingTerm.asc(table.id)]))
        .map(
          (row) => SpotPhotoPreview(
            id: row.read(table.id)!,
            spotId: row.read(table.spotId)!,
            thumbnailBytes: row
                .read(table.thumbnailBytes)!
                .asUnmodifiableView(),
            width: row.read(table.width)!,
            height: row.read(table.height)!,
          ),
        );
  }

  @override
  Future<List<SpotPhotoPreview>> getPhotos(int spotId) =>
      _photoQuery(spotId).get();

  @override
  Stream<List<SpotPhotoPreview>> watchPhotos(int spotId) =>
      _photoQuery(spotId).watch();

  @override
  Future<Uint8List?> getPhotoBytes({
    required int spotId,
    required int photoId,
  }) async {
    RepositoryValidation.id(spotId);
    RepositoryValidation.id(photoId);
    final table = _database.spotPhotos;
    final row =
        await (_database.selectOnly(table)
              ..addColumns([table.imageBytes])
              ..where(table.spotId.equals(spotId) & table.id.equals(photoId)))
            .getSingleOrNull();
    return row?.read(table.imageBytes)?.asUnmodifiableView();
  }
}
