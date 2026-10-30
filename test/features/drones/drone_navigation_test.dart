import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets(
    'drone profiles open before map readiness on a small screen and retain caller-owned data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final drones = DroneRepository(database);
      final id = await drones.createDrone(name: 'Existing profile');
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            spotRepository: SpotRepository(database),
            droneRepository: drones,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Map actions'));
      await tester.pumpAndSettle();
      // Weather and device location work independently of globe readiness.
      expect(find.text('Map layers'), findsOneWidget);
      final menuItems = tester.widgetList<PopupMenuItem<dynamic>>(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      );
      final simulationItem = tester.widget<PopupMenuItem<dynamic>>(
        find.ancestor(
          of: find.text('Spawn in map · simulated flight'),
          matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        ),
      );
      expect(simulationItem.enabled, isFalse);
      expect(find.text('Weather intelligence'), findsOneWidget);
      expect(find.text('Standortanzeige'), findsOneWidget);
      expect(menuItems.where((item) => item.enabled), hasLength(2));
      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Equipment'));
      await tester.tap(find.text('Equipment'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Drone profiles'));
      await tester.tap(find.text('Drone profiles'));
      await tester.pumpAndSettle();
      expect(find.text('Existing profile'), findsOneWidget);
      expect(find.text('Add drone'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect((await drones.getDrone(id))!.name, 'Existing profile');
    },
  );
}
