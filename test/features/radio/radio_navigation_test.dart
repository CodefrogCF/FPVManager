import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/radio_equipment_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets(
    'equipment opens before map readiness and retains caller database ownership',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = RadioEquipmentRepository(database);
      final id = await repository.createEquipment(
        name: 'Stored radio',
        category: 'control',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            spotRepository: SpotRepository(database),
            radioEquipmentRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ausrüstung'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(Drawer),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Ausrüstung'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Funk & Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Funk & Video'));
      await tester.pumpAndSettle();
      expect(find.text('Stored radio'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect((await repository.getEquipment(id))!.name, 'Stored radio');
      expect(tester.takeException(), isNull);
    },
  );
}
