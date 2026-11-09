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
      await tester.tap(find.byTooltip('Kartenaktionen'));
      await tester.pumpAndSettle();
      // Weather and device location work independently of globe readiness.
      expect(find.text('Karte & Ansicht'), findsOneWidget);
      final menuItems = tester.widgetList<PopupMenuItem<dynamic>>(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      );
      final simulationItem = tester.widget<PopupMenuItem<dynamic>>(
        find.ancestor(
          of: find.text('Flugsimulator'),
          matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        ),
      );
      expect(simulationItem.enabled, isFalse);
      expect(find.text('Wetter'), findsOneWidget);
      expect(find.text('Standortanzeige'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(menuItems.where((item) => item.enabled), hasLength(3));
      await tester.tapAt(const Offset(20, 200));
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
      await tester.ensureVisible(find.text('Drohnen'));
      await tester.tap(find.text('Drohnen'));
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
