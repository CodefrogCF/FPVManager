import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'route list observes only id/name without reading large planning JSON',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final iterator = StreamIterator(repository.watchFlightPlanSummaries());
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);

      // The list must remain usable even when an individual legacy route's
      // optional detail JSON is corrupt; detailed readers handle that record.
      final first = await db
          .into(db.flightPlans)
          .insert(
            FlightPlansCompanion.insert(
              name: 'Route with very large optional metadata',
              planningJson: Value('!' * 60000),
            ),
          );
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.id, first);
      expect(
        iterator.current.single.name,
        'Route with very large optional metadata',
      );
      await repository.createFlightPlan(name: 'Second');
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.map((s) => s.name), [
        'Second',
        'Route with very large optional metadata',
      ]);
      expect(
        (await repository.getFlightPlan(first))!.planningJson.length,
        60000,
      );
    },
  );
  test(
    'large flight-plan collections keep ordered lightweight summaries',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final payload = '{"extra":"${'x' * 4096}"}';
      await db.batch((batch) {
        for (var i = 0; i < 1200; i++) {
          batch.insert(
            db.flightPlans,
            FlightPlansCompanion.insert(
              name: 'Route $i',
              planningJson: Value(payload),
            ),
          );
        }
      });
      final summaries = await FlightPlanRepository(db)
          .watchFlightPlanSummaries()
          .first;
      expect(summaries.length, 1200);
      expect(summaries.first.name, 'Route 1199');
      expect(summaries.last.name, 'Route 0');
      expect((await FlightPlanRepository(db).getAllFlightPlans()).length, 1200);
    },
  );
}
