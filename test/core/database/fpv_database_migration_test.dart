import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fpvmanager/core/database/fpv_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v1 to v2 without losing spots', () async {
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

    await verifier.migrateAndValidate(database, 2);

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

    await database.close();
  });

  test('new v2 database creates all tables', () async {
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
    expect(names, contains('drones'));
    expect(names, contains('batteries'));
    expect(names, contains('radio_equipment'));
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
