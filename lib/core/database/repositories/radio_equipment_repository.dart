import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';
import '../../models/radio_profile.dart';

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
  Future<int> saveProfile(RadioProfileInput input, {int? id});
  Future<RadioProfile?> getProfile(int id);
  Stream<RadioProfile?> watchProfile(int id);
  Future<List<Drone>> getDrones();
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
  }) => saveProfile(
    RadioProfileInput(
      name: name,
      category: category,
      parameters: {
        RadioParameter.frequencyMhz: ?frequencyMhz,
        RadioParameter.maxPowerMw: ?maxPowerMw,
      },
      descriptions: {RadioTextField.notes: ?notes},
    ),
  );

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
    return _database.transaction(() async {
      final profile = await getProfile(id);
      if (profile == null) return false;
      // The legacy API replaces its original fields while retaining RF details
      // and drone assignments introduced by the profile editor.
      await saveProfile(
        RadioProfileInput(
          name: name,
          category: category,
          parameters: {
            for (final field in RadioParameter.values)
              if (field != RadioParameter.frequencyMhz &&
                  field != RadioParameter.maxPowerMw)
                field: ?field.read(profile.equipment),
            RadioParameter.frequencyMhz: ?frequencyMhz,
            RadioParameter.maxPowerMw: ?maxPowerMw,
          },
          descriptions: {
            for (final field in RadioTextField.values)
              if (field != RadioTextField.notes)
                field: ?field.read(profile.equipment),
            RadioTextField.notes: ?notes,
          },
          droneIds: profile.drones.map((row) => row.id).toSet(),
        ),
        id: id,
      );
      return true;
    });
  }

  @override
  Future<int> saveProfile(RadioProfileInput input, {int? id}) async {
    input.validate();
    RepositoryValidation.optionalId(id);
    return _database.transaction(() async {
      if (id != null && await getEquipment(id) == null) {
        throw StateError('Equipment no longer exists');
      }
      String? description(RadioTextField field) {
        final text = input.descriptions[field]?.trim();
        return text == null || text.isEmpty ? null : text;
      }

      final values = RadioEquipmentCompanion.insert(
        name: input.name.trim(),
        category: input.category.trim(),
        frequencyMhz: Value(input.parameters[RadioParameter.frequencyMhz]),
        maxPowerMw: Value(input.parameters[RadioParameter.maxPowerMw]),
        bandwidthKhz: Value(input.parameters[RadioParameter.bandwidthKhz]),
        sensitivityDbm: Value(input.parameters[RadioParameter.sensitivityDbm]),
        txGainDbi: Value(input.parameters[RadioParameter.txGainDbi]),
        rxGainDbi: Value(input.parameters[RadioParameter.rxGainDbi]),
        txLossDb: Value(input.parameters[RadioParameter.txLossDb]),
        rxLossDb: Value(input.parameters[RadioParameter.rxLossDb]),
        protocol: Value(description(RadioTextField.protocol)),
        transmitter: Value(description(RadioTextField.transmitter)),
        receiver: Value(description(RadioTextField.receiver)),
        txAntenna: Value(description(RadioTextField.txAntenna)),
        rxAntenna: Value(description(RadioTextField.rxAntenna)),
        txPolarization: Value(description(RadioTextField.txPolarization)),
        rxPolarization: Value(description(RadioTextField.rxPolarization)),
        receiverSpecifications: Value(
          description(RadioTextField.receiverSpecifications),
        ),
        specificationSource: Value(
          description(RadioTextField.specificationSource),
        ),
        notes: Value(input.descriptions[RadioTextField.notes]),
      );
      final equipmentId =
          id ?? await _database.into(_database.radioEquipment).insert(values);
      if (id != null) {
        await (_database.update(
          _database.radioEquipment,
        )..where((t) => t.id.equals(id))).write(values);
      }
      await (_database.delete(
        _database.radioEquipmentDrones,
      )..where((t) => t.equipmentId.equals(equipmentId))).go();
      await _database.batch(
        (batch) => batch.insertAll(_database.radioEquipmentDrones, [
          for (final droneId in input.droneIds)
            RadioEquipmentDronesCompanion.insert(
              equipmentId: equipmentId,
              droneId: droneId,
            ),
        ]),
      );
      return equipmentId;
    });
  }

  @override
  Future<List<Drone>> getDrones() => (_database.select(
    _database.drones,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  @override
  Future<RadioProfile?> getProfile(int id) {
    RepositoryValidation.id(id);
    return _database.transaction(() async {
      final equipment = await getEquipment(id);
      if (equipment == null) return null;
      final rows =
          await (_database.select(_database.drones).join([
                  innerJoin(
                    _database.radioEquipmentDrones,
                    _database.radioEquipmentDrones.droneId.equalsExp(
                      _database.drones.id,
                    ),
                  ),
                ])
                ..where(_database.radioEquipmentDrones.equipmentId.equals(id))
                ..orderBy([OrderingTerm.asc(_database.drones.name)]))
              .get();
      return RadioProfile(
        equipment: equipment,
        drones: [for (final row in rows) row.readTable(_database.drones)],
      );
    });
  }

  @override
  Stream<RadioProfile?> watchProfile(int id) {
    RepositoryValidation.id(id);
    return _database
        .customSelect(
          'SELECT id FROM radio_equipment WHERE id = ?',
          variables: [Variable.withInt(id)],
          readsFrom: {
            _database.radioEquipment,
            _database.radioEquipmentDrones,
            _database.drones,
          },
        )
        .watch()
        .asyncMap((_) => getProfile(id));
  }

  @override
  Future<int> deleteEquipment(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.radioEquipment,
    )..where((table) => table.id.equals(id))).go();
  }
}
