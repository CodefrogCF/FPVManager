import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets(
    'multiple route records open from the drawer before globe readiness without taking database ownership',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final first = await repository.createFlightPlan(name: 'Ridge');
      await repository.createFlightPlan(name: 'Valley');
      await tester.pumpWidget(
        MaterialApp(home: FPVHomeScreen(flightPlanRepository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flight routes'));
      await tester.pumpAndSettle();
      expect(find.text('Ridge'), findsOneWidget);
      expect(find.text('Valley'), findsOneWidget);
      await tester.tap(find.text('Ridge'));
      await tester.pumpAndSettle();
      expect(find.text('Route editor'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ridge'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Valley'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect((await repository.getFlightPlan(first))!.name, 'Ridge');
      expect(tester.takeException(), isNull);
    },
  );
}
