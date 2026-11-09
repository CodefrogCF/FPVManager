import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets(
    'inventory opens before map readiness and preserves caller-owned records',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final batteries = BatteryRepository(database);
      final id = await batteries.createBattery(
        name: 'Stored pack',
        cellCount: 4,
        capacityMah: 1500,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            spotRepository: SpotRepository(database),
            batteryRepository: batteries,
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
      await tester.ensureVisible(find.text('Akkus'));
      await tester.tap(find.text('Akkus'));
      await tester.pumpAndSettle();
      expect(find.text('Stored pack'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect((await batteries.getBattery(id))!.name, 'Stored pack');
      expect(tester.takeException(), isNull);
    },
  );
}
