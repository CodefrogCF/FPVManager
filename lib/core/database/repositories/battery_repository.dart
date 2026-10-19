import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';

/// Local records only. The caller owns and closes the injected database.
abstract interface class BatteryRepository {
  const factory BatteryRepository(FpvDatabase database) =
      DriftBatteryRepository;

  Future<int> createBattery({
    required String name,
    String chemistry = 'LiPo',
    required int cellCount,
    required int capacityMah,
    double? weightGrams,
    int cycleCount = 0,
    String? notes,
  });
  Future<Battery?> getBattery(int id);
  Future<List<Battery>> getAllBatteries();
  Stream<List<Battery>> watchBatteries();
  Future<bool> updateBattery({
    required int id,
    required String name,
    String chemistry = 'LiPo',
    required int cellCount,
    required int capacityMah,
    double? weightGrams,
    int cycleCount = 0,
    String? notes,
  });
  Future<int> deleteBattery(int id);
}

final class DriftBatteryRepository implements BatteryRepository {
  const DriftBatteryRepository(this._database);
  final FpvDatabase _database;

  @override
  Future<int> createBattery({
    required String name,
    String chemistry = 'LiPo',
    required int cellCount,
    required int capacityMah,
    double? weightGrams,
    int cycleCount = 0,
    String? notes,
  }) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(chemistry, 'chemistry');
    RepositoryValidation.positive(cellCount, 'cellCount');
    RepositoryValidation.positive(capacityMah, 'capacityMah');
    RepositoryValidation.positive(weightGrams, 'weightGrams');
    RepositoryValidation.positive(cycleCount, 'cycleCount', allowZero: true);
    return _database
        .into(_database.batteries)
        .insert(
          BatteriesCompanion.insert(
            name: name.trim(),
            chemistry: Value(chemistry.trim()),
            cellCount: cellCount,
            capacityMah: capacityMah,
            weightGrams: Value(weightGrams),
            cycleCount: Value(cycleCount),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<Battery?> getBattery(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.batteries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Battery>> getAllBatteries() =>
      (_database.select(_database.batteries)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .get();

  @override
  Stream<List<Battery>> watchBatteries() =>
      (_database.select(_database.batteries)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .watch();

  @override
  Future<bool> updateBattery({
    required int id,
    required String name,
    String chemistry = 'LiPo',
    required int cellCount,
    required int capacityMah,
    double? weightGrams,
    int cycleCount = 0,
    String? notes,
  }) async {
    RepositoryValidation.id(id);
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(chemistry, 'chemistry');
    RepositoryValidation.positive(cellCount, 'cellCount');
    RepositoryValidation.positive(capacityMah, 'capacityMah');
    RepositoryValidation.positive(weightGrams, 'weightGrams');
    RepositoryValidation.positive(cycleCount, 'cycleCount', allowZero: true);
    final changed =
        await (_database.update(
          _database.batteries,
        )..where((table) => table.id.equals(id))).write(
          BatteriesCompanion(
            name: Value(name.trim()),
            chemistry: Value(chemistry.trim()),
            cellCount: Value(cellCount),
            capacityMah: Value(capacityMah),
            weightGrams: Value(weightGrams),
            cycleCount: Value(cycleCount),
            notes: Value(notes),
          ),
        );
    return changed > 0;
  }

  @override
  Future<int> deleteBattery(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.batteries,
    )..where((table) => table.id.equals(id))).go();
  }
}
