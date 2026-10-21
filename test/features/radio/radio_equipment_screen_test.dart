import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/radio_equipment_repository.dart';
import 'package:fpvmanager/core/models/radio_profile.dart';
import 'package:fpvmanager/features/radio/radio_equipment_screen.dart';
import 'package:fpvmanager/features/radio/radio_editor_dialog.dart';

void main() {
  late FpvDatabase database;
  late RadioEquipmentRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = RadioEquipmentRepository(database);
  });
  tearDown(() => database.close());
  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    RadioEquipmentRepository? override,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RadioEquipmentScreen(repository: override ?? repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> category(WidgetTester tester, String value) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create independent RF profiles, assign drones and edit signed values',
    (tester) async {
      final drone = await DroneRepository(database)
          .createDrone(name: 'Explorer');
      await open(tester);
      await tap(tester, 'Add equipment');
      await enter(tester, 'Profile name', 'Control setup');
      await enter(tester, 'Protocol / system', 'Test control');
      await enter(tester, 'Frequency (MHz)', '868,5');
      await enter(tester, 'Transmitter antenna characteristics', 'Dipole');
      await enter(tester, 'Maximum transmitter power (mW)', '100');
      await enter(tester, 'Transmitter antenna gain (dBi)', '-1,5');
      await enter(tester, 'Receiver model', 'Air receiver');
      await enter(tester, 'Receiver sensitivity (dBm)', '-110');
      await enter(
        tester,
        'Specification source / measurement context',
        'Bench fixture',
      );
      await tap(tester, 'Explorer');
      await tap(tester, 'Save');
      expect(find.text('Equipment details'), findsOneWidget);
      final id = (await repository.getAllEquipment()).single.id;
      final control = (await repository.getProfile(id))!;
      expect(control.equipment.frequencyMhz, 868.5);
      expect(control.equipment.txGainDbi, -1.5);
      expect(control.equipment.sensitivityDbm, -110);
      expect(control.drones.single.id, drone);
      await tap(tester, 'Edit equipment');
      await enter(tester, 'Receiver sensitivity (dBm)', '');
      await tap(tester, 'Save');
      expect((await repository.getEquipment(id))!.sensitivityDbm, isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tap(tester, 'Add equipment');
      await enter(tester, 'Profile name', 'Video setup');
      await category(tester, 'Video');
      await enter(tester, 'Frequency (MHz)', '5800');
      await tap(tester, 'Explorer');
      await tap(tester, 'Save');
      final rows = await repository.getAllEquipment();
      expect(rows, hasLength(2));
      expect(rows.first.category, 'video');
      expect((await repository.getEquipment(id))!.frequencyMhz, 868.5);
      expect(
        (await repository.getProfile(rows.first.id))!.drones.single.id,
        drone,
      );
      await dispose(tester);
    },
  );

  testWidgets(
    'invalid power, frequency and nonfinite RF data cannot be saved',
    (tester) async {
      await open(tester);
      await tap(tester, 'Add equipment');
      await tap(tester, 'Save');
      expect(find.text('Enter Profile name'), findsOneWidget);
      await enter(tester, 'Profile name', 'Invalid');
      await enter(tester, 'Frequency (MHz)', '0');
      await enter(tester, 'Maximum transmitter power (mW)', '-2');
      await enter(tester, 'Receiver sensitivity (dBm)', 'NaN');
      await tap(tester, 'Save');
      expect(find.byType(RadioEditorDialog), findsOneWidget);
      expect(await repository.getAllEquipment(), isEmpty);
      await dispose(tester);
    },
  );

  testWidgets(
    'failed save retains entries for retry; cancel discards the draft',
    (tester) async {
      await database.customStatement(
        "CREATE TRIGGER reject_radio BEFORE INSERT ON radio_equipment BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await open(tester);
      await tap(tester, 'Add equipment');
      await enter(tester, 'Profile name', 'Retained draft');
      await tap(tester, 'Save');
      expect(
        find.textContaining('Your entries are still here'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Profile name')).controller!.text,
        'Retained draft',
      );
      await database.customStatement('DROP TRIGGER reject_radio');
      await tap(tester, 'Save');
      expect(
        (await repository.getAllEquipment()).single.name,
        'Retained draft',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tap(tester, 'Add equipment');
      await enter(tester, 'Profile name', 'Cancel this');
      await tap(tester, 'Cancel');
      expect(await repository.getAllEquipment(), hasLength(1));
      await dispose(tester);
    },
  );

  testWidgets(
    'delete can be cancelled and removes only equipment and its links',
    (tester) async {
      final drone = await DroneRepository(database)
          .createDrone(name: 'Keep drone');
      final id = await repository.saveProfile(
        RadioProfileInput(
          name: 'Delete setup',
          category: 'control',
          droneIds: {drone},
        ),
      );
      await repository.createEquipment(name: 'Keep video', category: 'video');
      await open(tester);
      await tap(tester, 'Delete setup');
      await tap(tester, 'Delete equipment');
      await tap(tester, 'Cancel');
      expect(await repository.getEquipment(id), isNotNull);
      await tap(tester, 'Delete equipment');
      await tap(tester, 'Delete');
      expect(await repository.getEquipment(id), isNull);
      expect((await repository.getAllEquipment()).single.name, 'Keep video');
      expect(await DroneRepository(database).getDrone(drone), isNotNull);
      await dispose(tester);
    },
  );

  testWidgets('legacy category and unknown values survive a UI edit', (
    tester,
  ) async {
    final id = await repository.createEquipment(
      name: 'Legacy',
      category: 'Custom legacy category',
      maxPowerMw: 0,
    );
    await open(tester);
    await tap(tester, 'Legacy');
    expect(find.text('Not recorded'), findsWidgets);
    await tap(tester, 'Edit equipment');
    await enter(tester, 'Profile name', 'Renamed');
    await tap(tester, 'Save');
    expect(
      (await repository.getEquipment(id))!.category,
      'Custom legacy category',
    );
    expect((await repository.getEquipment(id))!.maxPowerMw, 0);
    await dispose(tester);
  });

  testWidgets(
    'removed assignments are visible after refresh and can be cleared',
    (tester) async {
      final drone = await DroneRepository(database)
          .createDrone(name: 'Removed later');
      final id = await repository.saveProfile(
        RadioProfileInput(
          name: 'Setup',
          category: 'control',
          droneIds: {drone},
        ),
      );
      await open(tester);
      await tap(tester, 'Setup');
      await tap(tester, 'Edit equipment');
      await DroneRepository(database).deleteDrone(drone);
      await tap(tester, 'Refresh drones');
      await tap(tester, 'Removed drone (#$drone) — uncheck to continue');
      await tap(tester, 'Save');
      expect((await repository.getProfile(id))!.drones, isEmpty);
      await dispose(tester);
    },
  );

  testWidgets('equipment and assignment load failures have working retries', (
    tester,
  ) async {
    final flaky = _LoadFailureRepository(repository);
    await open(tester, override: flaky);
    expect(find.text('Unable to load equipment profiles.'), findsOneWidget);
    await tap(tester, 'Retry');
    await tap(tester, 'Add equipment');
    expect(find.text('Unable to load drone profiles.'), findsOneWidget);
    await tap(tester, 'Refresh drones');
    await enter(tester, 'Profile name', 'Recovered');
    await tap(tester, 'Save');
    expect(find.text('Unable to load this equipment profile.'), findsOneWidget);
    await tap(tester, 'Retry');
    expect(find.text('Recovered'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets(
    '320px display and keyboard keep the long form and Save reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await tap(tester, 'Add equipment');
      await enter(tester, 'Profile name', 'Small screen');
      await enter(
        tester,
        'Receiver specifications / operating mode',
        'Still reachable',
      );
      await enter(tester, 'Notes', 'End of form');
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(348));
      await tap(tester, 'Save');
      expect((await repository.getAllEquipment()).single.notes, 'End of form');
      await dispose(tester);
    },
  );
}

class _LoadFailureRepository implements RadioEquipmentRepository {
  _LoadFailureRepository(this.delegate);
  final RadioEquipmentRepository delegate;
  bool list = true, options = true, details = true;
  @override
  Stream<List<RadioEquipmentData>> watchEquipment() {
    if (list) {
      list = false;
      return Stream.error(StateError('Fixture list failure'));
    }
    return delegate.watchEquipment();
  }

  @override
  Future<List<Drone>> getDrones() async {
    if (options) {
      options = false;
      throw StateError('Fixture options failure');
    }
    return delegate.getDrones();
  }

  @override
  Stream<RadioProfile?> watchProfile(int id) {
    if (details) {
      details = false;
      return Stream.error(StateError('Fixture detail failure'));
    }
    return delegate.watchProfile(id);
  }

  @override
  Future<int> saveProfile(RadioProfileInput input, {int? id}) =>
      delegate.saveProfile(input, id: id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
