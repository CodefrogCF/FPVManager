import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/telemetry/telemetry_repository.dart';
import 'package:fpvmanager/features/telemetry/telemetry_tab.dart';

void main() {
  testWidgets(
    'preview cancellation keeps raw storage empty; import and calibration require confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const settings = RoutePlanningSettings(
        flightMassGrams: 500,
        referenceMassGrams: 500,
        powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 300)],
      );
      await tester.runAsync(
        () =>
            FlightPlanRepository(db)
                .saveRoute(name: 'Hill', planning: settings, waypoints: []),
      );
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (finder.evaluate().isNotEmpty) {
            await tester.pump(const Duration(milliseconds: 300));
            return;
          }
        }
        fail('UI did not show $finder');
      }

      final repo = TelemetryRepository(db),
          raw = Uint8List.fromList(
            utf8.encode(
              'time_s,airspeed_m_s,voltage_v,current_a\n0,10,12,20\n10,10,12,20\n',
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TelemetryTab(
              repository: repo,
              pickFile: () async => (name: 'flight.csv', bytes: raw),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import telemetry CSV'));
      await waitFor(find.text('Import telemetry locally?'));
      expect(find.text('Import telemetry locally?'), findsOneWidget);
      expect(await db.select(db.telemetryFlights).get(), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.select(db.telemetryFlights).get(), isEmpty);
      await tester.tap(find.text('Import telemetry CSV'));
      await waitFor(find.text('Import telemetry locally?'));
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<int>).last,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await waitFor(find.text('Hill'));
      await tester.tap(find.text('Hill').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Import locally'));
      await waitFor(find.widgetWithText(ListTile, 'flight.csv'));
      expect((await db.select(db.telemetryFlights).get()).length, 1);
      await tester.tap(find.text('flight.csv'));
      await waitFor(find.text('Preview & apply calibration'));
      final apply = find.text('Preview & apply calibration');
      await tester.ensureVisible(apply);
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(find.text('Apply route calibration?'), findsOneWidget);
      expect(
        (await db.select(db.flightPlans).getSingle()).planningJson,
        settings.encode(),
      );
      await tester.tap(find.text('Apply to this route'));
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          if ((await db.select(db.flightPlans).getSingle()).planningJson !=
              settings.encode()) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        fail('Calibration was not applied');
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        RoutePlanningSettings.decode(
          (await db.select(db.flightPlans).getSingle()).planningJson,
        ).powerCurve.last.watts,
        360,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
