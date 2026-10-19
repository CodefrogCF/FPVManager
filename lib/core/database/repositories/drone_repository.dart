import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';

/// Local records only. The caller owns and closes the injected database.
abstract interface class DroneRepository {
  const factory DroneRepository(FpvDatabase database) = DriftDroneRepository;

  Future<int> createDrone({
    required String name,
    String type = 'quadcopter',
    double? takeoffWeightGrams,
    double? maxSpeedMetersPerSecond,
    String? notes,
  });
  Future<Drone?> getDrone(int id);
  Future<List<Drone>> getAllDrones();
  Stream<List<Drone>> watchDrones();
  Future<bool> updateDrone({
    required int id,
    required String name,
    String type = 'quadcopter',
    double? takeoffWeightGrams,
    double? maxSpeedMetersPerSecond,
    String? notes,
  });
  Future<int> deleteDrone(int id);
}

final class DriftDroneRepository implements DroneRepository {
  const DriftDroneRepository(this._database);
  final FpvDatabase _database;

  @override
  Future<int> createDrone({
    required String name,
    String type = 'quadcopter',
    double? takeoffWeightGrams,
    double? maxSpeedMetersPerSecond,
    String? notes,
  }) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(type, 'type');
    RepositoryValidation.positive(takeoffWeightGrams, 'takeoffWeightGrams');
    RepositoryValidation.positive(
      maxSpeedMetersPerSecond,
      'maxSpeedMetersPerSecond',
    );
    return _database
        .into(_database.drones)
        .insert(
          DronesCompanion.insert(
            name: name.trim(),
            type: Value(type.trim()),
            takeoffWeightGrams: Value(takeoffWeightGrams),
            maxSpeedMetersPerSecond: Value(maxSpeedMetersPerSecond),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<Drone?> getDrone(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.drones,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Drone>> getAllDrones() =>
      (_database.select(_database.drones)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .get();

  @override
  Stream<List<Drone>> watchDrones() =>
      (_database.select(_database.drones)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .watch();

  @override
  Future<bool> updateDrone({
    required int id,
    required String name,
    String type = 'quadcopter',
    double? takeoffWeightGrams,
    double? maxSpeedMetersPerSecond,
    String? notes,
  }) async {
    RepositoryValidation.id(id);
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(type, 'type');
    RepositoryValidation.positive(takeoffWeightGrams, 'takeoffWeightGrams');
    RepositoryValidation.positive(
      maxSpeedMetersPerSecond,
      'maxSpeedMetersPerSecond',
    );
    final changed =
        await (_database.update(
          _database.drones,
        )..where((table) => table.id.equals(id))).write(
          DronesCompanion(
            name: Value(name.trim()),
            type: Value(type.trim()),
            takeoffWeightGrams: Value(takeoffWeightGrams),
            maxSpeedMetersPerSecond: Value(maxSpeedMetersPerSecond),
            notes: Value(notes),
          ),
        );
    return changed > 0;
  }

  @override
  Future<int> deleteDrone(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.drones,
    )..where((table) => table.id.equals(id))).go();
  }
}
