import 'package:drift/drift.dart';

import '../fpv_database.dart';
import '../repository_validation.dart';
import '../../models/drone_profile.dart';

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
  Future<int> createProfile(DroneProfileInput input);
  Future<bool> updateProfile({
    required int id,
    required DroneProfileInput input,
  });
  Future<DroneProfile?> getProfile(int id);
  Stream<DroneProfile?> watchProfile(int id);
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
    return _database.transaction(() async {
      final current = await getDrone(id);
      if (current == null) return false;
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
      final resetKeys = <String>[
        if (current.takeoffWeightGrams != takeoffWeightGrams)
          DroneParameter.takeoffWeightGrams.name,
        if (current.maxSpeedMetersPerSecond != maxSpeedMetersPerSecond)
          DroneParameter.maxSpeedMetersPerSecond.name,
      ];
      if (resetKeys.isNotEmpty) {
        await (_database.delete(_database.droneParameterSources)..where(
              (table) =>
                  table.droneId.equals(id) & table.parameterKey.isIn(resetKeys),
            ))
            .go();
      }
      return changed > 0;
    });
  }

  @override
  Future<int> deleteDrone(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.drones,
    )..where((table) => table.id.equals(id))).go();
  }

  String? _optionalText(String? value, String field, {int limit = 120}) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    if (clean.length > limit) {
      throw ArgumentError('$field must have at most $limit characters');
    }
    return clean;
  }

  DronesCompanion _profileValues(DroneProfileInput input) {
    final name = RepositoryValidation.text(input.name, 'name');
    final type = RepositoryValidation.text(input.type, 'type');
    return DronesCompanion(
      name: Value(name),
      type: Value(type),
      notes: Value(input.notes),
      configuration: Value(
        _optionalText(input.configuration, 'Configuration', limit: 4000),
      ),
      propellerDescription: Value(
        _optionalText(input.propellerDescription, 'Propeller description'),
      ),
      motorDescription: Value(
        _optionalText(input.motorDescription, 'Motor description'),
      ),
      escDescription: Value(
        _optionalText(input.escDescription, 'ESC description'),
      ),
      measurementContext: Value(
        _optionalText(
          input.measurementContext,
          'Measurement context',
          limit: 4000,
        ),
      ),
      takeoffWeightGrams: Value(input.value(DroneParameter.takeoffWeightGrams)),
      lengthMm: Value(input.value(DroneParameter.lengthMm)),
      widthMm: Value(input.value(DroneParameter.widthMm)),
      heightMm: Value(input.value(DroneParameter.heightMm)),
      propellerDiameterInches: Value(
        input.value(DroneParameter.propellerDiameterInches),
      ),
      propellerPitchInches: Value(
        input.value(DroneParameter.propellerPitchInches),
      ),
      propellerCount: Value(
        input.value(DroneParameter.propellerCount)?.toInt(),
      ),
      motorCount: Value(input.value(DroneParameter.motorCount)?.toInt()),
      motorKv: Value(input.value(DroneParameter.motorKv)),
      maxSpeedMetersPerSecond: Value(
        input.value(DroneParameter.maxSpeedMetersPerSecond),
      ),
      cruiseSpeedMetersPerSecond: Value(
        input.value(DroneParameter.cruiseSpeedMetersPerSecond),
      ),
      maxClimbRateMetersPerSecond: Value(
        input.value(DroneParameter.maxClimbRateMetersPerSecond),
      ),
      hoverPowerWatts: Value(input.value(DroneParameter.hoverPowerWatts)),
      cruisePowerWatts: Value(input.value(DroneParameter.cruisePowerWatts)),
      maxPowerWatts: Value(input.value(DroneParameter.maxPowerWatts)),
      referenceVoltageVolts: Value(
        input.value(DroneParameter.referenceVoltageVolts),
      ),
    );
  }

  Future<void> _writeSources(int id, DroneProfileInput input) async {
    final table = _database.droneParameterSources;
    await (_database.delete(
      table,
    )..where((table) => table.droneId.equals(id))).go();
    await _database.batch((batch) {
      batch.insertAll(table, [
        for (final entry in input.measurements.entries)
          if (entry.value.source != DroneValueSource.unspecified)
            DroneParameterSourcesCompanion.insert(
              droneId: id,
              parameterKey: entry.key.name,
              source: entry.value.source.name,
            ),
      ]);
    });
  }

  @override
  Future<int> createProfile(DroneProfileInput input) async {
    final values = _profileValues(input);
    return _database.transaction(() async {
      final id = await _database.into(_database.drones).insert(values);
      await _writeSources(id, input);
      return id;
    });
  }

  @override
  Future<bool> updateProfile({
    required int id,
    required DroneProfileInput input,
  }) async {
    RepositoryValidation.id(id);
    final values = _profileValues(input);
    return _database.transaction(() async {
      final changed = await (_database.update(
        _database.drones,
      )..where((table) => table.id.equals(id))).write(values);
      if (changed == 0) return false;
      await _writeSources(id, input);
      return true;
    });
  }

  Selectable<TypedResult> _profileQuery(int id) {
    RepositoryValidation.id(id);
    final drones = _database.drones;
    final sources = _database.droneParameterSources;
    return _database.select(drones).join([
      leftOuterJoin(sources, sources.droneId.equalsExp(drones.id)),
    ])..where(drones.id.equals(id));
  }

  DroneProfile? _readProfile(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    final drone = rows.first.readTable(_database.drones);
    final sources = <DroneParameter, DroneValueSource>{};
    for (final row in rows) {
      final stored = row.readTableOrNull(_database.droneParameterSources);
      if (stored == null) continue;
      final parameter = DroneParameter.values
          .where((value) => value.name == stored.parameterKey)
          .firstOrNull;
      final source = DroneValueSource.values
          .where((value) => value.name == stored.source)
          .firstOrNull;
      if (parameter == null ||
          source == null ||
          parameter.read(drone) == null) {
        throw const FormatException('Invalid stored drone parameter source');
      }
      sources[parameter] = source;
    }
    final measurements = <DroneParameter, DroneMeasurement>{};
    for (final parameter in DroneParameter.values) {
      final value = parameter.read(drone);
      if (value == null) continue;
      try {
        parameter.validate(value);
      } on ArgumentError {
        throw FormatException(
          'Invalid stored drone parameter: ${parameter.name}',
        );
      }
      measurements[parameter] = DroneMeasurement(
        value,
        source: sources[parameter] ?? DroneValueSource.unspecified,
      );
    }
    return DroneProfile(drone: drone, measurements: measurements);
  }

  @override
  Future<DroneProfile?> getProfile(int id) async =>
      _readProfile(await _profileQuery(id).get());

  @override
  Stream<DroneProfile?> watchProfile(int id) =>
      _profileQuery(id).watch().map(_readProfile);
}
