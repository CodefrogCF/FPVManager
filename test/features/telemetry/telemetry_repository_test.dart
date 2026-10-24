import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/telemetry/telemetry_log.dart';
import 'package:fpvmanager/features/telemetry/telemetry_repository.dart';

void main() {
  test(
    'raw bytes persist locally; bad imports and stale calibration are atomic',
    () async {
      final directory = await Directory.systemTemp.createTemp('fpv-telemetry-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/personal.sqlite');
      var db = FpvDatabase(NativeDatabase(file)),
          repo = TelemetryRepository(db);
      final plans = FlightPlanRepository(db);
      const settings = RoutePlanningSettings(
        flightMassGrams: 500,
        referenceMassGrams: 500,
        powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 300)],
      );
      final planId = await plans.saveRoute(
        name: 'Hill',
        planning: settings,
        waypoints: [],
      );
      final bytes = Uint8List.fromList(
        utf8.encode(
          'time_s,airspeed_m_s,voltage_v,current_a\n0,10,12,20\n10,10,12,20\n',
        ),
      );
      final id = await repo.import('flight.csv', bytes, planId: planId);
      await expectLater(
        repo.import('bad.csv', Uint8List.fromList([0])),
        throwsFormatException,
      );
      expect((await repo.watch().first).length, 1);
      await db.close();
      db = FpvDatabase(NativeDatabase(file));
      repo = TelemetryRepository(db);
      final stored = await repo.get(id);
      expect(stored.rawBytes, bytes);
      expect(stored.planId, planId);
      final comparison = TelemetryLog.decode(stored.rawBytes).compare(settings);
      expect(comparison.factor, closeTo(1.2, 1e-10));
      final calibrated = settings.calibrated(
        comparison.factor!,
        'Telemetry #$id',
      );
      await repo.calibrate(
        planId: planId,
        expectedPlanning: settings.encode(),
        calibrated: calibrated,
      );
      final saved = (await FlightPlanRepository(db).getFlightPlan(planId))!;
      expect(
        RoutePlanningSettings.decode(saved.planningJson).powerCurve.last.watts,
        360,
      );
      await expectLater(
        repo.calibrate(
          planId: planId,
          expectedPlanning: settings.encode(),
          calibrated: settings,
        ),
        throwsStateError,
      );
      expect((await repo.get(id)).rawBytes, bytes);
      final drone = await DroneRepository(db)
          .createDrone(name: 'Changed quad', takeoffWeightGrams: 650);
      await FlightPlanRepository(db)
          .updateFlightPlan(id: planId, name: 'Hill', droneId: drone);
      await expectLater(
        repo.calibrate(
          planId: planId,
          expectedPlanning: calibrated.encode(),
          calibrated: calibrated,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.calibrate(
          planId: planId,
          expectedPlanning: calibrated.encode(),
          calibrated: calibrated,
          expectedRouteDroneId: drone,
          massDroneId: drone,
          expectedDroneMass: 500,
        ),
        throwsStateError,
      );
      await repo.delete(id);
      expect(await repo.watch().first, isEmpty);
      await db.close();
    },
  );
}
