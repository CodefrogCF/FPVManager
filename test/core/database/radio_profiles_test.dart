import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/radio_equipment_repository.dart';
import 'package:fpvmanager/core/models/radio_profile.dart';

void main() {
  late FpvDatabase database;
  late RadioEquipmentRepository radios;
  late DroneRepository drones;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    radios = RadioEquipmentRepository(database);
    drones = DroneRepository(database);
  });
  tearDown(() => database.close());

  test(
    'independent control and video profiles share drones and retain RF units',
    () async {
      final drone = await drones.createDrone(name: 'Explorer');
      final second = await drones.createDrone(name: 'Spare');
      final control = await radios.saveProfile(
        RadioProfileInput(
          name: ' Control ',
          category: 'control',
          droneIds: {drone, second},
          parameters: {
            RadioParameter.frequencyMhz: 868,
            RadioParameter.maxPowerMw: 100,
            RadioParameter.bandwidthKhz: 500,
            RadioParameter.sensitivityDbm: -110,
            RadioParameter.txGainDbi: -1.5,
            RadioParameter.rxGainDbi: 2.2,
            RadioParameter.txLossDb: 0,
            RadioParameter.rxLossDb: 0.5,
          },
          descriptions: {
            RadioTextField.protocol: ' Test protocol ',
            RadioTextField.transmitter: 'Ground TX',
            RadioTextField.receiver: 'Air RX',
            RadioTextField.txAntenna: 'Omnidirectional dipole',
            RadioTextField.rxAntenna: 'Two antennas; diversity',
            RadioTextField.txPolarization: 'Linear vertical',
            RadioTextField.rxPolarization: 'Linear',
            RadioTextField.receiverSpecifications:
                'Sensitivity at test mode only',
            RadioTextField.specificationSource: 'Bench measurement, fixture',
            RadioTextField.notes: 'Local notes',
          },
        ),
      );
      final video = await radios.saveProfile(
        RadioProfileInput(
          name: 'Video',
          category: 'video',
          droneIds: {drone},
          parameters: {
            RadioParameter.frequencyMhz: 5800,
            RadioParameter.maxPowerMw: 25,
          },
        ),
      );
      final saved = (await radios.getProfile(control))!;
      expect(saved.equipment.name, 'Control');
      expect(saved.equipment.protocol, 'Test protocol');
      expect(saved.equipment.frequencyMhz, 868);
      expect(saved.equipment.maxPowerMw, 100);
      expect(saved.equipment.bandwidthKhz, 500);
      expect(saved.equipment.sensitivityDbm, -110);
      expect(saved.equipment.txGainDbi, -1.5);
      expect(saved.equipment.rxGainDbi, 2.2);
      expect(saved.equipment.txLossDb, 0);
      expect(saved.equipment.rxLossDb, 0.5);
      expect(saved.equipment.transmitter, 'Ground TX');
      expect(saved.equipment.receiver, 'Air RX');
      expect(saved.equipment.txAntenna, 'Omnidirectional dipole');
      expect(saved.equipment.rxAntenna, 'Two antennas; diversity');
      expect(saved.equipment.txPolarization, 'Linear vertical');
      expect(saved.equipment.rxPolarization, 'Linear');
      expect(
        saved.equipment.receiverSpecifications,
        'Sensitivity at test mode only',
      );
      expect(saved.equipment.specificationSource, 'Bench measurement, fixture');
      expect(saved.equipment.notes, 'Local notes');
      expect(saved.drones.map((d) => d.id), [drone, second]);
      await radios.saveProfile(
        RadioProfileInput(
          name: 'New video',
          category: 'video',
          droneIds: {second},
        ),
        id: video,
      );
      expect((await radios.getEquipment(video))!.frequencyMhz, isNull);
      expect((await radios.getProfile(video))!.drones.single.id, second);
      expect((await radios.getEquipment(control))!.frequencyMhz, 868);
      await radios.deleteEquipment(control);
      expect(await drones.getDrone(drone), isNotNull);
      expect((await radios.getProfile(video))!.drones.single.id, second);
      await drones.deleteDrone(second);
      expect((await radios.getProfile(video))!.drones, isEmpty);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test('failed foreign keys roll back both new profiles and assignment replacements', () async {
    final drone = await drones.createDrone(name: 'Existing');
    final id = await radios.saveProfile(
      RadioProfileInput(
        name: 'Original',
        category: 'control',
        droneIds: {drone},
      ),
    );
    final invalid = RadioProfileInput(
      name: 'Changed',
      category: 'video',
      droneIds: {drone, 99999},
    );
    await expectLater(radios.saveProfile(invalid, id: id), throwsA(anything));
    expect((await radios.getProfile(id))!.equipment.name, 'Original');
    expect((await radios.getProfile(id))!.drones.single.id, drone);
    await expectLater(radios.saveProfile(invalid), throwsA(anything));
    expect(await radios.getAllEquipment(), hasLength(1));
    await expectLater(
      radios.saveProfile(
        RadioProfileInput(name: 'Missing', category: 'video'),
        id: 99999,
      ),
      throwsStateError,
    );
  });

  test('signed RF values and zero power/loss are valid; invalid and nonfinite values cannot write', () async {
    for (final field in RadioParameter.values) {
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        if (!field.signed) -1.0,
        if (!field.signed && !field.zero) 0.0,
      ]) {
        await expectLater(
          radios.saveProfile(
            RadioProfileInput(
              name: 'Invalid',
              category: 'video',
              parameters: {field: value},
            ),
          ),
          throwsArgumentError,
        );
      }
    }
    for (final input in [
      RadioProfileInput(name: '', category: 'video'),
      RadioProfileInput(name: 'x' * 121, category: 'video'),
      RadioProfileInput(name: 'X', category: ' '),
      RadioProfileInput(name: 'X', category: 'video', droneIds: {0}),
      RadioProfileInput(
        name: 'X',
        category: 'video',
        descriptions: {RadioTextField.protocol: 'x' * 121},
      ),
      RadioProfileInput(
        name: 'X',
        category: 'video',
        descriptions: {RadioTextField.txAntenna: 'x' * 4001},
      ),
    ]) {
      await expectLater(radios.saveProfile(input), throwsArgumentError);
    }
    expect(await radios.getAllEquipment(), isEmpty);
    final id = await radios.saveProfile(
      RadioProfileInput(
        name: 'Receive only',
        category: 'video',
        parameters: {
          RadioParameter.maxPowerMw: 0,
          RadioParameter.txLossDb: 0,
          RadioParameter.rxGainDbi: -2,
        },
      ),
    );
    expect((await radios.getEquipment(id))!.maxPowerMw, 0);
  });

  test(
    'legacy updates retain RF details, custom categories and assignments',
    () async {
      final drone = await drones.createDrone(name: 'Assigned');
      final id = await radios.saveProfile(
        RadioProfileInput(
          name: 'Legacy',
          category: 'custom legacy',
          droneIds: {drone},
          descriptions: {RadioTextField.receiver: 'Keep RX'},
          parameters: {RadioParameter.sensitivityDbm: -100},
        ),
      );
      expect(
        await radios.updateEquipment(
          id: id,
          name: 'Changed',
          category: 'custom legacy',
          frequencyMhz: 900,
        ),
        isTrue,
      );
      final saved = (await radios.getProfile(id))!;
      expect(saved.equipment.receiver, 'Keep RX');
      expect(saved.equipment.sensitivityDbm, -100);
      expect(saved.equipment.category, 'custom legacy');
      expect(saved.drones.single.id, drone);
      expect(saved.equipment.frequencyMhz, 900);
      expect(saved.equipment.maxPowerMw, isNull);
    },
  );

  test(
    'profile watchers refresh assignments, drone names and cascading removal',
    () async {
      final drone = await drones.createDrone(name: 'Old name');
      final id = await radios.saveProfile(
        RadioProfileInput(name: 'Watch', category: 'control'),
      );
      final events = <RadioProfile?>[];
      final subscription = radios.watchProfile(id).listen(events.add);
      addTearDown(subscription.cancel);
      Future<void> wait(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 4));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(condition(), isTrue);
      }

      await wait(() => events.isNotEmpty);
      await radios.saveProfile(
        RadioProfileInput(
          name: 'Watch',
          category: 'control',
          droneIds: {drone},
        ),
        id: id,
      );
      await wait(() => events.last?.drones.isNotEmpty == true);
      await drones.updateDrone(id: drone, name: 'New name');
      await wait(() => events.last?.drones.single.name == 'New name');
      await drones.deleteDrone(drone);
      await wait(() => events.last?.drones.isEmpty == true);
      await radios.deleteEquipment(id);
      await wait(() => events.last == null);
    },
  );
}
