import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/models/battery_profile.dart';
import 'package:fpvmanager/features/batteries/batteries_screen.dart';
import 'package:fpvmanager/features/batteries/battery_editor_dialog.dart';

void main() {
  late FpvDatabase database;
  late BatteryRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = BatteryRepository(database);
  });
  tearDown(() => database.close());

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BatteriesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> requiredFields(
    WidgetTester tester, [
    String name = 'Pack A',
  ]) async {
    await enter(tester, 'Battery name', name);
    await enter(tester, 'Cell count', '6');
    await enter(tester, 'Capacity (mAh)', '1500');
  }

  testWidgets(
    'create, inspect and edit a pack with explicit units and assignments',
    (tester) async {
      final droneId = await DroneRepository(database)
          .createDrone(name: 'Explorer');
      final planId = await FlightPlanRepository(database)
          .createFlightPlan(name: 'Saved route');
      await open(tester);
      await tap(tester, 'Add battery');
      await requiredFields(tester);
      await enter(tester, 'Nominal voltage (V)', '22,2');
      await enter(tester, 'Recorded energy (Wh)', '32.5');
      await enter(tester, 'Weight (g)', '245');
      await enter(tester, 'Recorded charge (%)', '80');
      await enter(tester, 'Cycle count', '12');
      await enter(tester, 'Condition notes', 'Inspection recorded');
      final availability = find.byType(
        DropdownButtonFormField<BatteryAvailability>,
      );
      await tester.ensureVisible(availability);
      await tester.tap(availability);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available').last);
      await tester.pumpAndSettle();
      await tap(tester, 'Explorer');
      await tap(tester, 'Saved route');
      await tap(tester, 'Save');
      expect(find.text('Battery details'), findsOneWidget);
      expect(find.text('Pack A'), findsOneWidget);
      final id = (await repository.getAllBatteries()).single.id;
      final saved = (await repository.getProfile(id))!;
      expect(saved.battery.nominalVoltageVolts, 22.2);
      expect(saved.battery.energyWh, 32.5);
      expect(saved.battery.chargePercent, 80);
      expect(saved.battery.cycleCount, 12);
      expect(saved.battery.availability, 'available');
      expect(saved.drones.single.id, droneId);
      expect(saved.flightPlans.single.id, planId);
      await tap(tester, 'Edit battery');
      await enter(tester, 'Battery name', 'Renamed');
      await enter(tester, 'Recorded charge (%)', '');
      await enter(tester, 'Cycle count', '');
      await tap(tester, 'Save');
      expect((await repository.getBattery(id))!.name, 'Renamed');
      expect((await repository.getBattery(id))!.chargePercent, isNull);
      expect((await repository.getBattery(id))!.cycleCount, isNull);
      await dispose(tester);
    },
  );

  testWidgets(
    'types create independent pack copies with unknown initial condition',
    (tester) async {
      final typeId = await repository.saveProfile(
        BatteryInput(
          name: 'Template 6S',
          cellCount: 6,
          capacityMah: 1500,
          nominalVoltageVolts: 22.2,
          weightGrams: 240,
          isType: true,
        ),
      );
      await open(tester);
      await tap(tester, 'Types');
      await tap(tester, 'Template 6S');
      await tap(tester, 'Add pack from type');
      expect(
        tester.widget<TextField>(field('Cell count')).controller!.text,
        '6',
      );
      expect(
        tester.widget<TextField>(field('Cycle count')).controller!.text,
        isEmpty,
      );
      await enter(tester, 'Battery name', 'Serial 1');
      await enter(tester, 'Weight (g)', '245');
      await tap(tester, 'Save');
      final pack = (await repository.getAllBatteries()).firstWhere(
        (row) => !row.isType,
      );
      expect(pack.typeId, typeId);
      expect(pack.weightGrams, 245);
      expect(pack.cycleCount, isNull);
      expect(pack.chargePercent, isNull);
      expect(pack.availability, 'unknown');
      await repository.saveProfile(
        BatteryInput(
          name: 'Revised template',
          cellCount: 4,
          capacityMah: 1800,
          isType: true,
        ),
        id: typeId,
      );
      expect((await repository.getBattery(pack.id))!.cellCount, 6);
      await dispose(tester);
    },
  );

  testWidgets(
    'fractional counts, nonfinite values and invalid charge cannot be saved',
    (tester) async {
      await open(tester);
      await tap(tester, 'Add battery');
      await requiredFields(tester);
      await enter(tester, 'Cell count', '4.5');
      await enter(tester, 'Weight (g)', 'NaN');
      await enter(tester, 'Recorded charge (%)', '101');
      await enter(tester, 'Cycle count', '2.5');
      await tap(tester, 'Save');
      expect(find.byType(BatteryEditorDialog), findsOneWidget);
      expect(find.text('Enter a number from 0 to 100'), findsOneWidget);
      expect(await repository.getAllBatteries(), isEmpty);
      await dispose(tester);
    },
  );

  testWidgets(
    'failed saves keep the draft and can be retried; cancel discards a draft',
    (tester) async {
      await database.customStatement(
        "CREATE TRIGGER reject_battery BEFORE INSERT ON batteries BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await open(tester);
      await tap(tester, 'Add battery');
      await requiredFields(tester, 'Draft pack');
      await tap(tester, 'Save');
      expect(
        find.textContaining('Your entries are still here'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Battery name')).controller!.text,
        'Draft pack',
      );
      expect(await repository.getAllBatteries(), isEmpty);
      await database.customStatement('DROP TRIGGER reject_battery');
      await tap(tester, 'Save');
      expect((await repository.getAllBatteries()).single.name, 'Draft pack');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tap(tester, 'Add type');
      await enter(tester, 'Type name', 'Cancelled type');
      await tap(tester, 'Cancel');
      expect((await repository.getAllBatteries()).length, 1);
      await dispose(tester);
    },
  );

  testWidgets(
    'delete confirmation can be cancelled and removes only the battery',
    (tester) async {
      final droneId = await DroneRepository(database)
          .createDrone(name: 'Keep drone');
      final planId = await FlightPlanRepository(database)
          .createFlightPlan(name: 'Keep plan');
      final id = await repository.saveProfile(
        BatteryInput(
          name: 'Delete pack',
          cellCount: 4,
          capacityMah: 1500,
          droneIds: {droneId},
          flightPlanIds: {planId},
        ),
      );
      await open(tester);
      await tap(tester, 'Delete pack');
      await tap(tester, 'Delete battery');
      await tap(tester, 'Cancel');
      expect(await repository.getBattery(id), isNotNull);
      await tap(tester, 'Delete battery');
      await tap(tester, 'Delete');
      expect(await repository.getBattery(id), isNull);
      expect(await DroneRepository(database).getDrone(droneId), isNotNull);
      expect(
        await FlightPlanRepository(database).getFlightPlan(planId),
        isNotNull,
      );
      await dispose(tester);
    },
  );

  testWidgets(
    'small screens and the keyboard keep optional fields and Save reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await tap(tester, 'Add battery');
      await requiredFields(tester, 'Small pack');
      await enter(tester, 'Condition notes', 'Still reachable');
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(348));
      await tap(tester, 'Save');
      expect(
        (await repository.getAllBatteries()).single.conditionNotes,
        'Still reachable',
      );
      await dispose(tester);
    },
  );
}
