import 'package:drift/drift.dart';

import '../../../core/database/fpv_database.dart';
import '../../../core/database/repository_validation.dart';

abstract interface class SpotRepository {
  const factory SpotRepository(FpvDatabase database) = DriftSpotRepository;

  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
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
  });
  Future<int> deleteSpot(int id);
  Future<bool> setFavorite({required int id, required bool isFavorite});
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
  }) {
    _validate(name: name, latitude: latitude, longitude: longitude);

    return _database
        .into(_database.spots)
        .insert(
          SpotsCompanion.insert(
            name: name.trim(),
            latitude: latitude,
            longitude: longitude,
            notes: Value(notes),
          ),
        );
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
  }) async {
    RepositoryValidation.id(id);
    _validate(name: name, latitude: latitude, longitude: longitude);

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

    return changed > 0;
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
}
