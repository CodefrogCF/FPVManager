import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fpvmanager/core/database/fpv_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;
import '../../generated_migrations/schema_v2.dart' as v2;
import '../../generated_migrations/schema_v3.dart' as v3;
import '../../generated_migrations/schema_v4.dart' as v4;
import '../../generated_migrations/schema_v5.dart' as v5;
import '../../generated_migrations/schema_v6.dart' as v6;

import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/models/drone_profile.dart';

import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_query.dart';

import 'dart:typed_data';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v1 to v7 without losing spots', () async {
    final schema = await verifier.schemaAt(1);

    // Create a database with the original v1 schema.
    final oldDatabase = v1.DatabaseAtV1(schema.newConnection());

    await oldDatabase
        .into(oldDatabase.spots)
        .insert(
          v1.SpotsCompanion.insert(
            name: 'Existing FPV Spot',
            latitude: 47.12345,
            longitude: 8.54321,
          ),
        );

    await oldDatabase.close();

    // Open the same database with the new schema.
    final database = FpvDatabase(schema.newConnection());

    await verifier.migrateAndValidate(database, 7);

    // The original spot must still exist.
    final spots = await database.select(database.spots).get();

    expect(spots, hasLength(1));
    expect(spots.single.name, 'Existing FPV Spot');
    expect(spots.single.latitude, 47.12345);
    expect(spots.single.longitude, 8.54321);

    // Version 2 adds six more application tables.
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table'",
        )
        .get();

    final names = tables.map((row) => row.read<String>('name')).toSet();

    expect(names, contains('drones'));
    expect(names, contains('batteries'));
    expect(names, contains('radio_equipment'));
    expect(names, contains('flight_plans'));
    expect(names, contains('flight_waypoints'));
    expect(names, contains('app_settings'));
    expect(names, contains('spot_photos'));
    expect(names, contains('spot_tags'));

    await database.close();
  });

  test(
    'migrates v2 to v7 preserving personal records and references',
    () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      final spotId = await old
          .into(old.spots)
          .insert(
            v2.SpotsCompanion.insert(
              name: 'Private spot',
              latitude: 47,
              longitude: 8,
            ),
          );
      final droneId = await old
          .into(old.drones)
          .insert(v2.DronesCompanion.insert(name: 'My drone'));
      await old
          .into(old.batteries)
          .insert(
            v2.BatteriesCompanion.insert(
              name: 'Pack',
              cellCount: 6,
              capacityMah: 1500,
            ),
          );
      await old
          .into(old.radioEquipment)
          .insert(
            v2.RadioEquipmentCompanion.insert(
              name: 'Radio',
              category: 'control',
            ),
          );
      final planId = await old
          .into(old.flightPlans)
          .insert(
            v2.FlightPlansCompanion.insert(
              name: 'My route',
              droneId: Value(droneId),
              startSpotId: Value(spotId),
            ),
          );
      await old
          .into(old.flightWaypoints)
          .insert(
            v2.FlightWaypointsCompanion.insert(
              planId: planId,
              sequenceNumber: 0,
              latitude: 47,
              longitude: 8,
              heightMeters: const Value(830),
            ),
          );
      await old
          .into(old.appSettings)
          .insert(
            v2.AppSettingsCompanion.insert(
              key: 'legacy.keep',
              value: 'private',
            ),
          );
      await old.close();
      final database = FpvDatabase(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 7);
      expect(
        (await database.select(database.spots).get()).single.name,
        'Private spot',
      );
      expect((await database.select(database.drones).get()).single.id, droneId);
      expect(
        (await database.select(database.batteries).get()).single.capacityMah,
        1500,
      );
      expect(
        (await database.select(database.radioEquipment).get()).single.category,
        'control',
      );
      final plan = (await database.select(database.flightPlans).get()).single;
      expect(plan.droneId, droneId);
      expect(plan.startSpotId, spotId);
      final waypoint =
          (await database.select(database.flightWaypoints).get()).single;
      expect(waypoint.heightMeters, 830);
      expect(waypoint.heightReference, 'unverified');
      expect(
        (await database.select(database.appSettings).get()).single.value,
        'private',
      );
      expect(await database.select(database.spotPhotos).get(), isEmpty);
      final index = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'spot_photos_spot_id'",
          )
          .get();
      expect(index, hasLength(1));
    },
  );

  test('v3 to v7 preserves photos and favorites and backfills Unicode search in batches', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    for (var i = 0; i < 405; i++) {
      await old
          .into(old.spots)
          .insert(
            v3.SpotsCompanion.insert(
              name: 'Älpler $i',
              latitude: 47,
              longitude: 8,
              notes: const Value('Über dem See'),
              isFavorite: const Value(1),
            ),
          );
    }
    final bytes = Uint8List.fromList([1, 2, 3]);
    await old
        .into(old.spotPhotos)
        .insert(
          v3.SpotPhotosCompanion.insert(
            spotId: 405,
            imageBytes: bytes,
            thumbnailBytes: bytes,
            width: 8,
            height: 4,
          ),
        );
    await old.close();
    final database = FpvDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 7);
    final repository = SpotRepository(database);
    final page = await repository.getSpotPage(
      filter: SpotFilter(query: 'älpler 404 über', favoritesOnly: true),
    );
    expect(page.items.single.id, 405);
    expect(page.items.single.category, isNull);
    expect(page.items.single.tags, isEmpty);
    expect((await database.select(database.spots).get()), hasLength(405));
    final photo = (await repository.getPhotos(405)).single;
    expect(
      await repository.getPhotoBytes(spotId: 405, photoId: photo.id),
      bytes,
    );
    await repository.deleteSpot(405);
    expect(await repository.getPhotos(405), isEmpty);
  });

  test('v4 to v7 preserves classified spots and drones without inventing provenance', () async {
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    final spotId = await old
        .into(old.spots)
        .insert(
          v4.SpotsCompanion.insert(
            name: 'Existing spot',
            latitude: 47,
            longitude: 8,
            category: const Value('Alpine'),
            categoryKey: const Value('alpine'),
            searchText: const Value('existing spot alpine quiet'),
          ),
        );
    await old
        .into(old.spotTags)
        .insert(v4.SpotTagsCompanion.insert(spotId: spotId, tag: 'quiet'));
    final bytes = Uint8List.fromList([1, 2, 3]);
    await old
        .into(old.spotPhotos)
        .insert(
          v4.SpotPhotosCompanion.insert(
            spotId: spotId,
            imageBytes: bytes,
            thumbnailBytes: bytes,
            width: 8,
            height: 4,
          ),
        );
    final droneId = await old
        .into(old.drones)
        .insert(
          v4.DronesCompanion.insert(
            name: 'Existing drone',
            type: const Value('fixed-wing'),
            takeoffWeightGrams: const Value(710),
            maxSpeedMetersPerSecond: const Value(33),
            notes: const Value('Existing notes'),
          ),
        );
    final planId = await old
        .into(old.flightPlans)
        .insert(
          v4.FlightPlansCompanion.insert(
            name: 'Existing plan',
            droneId: Value(droneId),
            startSpotId: Value(spotId),
          ),
        );
    await old.close();
    final database = FpvDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 7);
    final profile = (await DroneRepository(database).getProfile(droneId))!;
    expect(profile.drone.name, 'Existing drone');
    expect(profile.drone.type, 'fixed-wing');
    expect(profile.drone.notes, 'Existing notes');
    expect(profile.drone.motorDescription, isNull);
    expect(profile.measurements, hasLength(2));
    expect(profile.measurements[DroneParameter.takeoffWeightGrams]!.value, 710);
    expect(
      profile.measurements[DroneParameter.maxSpeedMetersPerSecond]!.value,
      33,
    );
    expect(
      profile.measurements.values.every(
        (value) => value.source == DroneValueSource.unspecified,
      ),
      isTrue,
    );
    expect(
      await database.select(database.droneParameterSources).get(),
      isEmpty,
    );
    final spot = (await SpotRepository(database).getSpotPage(
      filter: SpotFilter(category: 'Alpine', tags: ['quiet']),
    )).items.single;
    expect(spot.id, spotId);
    expect((await SpotRepository(database).getPhotos(spotId)), hasLength(1));
    final plan = (await (database.select(
      database.flightPlans,
    )..where((row) => row.id.equals(planId))).getSingle());
    expect(plan.droneId, droneId);
    expect(plan.startSpotId, spotId);
  });

  test(
    'v5 to v7 preserves battery records without inventing state or type',
    () async {
      final schema = await verifier.schemaAt(5);
      final old = v5.DatabaseAtV5(schema.newConnection());
      final droneId = await old
          .into(old.drones)
          .insert(v5.DronesCompanion.insert(name: 'Existing drone'));
      final batteryId = await old
          .into(old.batteries)
          .insert(
            v5.BatteriesCompanion.insert(
              name: 'Pack ä',
              chemistry: const Value('LiIon'),
              cellCount: 6,
              capacityMah: 4000,
              weightGrams: const Value(501.5),
              cycleCount: const Value(23),
              notes: const Value('Original condition note'),
            ),
          );
      final zeroId = await old
          .into(old.batteries)
          .insert(
            v5.BatteriesCompanion.insert(
              name: 'Zero cycles',
              cellCount: 4,
              capacityMah: 1500,
            ),
          );
      final planId = await old
          .into(old.flightPlans)
          .insert(
            v5.FlightPlansCompanion.insert(
              name: 'Existing plan',
              droneId: Value(droneId),
            ),
          );
      await old.close();
      final database = FpvDatabase(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 7);
      final battery = await (database.select(
        database.batteries,
      )..where((t) => t.id.equals(batteryId))).getSingle();
      expect(battery.name, 'Pack ä');
      expect(battery.chemistry, 'LiIon');
      expect(battery.cellCount, 6);
      expect(battery.capacityMah, 4000);
      expect(battery.weightGrams, 501.5);
      expect(battery.cycleCount, 23);
      expect(battery.notes, 'Original condition note');
      expect(battery.isType, isFalse);
      expect(battery.typeId, isNull);
      expect(battery.nominalVoltageVolts, isNull);
      expect(battery.energyWh, isNull);
      expect(battery.chargePercent, isNull);
      expect(battery.conditionNotes, isNull);
      expect(battery.availability, 'unknown');
      expect(
        (await (database.select(
          database.batteries,
        )..where((t) => t.id.equals(zeroId))).getSingle()).cycleCount,
        0,
      );
      expect(
        (await database.select(database.flightPlans).getSingle()).id,
        planId,
      );
      expect(
        (await database.select(database.flightPlans).getSingle()).droneId,
        droneId,
      );
      expect(await database.select(database.batteryDrones).get(), isEmpty);
      expect(await database.select(database.batteryFlightPlans).get(), isEmpty);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
    },
  );

  test(
    'v6 to v7 preserves legacy RF values, categories and battery links',
    () async {
      final schema = await verifier.schemaAt(6);
      final old = v6.DatabaseAtV6(schema.newConnection());
      final drone = await old
          .into(old.drones)
          .insert(v6.DronesCompanion.insert(name: 'Existing drone'));
      final pack = await old
          .into(old.batteries)
          .insert(
            v6.BatteriesCompanion.insert(
              name: 'Existing pack',
              cellCount: 4,
              capacityMah: 1500,
              chargePercent: const Value(75),
            ),
          );
      await old
          .into(old.batteryDrones)
          .insert(
            v6.BatteryDronesCompanion.insert(batteryId: pack, droneId: drone),
          );
      final id = await old
          .into(old.radioEquipment)
          .insert(
            v6.RadioEquipmentCompanion.insert(
              name: 'Old RX',
              category: 'custom receiver',
              frequencyMhz: const Value(5800),
              maxPowerMw: const Value(0),
              notes: const Value('Keep original notes'),
            ),
          );
      await old.close();
      final database = FpvDatabase(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 7);
      final row = await database.select(database.radioEquipment).getSingle();
      expect(row.id, id);
      expect(row.name, 'Old RX');
      expect(row.category, 'custom receiver');
      expect(row.frequencyMhz, 5800);
      expect(row.maxPowerMw, 0);
      expect(row.notes, 'Keep original notes');
      expect(row.protocol, isNull);
      expect(row.transmitter, isNull);
      expect(row.receiver, isNull);
      expect(row.sensitivityDbm, isNull);
      expect(row.txGainDbi, isNull);
      expect(row.rxGainDbi, isNull);
      expect(row.txLossDb, isNull);
      expect(row.rxLossDb, isNull);
      expect(row.bandwidthKhz, isNull);
      expect(row.txAntenna, isNull);
      expect(row.rxAntenna, isNull);
      expect(row.txPolarization, isNull);
      expect(row.rxPolarization, isNull);
      expect(row.receiverSpecifications, isNull);
      expect(row.specificationSource, isNull);
      expect(
        await database.select(database.radioEquipmentDrones).get(),
        isEmpty,
      );
      expect(
        (await database.select(database.batteryDrones).getSingle()).droneId,
        drone,
      );
      expect(
        (await database.select(database.batteries).getSingle()).chargePercent,
        75,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test('new v7 database creates all tables', () async {
    final database = FpvDatabase(NativeDatabase.memory());

    // Trigger database initialization.
    await database.select(database.spots).get();

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table'",
        )
        .get();

    final names = tables.map((row) => row.read<String>('name')).toSet();

    expect(names, contains('spots'));
    expect(names, contains('spot_photos'));
    expect(names, contains('spot_tags'));
    expect(names, contains('drones'));
    expect(names, contains('drone_parameter_sources'));
    expect(names, contains('batteries'));
    expect(names, contains('battery_drones'));
    expect(names, contains('battery_flight_plans'));
    expect(names, contains('radio_equipment'));
    expect(names, contains('radio_equipment_drones'));
    expect(names, contains('flight_plans'));
    expect(names, contains('flight_waypoints'));
    expect(names, contains('app_settings'));

    await database.close();
  });

  test('deleting a flight plan cascades to its waypoints', () async {
    final database = FpvDatabase(NativeDatabase.memory());

    try {
      final planId = await database
          .into(database.flightPlans)
          .insert(FlightPlansCompanion.insert(name: 'Test Flight'));

      await database
          .into(database.flightWaypoints)
          .insert(
            FlightWaypointsCompanion.insert(
              planId: planId,
              sequenceNumber: 0,
              latitude: 46.95108,
              longitude: 7.43863,
            ),
          );

      final before = await database.select(database.flightWaypoints).get();

      expect(before, hasLength(1));

      await database.customStatement('DELETE FROM flight_plans WHERE id = ?', [
        planId,
      ]);

      final after = await database.select(database.flightWaypoints).get();

      expect(after, isEmpty);
    } finally {
      await database.close();
    }
  });
}
