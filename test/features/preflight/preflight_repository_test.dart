import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/features/preflight/checklist.dart';
import 'package:fpvmanager/features/preflight/preflight_repository.dart';

void main() {
  test(
    'template instances have independent local completion and survive restart',
    () async {
      final directory = await Directory.systemTemp.createTemp('fpv-preflight-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/personal.sqlite');
      var db = FpvDatabase(NativeDatabase(file));
      var repo = PreflightRepository(db);
      final drone = await DroneRepository(db).createDrone(name: 'Quad');
      final route = await FlightPlanRepository(db)
          .createFlightPlan(name: 'Hill');
      final template = await repo.save(
        name: 'Template',
        items: [const ChecklistItem('Battery', checked: true)],
        isTemplate: true,
      );
      final seed = decodeChecklist((await repo.watch().first).single.itemsJson);
      expect(seed.single.checked, isFalse);
      final first = await repo.save(
        name: 'Morning',
        items: seed,
        droneId: drone,
        planId: route,
      );
      final second = await repo.save(name: 'Evening', items: seed);
      await repo.check(first, 0, true);
      await expectLater(repo.check(template, 0, true), throwsStateError);
      await db.close();
      db = FpvDatabase(NativeDatabase(file));
      repo = PreflightRepository(db);
      final rows = await repo.watch().first;
      expect(
        decodeChecklist(rows.singleWhere((r) => r.id == first).itemsJson)
            .single
            .checked,
        isTrue,
      );
      expect(
        decodeChecklist(rows.singleWhere((r) => r.id == second).itemsJson)
            .single
            .checked,
        isFalse,
      );
      expect(rows.singleWhere((r) => r.id == first).droneId, drone);
      await repo.save(
        id: second,
        name: 'Different route',
        items: [const ChecklistItem('Battery', checked: true)],
        planId: route,
      );
      expect(
        decodeChecklist(
          (await repo.watch().first)
              .singleWhere((r) => r.id == second)
              .itemsJson,
        ).single.checked,
        isFalse,
      );
      await DroneRepository(db).deleteDrone(drone);
      await FlightPlanRepository(db).deleteFlightPlan(route);
      final detached = (await repo.watch().first).singleWhere(
        (r) => r.id == first,
      );
      expect(detached.droneId, isNull);
      expect(detached.planId, isNull);
      expect(decodeChecklist(detached.itemsJson).single.checked, isTrue);
      await db.close();
    },
  );
  test('checklists reject empty and oversized content', () {
    expect(() => encodeChecklist([]), throwsArgumentError);
    expect(
      () => encodeChecklist(List.filled(101, const ChecklistItem('x'))),
      throwsArgumentError,
    );
    expect(
      () => encodeChecklist([ChecklistItem('x' * 301)]),
      throwsArgumentError,
    );
    expect(defaultPreflightItems.length, 7);
  });
}
