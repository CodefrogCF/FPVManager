import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/models/drone_profile.dart';

void main() {
  late FpvDatabase database;
  late DroneRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = DroneRepository(database);
  });
  tearDown(() => database.close());
  DroneProfileInput profile({String name = 'Explorer'}) => DroneProfileInput(
    name: name,
    type: 'quad',
    configuration: 'True X, action camera',
    propellerDescription: 'Three blades',
    motorDescription: '2207',
    escDescription: '4-in-1',
    measurementContext: 'Payload fitted; bench supply at reference voltage',
    notes: 'Private build',
    measurements: {
      for (final parameter in DroneParameter.values)
        parameter: DroneMeasurement(
          parameter.index + 1,
          source: parameter.index.isEven
              ? DroneValueSource.measured
              : DroneValueSource.estimated,
        ),
    },
  );

  test('all physical parameters, explicit units and per-value provenance round trip', () async {
    final id = await repository.createProfile(profile());
    final saved = (await repository.getProfile(id))!;
    expect(saved.drone.configuration, 'True X, action camera');
    expect(saved.drone.propellerDescription, 'Three blades');
    expect(saved.drone.motorDescription, '2207');
    expect(saved.drone.escDescription, '4-in-1');
    expect(saved.drone.measurementContext, contains('reference voltage'));
    for (final parameter in DroneParameter.values) {
      expect(
        saved.measurements[parameter]!.value,
        parameter.index + 1,
        reason: parameter.name,
      );
      expect(
        saved.measurements[parameter]!.source,
        parameter.index.isEven
            ? DroneValueSource.measured
            : DroneValueSource.estimated,
      );
      if (!parameter.wholeNumber) {
        expect(parameter.unit, isNotEmpty, reason: parameter.name);
      }
    }
  });

  test(
    'multiple profiles, full replacement, unknown values and missing records',
    () async {
      final id = await repository.createProfile(profile());
      final created = (await repository.getDrone(id))!.createdAt;
      final empty = await repository.createProfile(
        DroneProfileInput(name: 'Unknown build'),
      );
      expect((await repository.getProfile(empty))!.measurements, isEmpty);
      expect((await repository.getAllDrones()).map((row) => row.id), [
        empty,
        id,
      ]);
      await repository.updateProfile(
        id: id,
        input: DroneProfileInput(
          name: 'Changed',
          measurements: {
            DroneParameter.hoverPowerWatts: const DroneMeasurement(180),
          },
        ),
      );
      final saved = (await repository.getProfile(id))!;
      expect(saved.drone.createdAt, created);
      expect(saved.drone.configuration, isNull);
      expect(saved.measurements.keys, [DroneParameter.hoverPowerWatts]);
      expect(
        saved.measurements.values.single.source,
        DroneValueSource.unspecified,
      );
      expect(
        await database.select(database.droneParameterSources).get(),
        isEmpty,
      );
      expect(await repository.getProfile(9999), isNull);
      expect(
        await repository.updateProfile(id: 9999, input: profile()),
        isFalse,
      );
    },
  );

  test(
    'invalid values and fractional component counts cannot be stored',
    () async {
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => DroneProfileInput(
            name: 'Invalid',
            measurements: {
              DroneParameter.hoverPowerWatts: DroneMeasurement(value),
            },
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => DroneProfileInput(
          name: 'Invalid',
          measurements: {
            DroneParameter.motorCount: const DroneMeasurement(4.5),
          },
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.createProfile(DroneProfileInput(name: ' ')),
        throwsArgumentError,
      );
      await expectLater(
        repository.createProfile(
          DroneProfileInput(name: 'Too long', motorDescription: 'x' * 121),
        ),
        throwsArgumentError,
      );
      expect(await repository.getAllDrones(), isEmpty);
    },
  );

  test(
    'legacy edits keep advanced fields and reset only changed value sources',
    () async {
      final id = await repository.createProfile(profile());
      final current = (await repository.getDrone(id))!;
      await repository.updateDrone(
        id: id,
        name: 'Basic rename',
        takeoffWeightGrams: current.takeoffWeightGrams,
        maxSpeedMetersPerSecond: current.maxSpeedMetersPerSecond,
      );
      var saved = (await repository.getProfile(id))!;
      expect(
        saved.measurements[DroneParameter.takeoffWeightGrams]!.source,
        DroneValueSource.measured,
      );
      expect(saved.drone.configuration, 'True X, action camera');
      await repository.updateDrone(
        id: id,
        name: 'New weight',
        takeoffWeightGrams: 700,
        maxSpeedMetersPerSecond: current.maxSpeedMetersPerSecond,
      );
      saved = (await repository.getProfile(id))!;
      expect(
        saved.measurements[DroneParameter.takeoffWeightGrams]!.source,
        DroneValueSource.unspecified,
      );
      expect(
        saved.measurements[DroneParameter.maxSpeedMetersPerSecond]!.source,
        DroneValueSource.estimated,
      );
      expect(
        saved.measurements[DroneParameter.hoverPowerWatts]!.source,
        DroneValueSource.measured,
      );
    },
  );

  test(
    'profile and source writes are atomic on creation and replacement',
    () async {
      final id = await repository.createProfile(profile());
      await database.customStatement(
        "CREATE TRIGGER fail_source BEFORE INSERT ON drone_parameter_sources BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        repository.createProfile(profile(name: 'Failed create')),
        throwsA(anything),
      );
      await expectLater(
        repository.updateProfile(
          id: id,
          input: DroneProfileInput(
            name: 'Failed edit',
            measurements: {
              DroneParameter.hoverPowerWatts: const DroneMeasurement(
                999,
                source: DroneValueSource.estimated,
              ),
            },
          ),
        ),
        throwsA(anything),
      );
      expect(await repository.getAllDrones(), hasLength(1));
      final saved = (await repository.getProfile(id))!;
      expect(saved.drone.name, 'Explorer');
      expect(saved.measurements, hasLength(DroneParameter.values.length));
      expect(saved.measurements[DroneParameter.hoverPowerWatts]!.value, 13);
      expect(
        saved.measurements[DroneParameter.hoverPowerWatts]!.source,
        DroneValueSource.measured,
      );
      expect(
        await database.select(database.droneParameterSources).get(),
        hasLength(DroneParameter.values.length),
      );
    },
  );

  test(
    'watchers receive committed values and provenance, deletion retains routes',
    () async {
      final id = await repository.createProfile(profile());
      final plan = await FlightPlanRepository(database)
          .createFlightPlan(name: 'Keep route', droneId: id);
      final stream = StreamIterator(repository.watchProfile(id));
      addTearDown(stream.cancel);
      await stream.moveNext();
      expect(stream.current!.drone.name, 'Explorer');
      await repository.updateProfile(
        id: id,
        input: DroneProfileInput(
          name: 'Updated',
          measurements: {
            DroneParameter.hoverPowerWatts: const DroneMeasurement(
              180,
              source: DroneValueSource.measured,
            ),
          },
        ),
      );
      await stream.moveNext();
      expect(stream.current!.drone.name, 'Updated');
      expect(stream.current!.measurements.values.single.value, 180);
      expect(
        stream.current!.measurements.values.single.source,
        DroneValueSource.measured,
      );
      await repository.deleteDrone(id);
      await stream.moveNext();
      expect(stream.current, isNull);
      expect(
        await database.select(database.droneParameterSources).get(),
        isEmpty,
      );
      expect(
        (await FlightPlanRepository(database).getRoute(plan))!.plan.droneId,
        isNull,
      );
    },
  );

  test(
    'corrupt source identifiers and invalid stored numbers are rejected',
    () async {
      final id = await repository.createDrone(
        name: 'Legacy',
        takeoffWeightGrams: 600,
      );
      expect(
        (await repository.getProfile(id))!.measurements.values.single.source,
        DroneValueSource.unspecified,
      );
      await database
          .into(database.droneParameterSources)
          .insert(
            DroneParameterSourcesCompanion.insert(
              droneId: id,
              parameterKey: 'takeoffWeightGrams',
              source: 'not-known',
            ),
          );
      await expectLater(repository.getProfile(id), throwsFormatException);
      await database.delete(database.droneParameterSources).go();
      await database
          .update(database.drones)
          .write(const DronesCompanion(hoverPowerWatts: Value(-1)));
      await expectLater(repository.getProfile(id), throwsFormatException);
    },
  );

  test(
    'profile values and provenance survive reopening a SQLite file',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'fpv-drone-profile-',
      );
      final file = File('${directory.path}/profiles.sqlite');
      FpvDatabase? store;
      try {
        store = FpvDatabase(NativeDatabase(file));
        final id = await DroneRepository(store).createProfile(profile());
        await store.close();
        store = null;
        store = FpvDatabase(NativeDatabase(file));
        final saved = (await DroneRepository(store).getProfile(id))!;
        expect(saved.drone.configuration, 'True X, action camera');
        expect(
          saved.measurements[DroneParameter.hoverPowerWatts]!.source,
          DroneValueSource.measured,
        );
        expect(
          saved.measurements[DroneParameter.cruisePowerWatts]!.source,
          DroneValueSource.estimated,
        );
      } finally {
        await store?.close();
        if (await directory.parent.resolveSymbolicLinks() ==
                await Directory.systemTemp.resolveSymbolicLinks() &&
            directory.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('fpv-drone-profile-')) {
          await directory.delete(recursive: true);
        }
      }
    },
  );
}
