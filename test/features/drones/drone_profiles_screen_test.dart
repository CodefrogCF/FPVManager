import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/models/drone_profile.dart';
import 'package:fpvmanager/features/drones/drone_editor_dialog.dart';
import 'package:fpvmanager/features/drones/drones_screen.dart';

void main() {
  late FpvDatabase database;
  late DroneRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = DroneRepository(database);
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

  Future<void> source(
    WidgetTester tester,
    DroneParameter parameter,
    String label,
  ) async {
    final dropdown = find.ancestor(
      of: find.text('${parameter.label} source'),
      matching: find.byType(DropdownButtonFormField<DroneValueSource>),
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DronesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create records explicit units, mixed sources and context, with multiple profiles',
    (tester) async {
      await repository.createProfile(DroneProfileInput(name: 'Existing build'));
      await open(tester);
      await tap(tester, 'Add drone');
      await enter(tester, 'Profile name', 'New build');
      await enter(tester, 'Takeoff weight (g)', '710,5');
      await source(tester, DroneParameter.takeoffWeightGrams, 'Measured');
      await enter(tester, 'Hover power (W)', '180');
      await source(tester, DroneParameter.hoverPowerWatts, 'Estimated');
      await enter(
        tester,
        'Measurement context / sources',
        'Payload fitted; estimated hover power.',
      );
      await tap(tester, 'Save');
      expect(find.text('New build'), findsOneWidget);
      expect(find.text('Existing build'), findsOneWidget);
      final saved = (await repository.getProfile(
        (await repository.getAllDrones()).first.id,
      ))!;
      expect(
        saved.measurements[DroneParameter.takeoffWeightGrams]!.value,
        710.5,
      );
      expect(
        saved.measurements[DroneParameter.takeoffWeightGrams]!.source,
        DroneValueSource.measured,
      );
      expect(
        saved.measurements[DroneParameter.hoverPowerWatts]!.source,
        DroneValueSource.estimated,
      );
      await tap(tester, 'New build');
      expect(find.text('Takeoff weight: 710.5 g'), findsOneWidget);
      expect(find.text('Measured'), findsOneWidget);
      expect(find.text('Estimated'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets(
    'editing a number resets provenance; changing only text preserves it',
    (tester) async {
      final id = await repository.createProfile(
        DroneProfileInput(
          name: 'Original',
          measurements: {
            DroneParameter.takeoffWeightGrams: const DroneMeasurement(
              700,
              source: DroneValueSource.measured,
            ),
          },
        ),
      );
      await open(tester);
      await tap(tester, 'Original');
      await tap(tester, 'Edit profile');
      await enter(tester, 'Profile name', 'Renamed');
      await tap(tester, 'Save');
      expect(
        (await repository.getProfile(id))!.measurements.values.single.source,
        DroneValueSource.measured,
      );
      await tap(tester, 'Edit profile');
      await enter(tester, 'Takeoff weight (g)', '800');
      await tap(tester, 'Save');
      final saved = (await repository.getProfile(id))!;
      expect(saved.measurements.values.single.value, 800);
      expect(
        saved.measurements.values.single.source,
        DroneValueSource.unspecified,
      );
      expect(find.text('Source not specified'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets('fractional component counts and nonfinite values block saving', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Add drone');
    await enter(tester, 'Profile name', 'Invalid build');
    await enter(tester, 'Motor count', '4.5');
    await tap(tester, 'Save');
    expect(find.text('Enter a positive whole number'), findsOneWidget);
    expect(await repository.getAllDrones(), isEmpty);
    await enter(tester, 'Motor count', '4');
    await enter(tester, 'Hover power (W)', 'Infinity');
    await tap(tester, 'Save');
    expect(
      find.text('Enter a finite number greater than zero'),
      findsOneWidget,
    );
    await tap(tester, 'Cancel');
    await dispose(tester);
  });

  testWidgets(
    'cancel preserves profile; failed save preserves the complete draft',
    (tester) async {
      final id = await repository.createProfile(
        DroneProfileInput(name: 'Original'),
      );
      await open(tester);
      await tap(tester, 'Original');
      await tap(tester, 'Edit profile');
      await enter(tester, 'Profile name', 'Cancelled');
      await tap(tester, 'Cancel');
      expect((await repository.getProfile(id))!.drone.name, 'Original');
      await tap(tester, 'Edit profile');
      await enter(tester, 'Profile name', 'Draft');
      await enter(tester, 'Hover power (W)', '170');
      await source(tester, DroneParameter.hoverPowerWatts, 'Measured');
      await database.customStatement(
        "CREATE TRIGGER fail_source BEFORE INSERT ON drone_parameter_sources BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await tap(tester, 'Save');
      expect(
        find.textContaining('Your entries are still here'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Profile name')).controller!.text,
        'Draft',
      );
      expect(
        tester.widget<TextField>(field('Hover power (W)')).controller!.text,
        '170',
      );
      expect(find.text('Measured'), findsOneWidget);
      expect((await repository.getProfile(id))!.drone.name, 'Original');
      await tap(tester, 'Cancel');
      await dispose(tester);
    },
  );

  testWidgets(
    'delete confirmation can be cancelled or remove the selected profile',
    (tester) async {
      final id = await repository.createProfile(
        DroneProfileInput(name: 'Disposable test fixture'),
      );
      await open(tester);
      await tap(tester, 'Disposable test fixture');
      await tap(tester, 'Delete profile');
      await tap(tester, 'Cancel');
      expect(await repository.getProfile(id), isNotNull);
      await tap(tester, 'Delete profile');
      await tap(tester, 'Delete');
      expect(await repository.getProfile(id), isNull);
      expect(
        find.textContaining('No drone profiles saved yet.'),
        findsOneWidget,
      );
      await dispose(tester);
    },
  );

  testWidgets(
    'small screen and keyboard keep all values, sources and Save reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await tap(tester, 'Add drone');
      await enter(tester, 'Profile name', 'Small screen build');
      await enter(tester, 'Reference voltage (V)', '22.2');
      await source(tester, DroneParameter.referenceVoltageVolts, 'Measured');
      await tap(tester, 'Save');
      expect(find.byType(DroneEditorDialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        (await repository.getProfile(
          (await repository.getAllDrones()).single.id,
        ))!.measurements.values.single.value,
        22.2,
      );
      await dispose(tester);
    },
  );
}
