import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';
import '../../models/battery_profile.dart';

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
  Future<int> saveProfile(BatteryInput input, {int? id});
  Future<BatteryProfile?> getProfile(int id);
  Stream<BatteryProfile?> watchProfile(int id);
  Future<BatteryAssignmentOptions> getAssignmentOptions();
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
  }) => saveProfile(
    BatteryInput(
      name: name,
      chemistry: chemistry,
      cellCount: cellCount,
      capacityMah: capacityMah,
      weightGrams: weightGrams,
      cycleCount: cycleCount,
      notes: notes,
    ),
  );

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
    final input = BatteryInput(
      name: name,
      chemistry: chemistry,
      cellCount: cellCount,
      capacityMah: capacityMah,
      weightGrams: weightGrams,
      cycleCount: cycleCount,
      notes: notes,
    );
    input.validate();
    return _database.transaction(() async {
      if (await getBattery(id) == null) return false;
      await saveProfile(input, id: id);
      return true;
    });
  }

  @override
  Future<int> saveProfile(BatteryInput input, {int? id}) async {
    input.validate();
    RepositoryValidation.optionalId(id);
    return _database.transaction(() async {
      if (id != null) {
        final current = await getBattery(id);
        if (current == null) throw StateError('Battery no longer exists');
        if (current.isType != input.isType) {
          throw ArgumentError('Record kind cannot change');
        }
      }
      if (input.typeId != null) {
        final type = await getBattery(input.typeId!);
        if (type == null || !type.isType) {
          throw ArgumentError('Select an existing battery type');
        }
      }
      final values = BatteriesCompanion.insert(
        name: input.name.trim(),
        chemistry: Value(input.chemistry.trim()),
        cellCount: input.cellCount,
        capacityMah: input.capacityMah,
        weightGrams: Value(input.weightGrams),
        cycleCount: Value(input.cycleCount),
        notes: Value(input.notes),
        isType: Value(input.isType),
        typeId: Value(input.typeId),
        nominalVoltageVolts: Value(input.nominalVoltageVolts),
        energyWh: Value(input.energyWh),
        chargePercent: Value(input.chargePercent),
        availability: Value(input.availability.name),
        conditionNotes: Value(input.conditionNotes),
      );
      final batteryId =
          id ?? await _database.into(_database.batteries).insert(values);
      if (id != null) {
        await (_database.update(
          _database.batteries,
        )..where((t) => t.id.equals(id))).write(values);
      }
      await (_database.delete(
        _database.batteryDrones,
      )..where((t) => t.batteryId.equals(batteryId))).go();
      await (_database.delete(
        _database.batteryFlightPlans,
      )..where((t) => t.batteryId.equals(batteryId))).go();
      await _database.batch((batch) {
        batch.insertAll(_database.batteryDrones, [
          for (final droneId in input.droneIds)
            BatteryDronesCompanion.insert(
              batteryId: batteryId,
              droneId: droneId,
            ),
        ]);
        batch.insertAll(_database.batteryFlightPlans, [
          for (final planId in input.flightPlanIds)
            BatteryFlightPlansCompanion.insert(
              batteryId: batteryId,
              planId: planId,
            ),
        ]);
      });
      return batteryId;
    });
  }

  @override
  Future<BatteryProfile?> getProfile(int id) {
    RepositoryValidation.id(id);
    return _database.transaction(() async {
      final battery = await getBattery(id);
      if (battery == null) return null;
      final droneRows =
          await (_database.select(_database.drones).join([
                  innerJoin(
                    _database.batteryDrones,
                    _database.batteryDrones.droneId.equalsExp(
                      _database.drones.id,
                    ),
                  ),
                ])
                ..where(_database.batteryDrones.batteryId.equals(id))
                ..orderBy([OrderingTerm.asc(_database.drones.name)]))
              .get();
      final planRows =
          await (_database.select(_database.flightPlans).join([
                  innerJoin(
                    _database.batteryFlightPlans,
                    _database.batteryFlightPlans.planId.equalsExp(
                      _database.flightPlans.id,
                    ),
                  ),
                ])
                ..where(_database.batteryFlightPlans.batteryId.equals(id))
                ..orderBy([OrderingTerm.asc(_database.flightPlans.name)]))
              .get();
      return BatteryProfile(
        battery: battery,
        type: battery.typeId == null ? null : await getBattery(battery.typeId!),
        drones: [for (final row in droneRows) row.readTable(_database.drones)],
        flightPlans: [
          for (final row in planRows) row.readTable(_database.flightPlans),
        ],
      );
    });
  }

  @override
  Stream<BatteryProfile?> watchProfile(int id) {
    RepositoryValidation.id(id);
    return _database
        .customSelect(
          'SELECT id FROM batteries WHERE id = ?',
          variables: [Variable.withInt(id)],
          readsFrom: {
            _database.batteries,
            _database.batteryDrones,
            _database.batteryFlightPlans,
            _database.drones,
            _database.flightPlans,
          },
        )
        .watch()
        .asyncMap((_) => getProfile(id));
  }

  @override
  Future<BatteryAssignmentOptions> getAssignmentOptions() =>
      _database.transaction(() async {
        final types =
            await (_database.select(_database.batteries)
                  ..where((t) => t.isType.equals(true))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get();
        final drones = await (_database.select(
          _database.drones,
        )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
        final plans = await (_database.select(
          _database.flightPlans,
        )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
        return BatteryAssignmentOptions(
          types: types,
          drones: drones,
          flightPlans: plans,
        );
      });

  @override
  Future<int> deleteBattery(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.batteries,
    )..where((table) => table.id.equals(id))).go();
  }
}
