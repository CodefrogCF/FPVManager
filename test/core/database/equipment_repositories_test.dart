import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/radio_equipment_repository.dart';

void main() {
  late FpvDatabase database;
  late DroneRepository drones;
  late BatteryRepository batteries;
  late RadioEquipmentRepository radios;

  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    drones = DroneRepository(database);
    batteries = BatteryRepository(database);
    radios = RadioEquipmentRepository(database);
  });
  tearDown(() => database.close());

  test('drone round trip, full update, ordering and missing records', () async {
    final id = await drones.createDrone(
      name: '  Explorer  ',
      type: ' fixed-wing ',
      takeoffWeightGrams: 750,
      maxSpeedMetersPerSecond: 30,
      notes: ' original notes ',
    );
    final original = (await drones.getDrone(id))!;
    expect(original.name, 'Explorer');
    expect(original.type, 'fixed-wing');
    expect(original.takeoffWeightGrams, 750);
    expect(original.maxSpeedMetersPerSecond, 30);
    expect(original.notes, ' original notes ');
    final newer = await drones.createDrone(name: 'Mini');
    expect((await drones.getAllDrones()).map((row) => row.id), [newer, id]);
    expect((await drones.getDrone(newer))!.type, 'quadcopter');
    expect(await drones.updateDrone(id: id, name: ' Updated '), isTrue);
    final updated = (await drones.getDrone(id))!;
    expect(updated.name, 'Updated');
    expect(updated.createdAt, original.createdAt);
    expect(updated.takeoffWeightGrams, isNull);
    expect(updated.maxSpeedMetersPerSecond, isNull);
    expect(updated.notes, isNull);
    expect(await drones.deleteDrone(id), 1);
    expect(await drones.deleteDrone(id), 0);
    expect(await drones.getDrone(id), isNull);
    expect(await drones.updateDrone(id: id, name: 'Missing'), isFalse);
  });

  test(
    'battery round trip, defaults and replacement of optional fields',
    () async {
      final id = await batteries.createBattery(
        name: ' Pack ',
        chemistry: ' LiIon ',
        cellCount: 6,
        capacityMah: 4000,
        weightGrams: 500,
        cycleCount: 12,
        notes: 'Retire at 100 cycles',
      );
      final original = (await batteries.getBattery(id))!;
      expect(original.name, 'Pack');
      expect(original.chemistry, 'LiIon');
      expect(original.cellCount, 6);
      expect(original.capacityMah, 4000);
      expect(original.weightGrams, 500);
      expect(original.cycleCount, 12);
      expect(original.notes, 'Retire at 100 cycles');
      final newer = await batteries.createBattery(
        name: 'Spare',
        cellCount: 4,
        capacityMah: 1500,
      );
      expect((await batteries.getAllBatteries()).map((row) => row.id), [
        newer,
        id,
      ]);
      expect((await batteries.getBattery(newer))!.chemistry, 'LiPo');
      expect((await batteries.getBattery(newer))!.cycleCount, 0);
      expect(
        await batteries.updateBattery(
          id: id,
          name: 'Updated',
          cellCount: 4,
          capacityMah: 1800,
        ),
        isTrue,
      );
      final updated = (await batteries.getBattery(id))!;
      expect(updated.cellCount, 4);
      expect(updated.capacityMah, 1800);
      expect(updated.weightGrams, isNull);
      expect(updated.notes, isNull);
      expect(await batteries.deleteBattery(id), 1);
      expect(await batteries.deleteBattery(id), 0);
      expect(await batteries.getBattery(id), isNull);
      expect(
        await batteries.updateBattery(
          id: id,
          name: 'Missing',
          cellCount: 4,
          capacityMah: 1800,
        ),
        isFalse,
      );
    },
  );

  test('radio round trip and receive-only power of zero', () async {
    final id = await radios.createEquipment(
      name: ' Goggles ',
      category: ' video ',
      frequencyMhz: 5800,
      maxPowerMw: 0,
      notes: 'Receiver',
    );
    final original = (await radios.getEquipment(id))!;
    expect(original.name, 'Goggles');
    expect(original.category, 'video');
    expect(original.frequencyMhz, 5800);
    expect(original.maxPowerMw, 0);
    expect(original.notes, 'Receiver');
    final newer = await radios.createEquipment(name: 'TX', category: 'control');
    expect((await radios.getAllEquipment()).map((row) => row.id), [newer, id]);
    expect(
      await radios.updateEquipment(
        id: id,
        name: 'Updated',
        category: 'telemetry',
      ),
      isTrue,
    );
    final updated = (await radios.getEquipment(id))!;
    expect(updated.category, 'telemetry');
    expect(updated.frequencyMhz, isNull);
    expect(updated.maxPowerMw, isNull);
    expect(updated.notes, isNull);
    expect(await radios.deleteEquipment(id), 1);
    expect(await radios.deleteEquipment(id), 0);
    expect(await radios.getEquipment(id), isNull);
    expect(
      await radios.updateEquipment(id: id, name: 'Missing', category: 'video'),
      isFalse,
    );
  });

  test('invalid equipment input cannot create records', () async {
    final operations = <Future<Object?> Function()>[
      () => drones.createDrone(name: ' '),
      () => drones.createDrone(name: 'a' * 121),
      () => drones.createDrone(name: 'Drone', type: ' '),
      () => drones.createDrone(name: 'Drone', takeoffWeightGrams: 0),
      () => drones.createDrone(
        name: 'Drone',
        maxSpeedMetersPerSecond: double.nan,
      ),
      () => batteries.createBattery(
        name: 'Pack',
        cellCount: 0,
        capacityMah: 1000,
      ),
      () =>
          batteries.createBattery(name: 'Pack', cellCount: 4, capacityMah: -1),
      () => batteries.createBattery(
        name: 'Pack',
        cellCount: 4,
        capacityMah: 1000,
        cycleCount: -1,
      ),
      () => batteries.createBattery(
        name: 'Pack',
        cellCount: 4,
        capacityMah: 1000,
        weightGrams: double.infinity,
      ),
      () => batteries.createBattery(
        name: 'Pack',
        cellCount: 4,
        capacityMah: 1000,
        chemistry: '',
      ),
      () => radios.createEquipment(name: 'Radio', category: ''),
      () => radios.createEquipment(
        name: 'Radio',
        category: 'control',
        frequencyMhz: 0,
      ),
      () => radios.createEquipment(
        name: 'Radio',
        category: 'control',
        maxPowerMw: -1,
      ),
      () => radios.createEquipment(
        name: 'Radio',
        category: 'control',
        frequencyMhz: double.infinity,
      ),
    ];
    for (final operation in operations) {
      await expectLater(operation, throwsArgumentError);
    }
    expect(await drones.getAllDrones(), isEmpty);
    expect(await batteries.getAllBatteries(), isEmpty);
    expect(await radios.getAllEquipment(), isEmpty);
  });

  test('invalid updates leave all existing equipment intact', () async {
    final droneId = await drones.createDrone(name: 'Drone');
    final batteryId = await batteries.createBattery(
      name: 'Pack',
      cellCount: 4,
      capacityMah: 1500,
    );
    final radioId = await radios.createEquipment(
      name: 'Radio',
      category: 'control',
    );
    await expectLater(
      () => drones.updateDrone(
        id: droneId,
        name: 'Corrupted',
        takeoffWeightGrams: -1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => batteries.updateBattery(
        id: batteryId,
        name: 'Corrupted',
        cellCount: 4,
        capacityMah: 0,
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => radios.updateEquipment(
        id: radioId,
        name: 'Corrupted',
        category: 'control',
        maxPowerMw: double.nan,
      ),
      throwsArgumentError,
    );
    expect((await drones.getDrone(droneId))!.name, 'Drone');
    expect((await batteries.getBattery(batteryId))!.name, 'Pack');
    expect((await radios.getEquipment(radioId))!.name, 'Radio');
    for (final operation in <Future<Object?> Function()>[
      () => drones.getDrone(0),
      () => drones.deleteDrone(-1),
      () => batteries.getBattery(0),
      () => batteries.deleteBattery(-1),
      () => radios.getEquipment(0),
      () => radios.deleteEquipment(-1),
    ]) {
      await expectLater(operation, throwsArgumentError);
    }
  });

  test('equipment watchers expose committed changes', () async {
    final droneChange = drones.watchDrones().firstWhere(
      (rows) => rows.isNotEmpty,
    );
    final batteryChange = batteries.watchBatteries().firstWhere(
      (rows) => rows.isNotEmpty,
    );
    final radioChange = radios.watchEquipment().firstWhere(
      (rows) => rows.isNotEmpty,
    );
    final droneId = await drones.createDrone(name: 'Drone');
    final batteryId = await batteries.createBattery(
      name: 'Pack',
      cellCount: 4,
      capacityMah: 1500,
    );
    final radioId = await radios.createEquipment(
      name: 'Radio',
      category: 'control',
    );
    expect((await droneChange).single.id, droneId);
    expect((await batteryChange).single.id, batteryId);
    expect((await radioChange).single.id, radioId);
  });
}
