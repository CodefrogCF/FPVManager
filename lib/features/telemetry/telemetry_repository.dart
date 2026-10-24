import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/fpv_database.dart';
import '../../core/models/route_planning_settings.dart';
import 'telemetry_log.dart';

TelemetryLog decodeTelemetry(Uint8List bytes) => TelemetryLog.decode(bytes);

class TelemetryRepository {
  const TelemetryRepository(this.database);
  final FpvDatabase database;
  // Deliberately exclude raw blobs from the library projection.
  Stream<
    List<
      ({
        int id,
        String fileName,
        int? droneId,
        int? planId,
        DateTime importedAt,
      })
    >
  >
  watch() {
    final t = database.telemetryFlights;
    return (database.selectOnly(t)
          ..addColumns([t.id, t.fileName, t.droneId, t.planId, t.importedAt])
          ..orderBy([OrderingTerm.desc(t.importedAt)]))
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              (
                id: r.read(t.id)!,
                fileName: r.read(t.fileName)!,
                droneId: r.read(t.droneId),
                planId: r.read(t.planId),
                importedAt: r.read(t.importedAt)!,
              ),
          ],
        );
  }

  Future<int> import(
    String name,
    Uint8List bytes, {
    int? droneId,
    int? planId,
  }) async {
    if (name.trim().isEmpty || name.length > 240) {
      throw ArgumentError('Invalid telemetry filename');
    }
    await compute(decodeTelemetry, bytes);
    return database.transaction(() async {
      final t = database.telemetryFlights;
      final stats = await database
          .customSelect(
            'SELECT COUNT(*) AS n, COALESCE(SUM(LENGTH(raw_bytes)), 0) AS bytes FROM telemetry_flights',
            readsFrom: {t},
          )
          .getSingle();
      if (stats.read<int>('n') >= 50 ||
          stats.read<int>('bytes') + bytes.length > 100 * 1024 * 1024) {
        throw StateError(
          'Local telemetry limit: 50 logs / 100 MiB. Delete old logs first.',
        );
      }
      return database
          .into(t)
          .insert(
            TelemetryFlightsCompanion.insert(
              fileName: name,
              rawBytes: bytes,
              droneId: Value(droneId),
              planId: Value(planId),
            ),
          );
    });
  }

  Future<TelemetryFlight> get(int id) => (database.select(
    database.telemetryFlights,
  )..where((t) => t.id.equals(id))).getSingle();
  Future<void> delete(int id) async {
    await (database.delete(
      database.telemetryFlights,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Compare-and-swap prevents applying a preview to subsequently edited inputs.
  Future<void> calibrate({
    required int planId,
    required String expectedPlanning,
    required RoutePlanningSettings calibrated,
    int? expectedRouteDroneId,
    int? massDroneId,
    double? expectedDroneMass,
  }) => database.transaction(() async {
    final route = await (database.select(
      database.flightPlans,
    )..where((t) => t.id.equals(planId))).getSingleOrNull();
    if (route == null || route.droneId != expectedRouteDroneId) {
      throw StateError('Route equipment changed. Reopen the comparison.');
    }
    if (massDroneId != null) {
      final drone = await (database.select(
        database.drones,
      )..where((t) => t.id.equals(massDroneId))).getSingleOrNull();
      if (drone == null || drone.takeoffWeightGrams != expectedDroneMass) {
        throw StateError('Drone mass changed. Reopen the comparison.');
      }
    }
    final count =
        await (database.update(database.flightPlans)..where(
              (t) =>
                  t.id.equals(planId) & t.planningJson.equals(expectedPlanning),
            ))
            .write(
              FlightPlansCompanion(planningJson: Value(calibrated.encode())),
            );
    if (count != 1) {
      throw StateError(
        'Route changed. Reopen the comparison before applying calibration.',
      );
    }
  });
}
