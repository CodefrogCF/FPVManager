import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/models/battery_profile.dart';

void main() {
  late FpvDatabase db;
  late BatteryRepository repository;
  Directory? fileDirectory;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    repository = BatteryRepository(db);
  });
  tearDown(() async {
    await db.close();
    await fileDirectory?.delete(recursive: true);
    fileDirectory = null;
  });

  test('pack round trip records explicit units, optional state and multiple associations', () async {
    final droneId = await DroneRepository(db).createDrone(name: 'Explorer');
    final planId = await FlightPlanRepository(db)
        .createFlightPlan(name: 'Route', droneId: droneId);
    final typeId = await repository.saveProfile(
      BatteryInput(
        name: '6S type',
        cellCount: 6,
        capacityMah: 1500,
        isType: true,
        nominalVoltageVolts: 22.2,
        energyWh: 33.3,
        weightGrams: 240,
      ),
    );
    final id = await repository.saveProfile(
      BatteryInput(
        name: ' Pack A ',
        chemistry: ' LiPo ',
        cellCount: 6,
        capacityMah: 1500,
        nominalVoltageVolts: 22.2,
        energyWh: 32.5,
        weightGrams: 241.5,
        typeId: typeId,
        chargePercent: 0,
        cycleCount: 0,
        availability: BatteryAvailability.unavailable,
        notes: 'Serial A',
        conditionNotes: 'Recorded inspection',
        droneIds: {droneId},
        flightPlanIds: {planId},
      ),
    );
    final profile = (await repository.getProfile(id))!;
    expect(profile.battery.name, 'Pack A');
    expect(profile.battery.chemistry, 'LiPo');
    expect(profile.battery.energyWh, 32.5);
    expect(profile.calculatedNominalEnergyWh, closeTo(33.3, 1e-9));
    expect(profile.battery.weightGrams, 241.5);
    expect(profile.battery.chargePercent, 0);
    expect(profile.battery.cycleCount, 0);
    expect(profile.battery.availability, 'unavailable');
    expect(profile.battery.conditionNotes, 'Recorded inspection');
    expect(profile.type!.id, typeId);
    expect(profile.drones.single.id, droneId);
    expect(profile.flightPlans.single.id, planId);
    await repository.saveProfile(
      BatteryInput(name: 'Unknown condition', cellCount: 4, capacityMah: 1800),
      id: id,
    );
    final cleared = (await repository.getProfile(id))!;
    expect(cleared.battery.chargePercent, isNull);
    expect(cleared.battery.cycleCount, isNull);
    expect(cleared.battery.nominalVoltageVolts, isNull);
    expect(cleared.battery.energyWh, isNull);
    expect(cleared.calculatedNominalEnergyWh, isNull);
    expect(cleared.type, isNull);
    expect(cleared.drones, isEmpty);
    expect(cleared.flightPlans, isEmpty);
  });

  test('types are independent templates; deleting them preserves packs and assignments', () async {
    final droneId = await DroneRepository(db).createDrone(name: 'Drone');
    final planId = await FlightPlanRepository(db)
        .createFlightPlan(name: 'Plan');
    final typeId = await repository.saveProfile(
      BatteryInput(name: 'Type', cellCount: 4, capacityMah: 1500, isType: true),
    );
    final id = await repository.saveProfile(
      BatteryInput(
        name: 'Pack',
        cellCount: 4,
        capacityMah: 1500,
        typeId: typeId,
        droneIds: {droneId},
        flightPlanIds: {planId},
      ),
    );
    await repository.saveProfile(
      BatteryInput(
        name: 'Revised type',
        cellCount: 6,
        capacityMah: 2000,
        isType: true,
      ),
      id: typeId,
    );
    final changed = (await repository.getProfile(id))!;
    expect(changed.type!.cellCount, 6);
    expect(changed.battery.cellCount, 4);
    await repository.deleteBattery(typeId);
    final detached = (await repository.getProfile(id))!;
    expect(detached.type, isNull);
    expect(detached.battery.capacityMah, 1500);
    expect(detached.drones.single.id, droneId);
    expect(detached.flightPlans.single.id, planId);
    await DroneRepository(db).deleteDrone(droneId);
    await FlightPlanRepository(db).deleteFlightPlan(planId);
    expect((await repository.getProfile(id))!.drones, isEmpty);
    expect((await repository.getProfile(id))!.flightPlans, isEmpty);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'failed association replacement rolls back the entire pack and all links',
    () async {
      final droneId = await DroneRepository(db).createDrone(name: 'Drone');
      final id = await repository.saveProfile(
        BatteryInput(
          name: 'Original',
          cellCount: 4,
          capacityMah: 1500,
          droneIds: {droneId},
        ),
      );
      await expectLater(
        repository.saveProfile(
          BatteryInput(
            name: 'Corrupted',
            cellCount: 6,
            capacityMah: 2000,
            droneIds: {droneId},
            flightPlanIds: {999999},
          ),
          id: id,
        ),
        throwsA(anything),
      );
      final retained = (await repository.getProfile(id))!;
      expect(retained.battery.name, 'Original');
      expect(retained.battery.cellCount, 4);
      expect(retained.drones.single.id, droneId);
      expect(retained.flightPlans, isEmpty);
    },
  );

  test(
    'invalid state, numbers, type links and kind changes leave records intact',
    () async {
      final id = await repository.saveProfile(
        BatteryInput(name: 'Pack', cellCount: 4, capacityMah: 1500),
      );
      for (final input in [
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          chargePercent: 101,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          chargePercent: double.nan,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          cycleCount: -1,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          nominalVoltageVolts: double.infinity,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 4000,
          nominalVoltageVolts: 1e308,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          energyWh: -1,
        ),
        BatteryInput(name: 'Bad', cellCount: 0, capacityMah: 1500),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          isType: true,
          cycleCount: 0,
        ),
        BatteryInput(
          name: 'Bad',
          cellCount: 4,
          capacityMah: 1500,
          isType: true,
          droneIds: {1},
        ),
        BatteryInput(name: 'Bad', cellCount: 4, capacityMah: 1500, typeId: id),
      ]) {
        await expectLater(
          repository.saveProfile(input, id: id),
          throwsArgumentError,
        );
        expect((await repository.getBattery(id))!.name, 'Pack');
      }
      await expectLater(
        repository.saveProfile(
          BatteryInput(
            name: 'Type',
            cellCount: 4,
            capacityMah: 1500,
            isType: true,
          ),
          id: id,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveProfile(
          BatteryInput(name: 'Missing', cellCount: 4, capacityMah: 1500),
          id: 999999,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'profile watchers follow renamed and removed associations after commit',
    () async {
      final droneId = await DroneRepository(db).createDrone(name: 'Before');
      final id = await repository.saveProfile(
        BatteryInput(
          name: 'Pack',
          cellCount: 4,
          capacityMah: 1500,
          droneIds: {droneId},
        ),
      );
      final update = repository
          .watchProfile(id)
          .firstWhere((p) => p?.drones.single.name == 'After');
      await DroneRepository(db).updateDrone(id: droneId, name: 'After');
      expect((await update)!.drones.single.name, 'After');
      final deleted = repository.watchProfile(id).firstWhere((p) => p == null);
      await repository.deleteBattery(id);
      expect(await deleted, isNull);
      expect((await DroneRepository(db).getDrone(droneId))!.name, 'After');
    },
  );

  test('inventory and associations survive a SQLite file reopen', () async {
    final directory = await Directory.systemTemp.createTemp('fpv-battery-');
    fileDirectory = directory;
    await db.close();
    final path = File('${directory.path}/inventory.sqlite');
    final first = db = FpvDatabase(NativeDatabase(path));
    final droneId = await DroneRepository(first).createDrone(name: 'Drone');
    final planId = await FlightPlanRepository(first)
        .createFlightPlan(name: 'Plan');
    final id = await BatteryRepository(first).saveProfile(
      BatteryInput(
        name: 'Stored',
        cellCount: 6,
        capacityMah: 1800,
        nominalVoltageVolts: 22.2,
        chargePercent: 75,
        cycleCount: 12,
        conditionNotes: 'Inspection note',
        availability: BatteryAvailability.available,
        droneIds: {droneId},
        flightPlanIds: {planId},
      ),
    );
    await first.close();
    final reopened = db = FpvDatabase(NativeDatabase(path));
    final result = (await BatteryRepository(reopened).getProfile(id))!;
    expect(result.battery.chargePercent, 75);
    expect(result.battery.cycleCount, 12);
    expect(result.battery.conditionNotes, 'Inspection note');
    expect(result.battery.availability, 'available');
    expect(result.drones.single.id, droneId);
    expect(result.flightPlans.single.id, planId);
  });
}
