import 'package:drift/drift.dart';

import '../../geo/altitude_service.dart';
import '../../geo/geo_coordinate_service.dart';
import '../../models/flight_route.dart';
import '../../models/route_planning_settings.dart';
import '../../models/recorded_route_track.dart';
import '../../models/route_transfer.dart';
import '../fpv_database.dart';
import '../repository_validation.dart';
import 'drone_repository.dart';

/// Lightweight row used in route navigation; large planning/recording JSON
/// is fetched only when the user needs its detail.
class FlightPlanSummary {
  const FlightPlanSummary({required this.id, required this.name});
  final int id;
  final String name;
}

/// Local flight projects. The caller owns the injected database.
abstract interface class FlightPlanRepository {
  static RouteWaypoint validatePersistedWaypoint(FlightWaypoint row) =>
      DriftFlightPlanRepository._readPoint(row);
  const factory FlightPlanRepository(FpvDatabase database) =
      DriftFlightPlanRepository;

  Future<int> createFlightPlan({
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    List<RouteWaypointInput> waypoints = const [],
  });
  Future<FlightPlan?> getFlightPlan(int id);
  Future<List<FlightPlan>> getAllFlightPlans();
  Stream<List<FlightPlan>> watchFlightPlans();
  Stream<List<FlightPlanSummary>> watchFlightPlanSummaries();
  Future<bool> updateFlightPlan({
    required int id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
  });
  Future<FlightRoute?> getRoute(int id);
  Stream<FlightRoute?> watchRoute(int id);
  Future<bool> replaceWaypoints({
    required int planId,
    required List<RouteWaypointInput> waypoints,
  });
  Future<int> deleteFlightPlan(int id);
  Future<List<int>> importRoutes(List<ImportedRoute> routes);
  Future<RouteEquipmentOptions> getEquipmentOptions();
  Future<int> saveRoute({
    int? id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    Set<int>? batteryIds,
    RoutePlanningSettings? planning,
    required List<RouteWaypointInput> waypoints,
  });
}

final class DriftFlightPlanRepository implements FlightPlanRepository {
  const DriftFlightPlanRepository(this._database);
  final FpvDatabase _database;

  @override
  Future<List<int>> importRoutes(List<ImportedRoute> routes) {
    if (routes.isEmpty ||
        routes.length > 20 ||
        routes.fold<int>(0, (n, r) => n + r.points.length) > 10000 ||
        routes.any((r) => r.points.length < 2 || r.points.length > 1000)) {
      throw ArgumentError('Invalid route import size');
    }
    final snapshot = [
      for (final r in routes)
        ImportedRoute(r.name, r.points, recordedTrack: r.recordedTrack),
    ];
    return _database.transaction(
      () async => [
        for (final r in snapshot)
          await saveRoute(
            name: r.name,
            waypoints: r.points,
            planning: r.recordedTrack == null
                ? null
                : const RoutePlanningSettings().withRecordedTrack(
                    _verifiedImportedTrack(r),
                  ),
          ),
      ],
    );
  }

  static RecordedRouteTrack _verifiedImportedTrack(ImportedRoute route) {
    final track = route.recordedTrack!;
    if (track.samples.length != route.points.length ||
        track.waypointSignature != recordedInputSignature(route.points)) {
      throw const FormatException('Recording no longer matches route');
    }
    return track;
  }

  @override
  Future<int> saveRoute({
    int? id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    Set<int>? batteryIds,
    RoutePlanningSettings? planning,
    required List<RouteWaypointInput> waypoints,
  }) {
    _validatePlan(name, droneId, startSpotId);
    final planningJson = planning?.encode();
    RepositoryValidation.optionalId(id);
    final points = _validatedPoints(waypoints);
    final assignedPacks = batteryIds == null
        ? null
        : Set<int>.unmodifiable(batteryIds);
    return _database.transaction(() async {
      final planId =
          id ??
          await createFlightPlan(
            name: name,
            droneId: droneId,
            startSpotId: startSpotId,
            notes: notes,
            waypoints: points,
          );
      if (id != null) {
        final exists = await updateFlightPlan(
          id: id,
          name: name,
          droneId: droneId,
          startSpotId: startSpotId,
          notes: notes,
        );
        if (!exists) throw StateError('Flight route no longer exists');
        await replaceWaypoints(planId: id, waypoints: points);
      }
      if (planningJson != null) {
        await (_database.update(_database.flightPlans)
              ..where((t) => t.id.equals(planId)))
            .write(FlightPlansCompanion(planningJson: Value(planningJson)));
      }
      if (assignedPacks != null) {
        for (final batteryId in assignedPacks) {
          RepositoryValidation.id(batteryId);
          final pack = await (_database.select(
            _database.batteries,
          )..where((t) => t.id.equals(batteryId))).getSingleOrNull();
          if (pack == null || pack.isType) {
            throw ArgumentError('Select an existing individual battery');
          }
        }
        await (_database.delete(
          _database.batteryFlightPlans,
        )..where((t) => t.planId.equals(planId))).go();
        await _database.batch(
          (batch) => batch.insertAll(_database.batteryFlightPlans, [
            for (final batteryId in assignedPacks)
              BatteryFlightPlansCompanion.insert(
                batteryId: batteryId,
                planId: planId,
              ),
          ]),
        );
      }
      return planId;
    });
  }

  void _validatePlan(String name, int? droneId, int? startSpotId) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.optionalId(droneId);
    RepositoryValidation.optionalId(startSpotId);
  }

  List<RouteWaypointInput> _validatedPoints(List<RouteWaypointInput> points) {
    final snapshot = List<RouteWaypointInput>.unmodifiable(points);
    for (final point in snapshot) {
      RepositoryValidation.coordinates(
        point.position.latitude,
        point.position.longitude,
      );
      final speed = point.speedMetersPerSecond;
      if (speed != null && (!speed.isFinite || speed <= 0 || speed > 200)) {
        throw ArgumentError(
          'Airspeed must be greater than 0 and at most 200 m/s',
        );
      }
      final height = point.height;
      if (height != null &&
          (!height.meters.isFinite || height.meters.abs() > 100000)) {
        throw ArgumentError('Waypoint height must be finite');
      }
      if (height is AglWaypointHeight && height.meters < 0) {
        throw ArgumentError('AGL height must be nonnegative');
      }
    }
    return snapshot;
  }

  Future<void> _insertPoints(int planId, List<RouteWaypointInput> points) {
    return _database.batch((batch) {
      batch.insertAll(_database.flightWaypoints, [
        for (var i = 0; i < points.length; i++)
          FlightWaypointsCompanion.insert(
            planId: planId,
            sequenceNumber: i,
            latitude: points[i].position.latitude,
            longitude: points[i].position.longitude,
            heightMeters: Value(points[i].height?.meters),
            speedMetersPerSecond: Value(points[i].speedMetersPerSecond),
            heightReference: Value(switch (points[i].height) {
              AbsoluteWaypointHeight(:final elevation) =>
                elevation.reference.name,
              _ => VerticalReference.unverified.name,
            }),
            altitudeMode: Value(
              points[i].height is AglWaypointHeight
                  ? 'aboveGroundLevel'
                  : 'absolute',
            ),
          ),
      ]);
    });
  }

  @override
  Future<int> createFlightPlan({
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    List<RouteWaypointInput> waypoints = const [],
  }) {
    _validatePlan(name, droneId, startSpotId);
    final points = _validatedPoints(waypoints);
    return _database.transaction(() async {
      final id = await _database
          .into(_database.flightPlans)
          .insert(
            FlightPlansCompanion.insert(
              name: name.trim(),
              droneId: Value(droneId),
              startSpotId: Value(startSpotId),
              notes: Value(notes),
            ),
          );
      await _insertPoints(id, points);
      return id;
    });
  }

  @override
  Future<FlightPlan?> getFlightPlan(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.flightPlans,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<FlightPlan>> getAllFlightPlans() => (_database.select(
    _database.flightPlans,
  )..orderBy([(table) => OrderingTerm.desc(table.id)])).get();

  @override
  Stream<List<FlightPlan>> watchFlightPlans() => (_database.select(
    _database.flightPlans,
  )..orderBy([(table) => OrderingTerm.desc(table.id)])).watch();

  @override
  Stream<List<FlightPlanSummary>> watchFlightPlanSummaries() => _database
      .customSelect(
        'SELECT id,name FROM flight_plans ORDER BY id DESC',
        readsFrom: {_database.flightPlans},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            FlightPlanSummary(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
            ),
        ],
      );

  @override
  Future<bool> updateFlightPlan({
    required int id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
  }) async {
    RepositoryValidation.id(id);
    _validatePlan(name, droneId, startSpotId);
    return await (_database.update(
          _database.flightPlans,
        )..where((table) => table.id.equals(id))).write(
          FlightPlansCompanion(
            name: Value(name.trim()),
            droneId: Value(droneId),
            startSpotId: Value(startSpotId),
            notes: Value(notes),
          ),
        ) >
        0;
  }

  JoinedSelectStatement<HasResultSet, dynamic> _routeQuery(int id) {
    RepositoryValidation.id(id);
    final plans = _database.flightPlans;
    final points = _database.flightWaypoints;
    return _database.select(plans).join([
        leftOuterJoin(points, points.planId.equalsExp(plans.id)),
      ])
      ..where(plans.id.equals(id))
      ..orderBy([
        OrderingTerm.asc(points.sequenceNumber),
        OrderingTerm.asc(points.id),
      ]);
  }

  Future<FlightRoute?> _readRoute(List<TypedResult> rows) async {
    if (rows.isEmpty) return null;
    return FlightRoute(
      plan: rows.first.readTable(_database.flightPlans),
      batteryIds:
          (await (_database.select(_database.batteryFlightPlans)..where(
                    (t) => t.planId.equals(
                      rows.first.readTable(_database.flightPlans).id,
                    ),
                  ))
                  .get())
              .map((r) => r.batteryId)
              .toSet(),
      waypoints: [
        for (final row in rows)
          if (row.readTableOrNull(_database.flightWaypoints) case final point?)
            _readPoint(point),
      ],
    );
  }

  static RouteWaypoint _readPoint(FlightWaypoint point) {
    try {
      RepositoryValidation.coordinates(point.latitude, point.longitude);
      if (point.sequenceNumber < 0) {
        throw const FormatException('Negative waypoint sequence');
      }
      final mode = FlightAltitudeMode.values.byName(point.altitudeMode);
      final reference = VerticalReference.values.byName(point.heightReference);
      final meters = point.heightMeters;
      WaypointHeight? height;
      if (meters == null) {
        if (mode != FlightAltitudeMode.absolute ||
            reference != VerticalReference.unverified) {
          throw const FormatException(
            'Position-only waypoint has height metadata',
          );
        }
      } else {
        if (!meters.isFinite || meters.abs() > 100000) {
          throw const FormatException('Nonfinite waypoint height');
        }
        if (mode == FlightAltitudeMode.aboveGroundLevel) {
          if (reference != VerticalReference.unverified || meters < 0) {
            throw const FormatException('Invalid AGL height or datum');
          }
          height = AglWaypointHeight(AboveGroundHeight(meters));
        } else {
          height = AbsoluteWaypointHeight(
            ReferencedElevation(meters: meters, reference: reference),
          );
        }
      }
      final speed = point.speedMetersPerSecond;
      if (speed != null && (!speed.isFinite || speed <= 0 || speed > 200)) {
        throw const FormatException('Invalid stored airspeed');
      }
      return RouteWaypoint(
        id: point.id,
        planId: point.planId,
        sequenceNumber: point.sequenceNumber,
        position: Wgs84Coordinate(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        height: height,
        speedMetersPerSecond: speed,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid stored waypoint ${point.id}: $error');
    }
  }

  @override
  Future<FlightRoute?> getRoute(int id) async => _database.transaction(
    () async => _readRoute(await _routeQuery(id).get()),
  );

  @override
  Stream<FlightRoute?> watchRoute(int id) => _database
      .customSelect(
        'SELECT id FROM flight_plans WHERE id = ?',
        variables: [Variable.withInt(id)],
        readsFrom: {
          _database.flightPlans,
          _database.flightWaypoints,
          _database.batteryFlightPlans,
        },
      )
      .watch()
      .asyncMap((_) => getRoute(id));

  @override
  Future<bool> replaceWaypoints({
    required int planId,
    required List<RouteWaypointInput> waypoints,
  }) {
    RepositoryValidation.id(planId);
    final points = _validatedPoints(waypoints);
    return _database.transaction(() async {
      if (await getFlightPlan(planId) == null) return false;
      await (_database.delete(
        _database.flightWaypoints,
      )..where((table) => table.planId.equals(planId))).go();
      await _insertPoints(planId, points);
      return true;
    });
  }

  @override
  Future<RouteEquipmentOptions> getEquipmentOptions() =>
      _database.transaction(() async {
        final drones = await (_database.select(
          _database.drones,
        )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
        final profiles = await Future.wait(
          drones.map((d) => DroneRepository(_database).getProfile(d.id)),
        );
        final batteries =
            await (_database.select(_database.batteries)
                  ..where((t) => t.isType.equals(false))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get();
        return RouteEquipmentOptions(
          drones: profiles.nonNulls.toList(),
          batteries: batteries,
        );
      });

  @override
  Future<int> deleteFlightPlan(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.flightPlans,
    )..where((table) => table.id.equals(id))).go();
  }
}
