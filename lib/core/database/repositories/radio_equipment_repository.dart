import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';

/// Local records only. The caller owns and closes the injected database.
abstract interface class RadioEquipmentRepository {
  const factory RadioEquipmentRepository(FpvDatabase database) =
      DriftRadioEquipmentRepository;

  Future<int> createEquipment({
    required String name,
    required String category,
    double? frequencyMhz,
    double? maxPowerMw,
    String? notes,
  });
  Future<RadioEquipmentData?> getEquipment(int id);
  Future<List<RadioEquipmentData>> getAllEquipment();
  Stream<List<RadioEquipmentData>> watchEquipment();
  Future<bool> updateEquipment({
    required int id,
    required String name,
    required String category,
    double? frequencyMhz,
    double? maxPowerMw,
    String? notes,
  });
  Future<int> deleteEquipment(int id);
}

final class DriftRadioEquipmentRepository implements RadioEquipmentRepository {
  const DriftRadioEquipmentRepository(this._database);
  final FpvDatabase _database;

  @override
  Future<int> createEquipment({
    required String name,
    required String category,
    double? frequencyMhz,
    double? maxPowerMw,
    String? notes,
  }) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(category, 'category');
    RepositoryValidation.positive(frequencyMhz, 'frequencyMhz');
    RepositoryValidation.positive(maxPowerMw, 'maxPowerMw', allowZero: true);
    return _database
        .into(_database.radioEquipment)
        .insert(
          RadioEquipmentCompanion.insert(
            name: name.trim(),
            category: category.trim(),
            frequencyMhz: Value(frequencyMhz),
            maxPowerMw: Value(maxPowerMw),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<RadioEquipmentData?> getEquipment(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.radioEquipment,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<RadioEquipmentData>> getAllEquipment() =>
      (_database.select(_database.radioEquipment)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .get();

  @override
  Stream<List<RadioEquipmentData>> watchEquipment() =>
      (_database.select(_database.radioEquipment)..orderBy([
            (table) =>
                OrderingTerm(expression: table.id, mode: OrderingMode.desc),
          ]))
          .watch();

  @override
  Future<bool> updateEquipment({
    required int id,
    required String name,
    required String category,
    double? frequencyMhz,
    double? maxPowerMw,
    String? notes,
  }) async {
    RepositoryValidation.id(id);
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(category, 'category');
    RepositoryValidation.positive(frequencyMhz, 'frequencyMhz');
    RepositoryValidation.positive(maxPowerMw, 'maxPowerMw', allowZero: true);
    final changed =
        await (_database.update(
          _database.radioEquipment,
        )..where((table) => table.id.equals(id))).write(
          RadioEquipmentCompanion(
            name: Value(name.trim()),
            category: Value(category.trim()),
            frequencyMhz: Value(frequencyMhz),
            maxPowerMw: Value(maxPowerMw),
            notes: Value(notes),
          ),
        );
    return changed > 0;
  }

  @override
  Future<int> deleteEquipment(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.radioEquipment,
    )..where((table) => table.id.equals(id))).go();
  }
}
