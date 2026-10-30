import 'package:drift/drift.dart';

import '../../core/database/fpv_database.dart';
import 'ground_route.dart';

class GroundRouteSummary {
  const GroundRouteSummary(this.id, this.name, this.mode, this.savedAt);
  final int id;
  final String name;
  final GroundTravelMode mode;
  final DateTime savedAt;
}

class GroundRouteRepository {
  const GroundRouteRepository(this.database);
  final FpvDatabase database;
  static GroundRoutePlan validateRow(GroundRoute row) {
    final route = GroundRoutePlan.decode(row.routeJson);
    if (route.name != row.name || route.mode.name != row.mode) {
      throw const FormatException('Widersprüchliche Bodenroute');
    }
    return route;
  }

  Future<int> save(GroundRoutePlan route, {int? id}) async {
    final text = route.encode();
    GroundRoutePlan.decode(text);
    final record = GroundRoutesCompanion(
      name: Value(route.name),
      mode: Value(route.mode.name),
      routeJson: Value(text),
      savedAt: Value(DateTime.now().toUtc()),
    );
    if (id == null) return database.into(database.groundRoutes).insert(record);
    final count = await (database.update(
      database.groundRoutes,
    )..where((t) => t.id.equals(id))).write(record);
    if (count != 1) throw StateError('Bodenroute nicht mehr vorhanden');
    return id;
  }

  Future<List<int>> importAll(List<GroundRoutePlan> routes) {
    if (routes.isEmpty ||
        routes.length > 20 ||
        routes.fold<int>(0, (n, r) => n + r.points.length) > 20000) {
      throw const FormatException('Zu viele importierte Bodenrouten');
    }
    return database.transaction(
      () async => [for (final route in routes) await save(route)],
    );
  }

  Future<GroundRoutePlan?> read(int id) async {
    final row = await (database.select(
      database.groundRoutes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : validateRow(row);
  }

  Stream<List<GroundRouteSummary>> watch({int limit = 50, String query = ''}) {
    if (limit < 1 || limit > 500) throw ArgumentError('Ungültiges Listenlimit');
    if (query.length > 120) throw ArgumentError('Suchtext zu lang');
    return database
        .customSelect(
          'SELECT id,name,mode,saved_at FROM ground_routes WHERE instr(lower(name),lower(?))>0 ORDER BY saved_at DESC,id DESC LIMIT ?',
          variables: [
            Variable.withString(query.trim()),
            Variable.withInt(limit),
          ],
          readsFrom: {database.groundRoutes},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              GroundRouteSummary(
                r.read<int>('id'),
                r.read<String>('name'),
                GroundTravelMode.values.byName(r.read<String>('mode')),
                r.read<DateTime>('saved_at'),
              ),
          ],
        );
  }

  Future<void> delete(int id) => (database.delete(
    database.groundRoutes,
  )..where((t) => t.id.equals(id))).go();
}
