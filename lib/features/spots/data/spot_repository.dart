import 'package:drift/drift.dart';

import '../../../core/database/fpv_database.dart';

class SpotRepository {
  const SpotRepository(this.database);

  final FpvDatabase database;

  void _validate({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError('Spot name must contain 1–120 characters');
    }

    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError('Invalid latitude');
    }

    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid longitude');
    }
  }

  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
  }) {
    _validate(name: name, latitude: latitude, longitude: longitude);

    return database
        .into(database.spots)
        .insert(
          SpotsCompanion.insert(
            name: name.trim(),
            latitude: latitude,
            longitude: longitude,
            notes: Value(notes),
          ),
        );
  }

  Future<List<Spot>> getAllSpots() {
    return (database.select(database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Stream<List<Spot>> watchSpots() {
    return (database.select(database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<Spot?> getSpot(int id) {
    return (database.select(
      database.spots,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<bool> updateSpot({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    _validate(name: name, latitude: latitude, longitude: longitude);

    final changed =
        await (database.update(
          database.spots,
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

  Future<int> deleteSpot(int id) {
    return (database.delete(
      database.spots,
    )..where((table) => table.id.equals(id))).go();
  }
}
