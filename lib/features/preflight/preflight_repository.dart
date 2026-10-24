import 'package:drift/drift.dart';

import '../../core/database/fpv_database.dart';
import 'checklist.dart';

/// Personal records, with independent completion snapshots for every checklist.
class PreflightRepository {
  const PreflightRepository(this.database);
  final FpvDatabase database;

  Stream<List<PreflightChecklist>> watch() => (database.select(
    database.preflightChecklists,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  Future<List<Drone>> drones() => database.select(database.drones).get();
  Future<List<FlightPlan>> routes() =>
      database.select(database.flightPlans).get();

  Future<int> save({
    int? id,
    required String name,
    required List<ChecklistItem> items,
    bool isTemplate = false,
    int? droneId,
    int? planId,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError('Enter a name up to 120 characters');
    }
    var normalized = [
      for (final i in items)
        ChecklistItem(i.label, checked: !isTemplate && i.checked),
    ];
    encodeChecklist(normalized);
    return database.transaction(() async {
      final table = database.preflightChecklists;
      if (id == null) {
        final count = table.id.count();
        final row = await (database.selectOnly(
          table,
        )..addColumns([count])).getSingle();
        if (row.read(count)! >= 200) {
          throw StateError('The local limit is 200 checklists and templates');
        }
      } else {
        final old = await (database.select(
          table,
        )..where((t) => t.id.equals(id))).getSingle();
        if (old.droneId != droneId ||
            old.planId != planId ||
            old.isTemplate != isTemplate) {
          normalized = [
            for (final item in normalized) ChecklistItem(item.label),
          ];
        }
      }
      final value = PreflightChecklistsCompanion.insert(
        name: name.trim(),
        itemsJson: encodeChecklist(normalized),
        isTemplate: Value(isTemplate),
        droneId: Value(droneId),
        planId: Value(planId),
        updatedAt: Value(DateTime.now().toUtc()),
      );
      if (id == null) {
        return database.into(database.preflightChecklists).insert(value);
      }
      final count = await (database.update(
        database.preflightChecklists,
      )..where((t) => t.id.equals(id))).write(value);
      if (count != 1) throw StateError('Checklist no longer exists');
      return id;
    });
  }

  Future<void> check(int id, int index, bool checked) =>
      database.transaction(() async {
        final row = await (database.select(
          database.preflightChecklists,
        )..where((t) => t.id.equals(id))).getSingle();
        if (row.isTemplate) {
          throw StateError('Start a checklist from this template first');
        }
        final items = decodeChecklist(row.itemsJson).toList();
        if (index < 0 || index >= items.length) {
          throw ArgumentError('Unknown checklist item');
        }
        items[index] = ChecklistItem(items[index].label, checked: checked);
        await save(
          id: id,
          name: row.name,
          items: items,
          droneId: row.droneId,
          planId: row.planId,
        );
      });

  Future<void> delete(int id) async {
    await (database.delete(
      database.preflightChecklists,
    )..where((t) => t.id.equals(id))).go();
  }
}
