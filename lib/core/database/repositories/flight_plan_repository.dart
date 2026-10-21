import 'package:drift/drift.dart';

import '../../geo/altitude_service.dart';
import '../../geo/geo_coordinate_service.dart';
import '../../models/flight_route.dart';
import '../fpv_database.dart';
import '../repository_validation.dart';

/// Local flight projects. The caller owns the injected database.
abstract interface class FlightPlanRepository {
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
  Future<int> saveRoute({
    int? id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    required List<RouteWaypointInput> waypoints,
  });
}

final class DriftFlightPlanRepository implements FlightPlanRepository {
  const DriftFlightPlanRepository(this._database);
  final FpvDatabase _database;

  @override
  Future<int> saveRoute({
    int? id,
    required String name,
    int? droneId,
    int? startSpotId,
    String? notes,
    required List<RouteWaypointInput> waypoints,
  }) {
    _validatePlan(name, droneId, startSpotId);
    RepositoryValidation.optionalId(id);
    final points = _validatedPoints(waypoints);
    return _database.transaction(() async {
      if (id == null) {
        return createFlightPlan(
          name: name,
          droneId: droneId,
          startSpotId: startSpotId,
          notes: notes,
          waypoints: points,
        );
      }
      final exists = await updateFlightPlan(
        id: id,
        name: name,
        droneId: droneId,
        startSpotId: startSpotId,
        notes: notes,
      );
      if (!exists) throw StateError('Flight route no longer exists');
      await replaceWaypoints(planId: id, waypoints: points);
      return id;
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
      final height = point.height;
      if (height != null && !height.meters.isFinite) {
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

  FlightRoute? _readRoute(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    return FlightRoute(
      plan: rows.first.readTable(_database.flightPlans),
      waypoints: [
        for (final row in rows)
          if (row.readTableOrNull(_database.flightWaypoints) case final point?)
            _readPoint(point),
      ],
    );
  }

  RouteWaypoint _readPoint(FlightWaypoint point) {
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
        if (!meters.isFinite) {
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
      return RouteWaypoint(
        id: point.id,
        planId: point.planId,
        sequenceNumber: point.sequenceNumber,
        position: Wgs84Coordinate(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        height: height,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid stored waypoint ${point.id}: $error');
    }
  }

  @override
  Future<FlightRoute?> getRoute(int id) async =>
      _readRoute(await _routeQuery(id).get());

  @override
  Stream<FlightRoute?> watchRoute(int id) =>
      _routeQuery(id).watch().map(_readRoute);

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
  Future<int> deleteFlightPlan(int id) {
    RepositoryValidation.id(id);
    return (_database.delete(
      _database.flightPlans,
    )..where((table) => table.id.equals(id))).go();
  }
}
