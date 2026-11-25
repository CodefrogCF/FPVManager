import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import 'scenery_manifest.dart';

final class SceneryRepository {
  const SceneryRepository(this.database);
  final FpvDatabase database;
  static const initializedKey = 'map.scenery.catalog.initialized.v1';
  static const maxCount = 64;
  static const maxCatalogBytes = 1024 * 1024;

  Future<List<SceneryManifest>> list() async {
    final rows = await (database.select(
      database.sceneries,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    return List.unmodifiable(
      rows.map((row) {
        final manifest = SceneryManifest.fromJson(jsonDecode(row.manifestJson));
        if (manifest.id != row.id) {
          throw const FormatException('Scenery ID mismatch');
        }
        return manifest;
      }),
    );
  }

  /// Seed exactly once so deleting a bundled scene survives restart/restore.
  /// Old preference keys remain readable by older versions; malformed data is
  /// reported, never silently discarded or replaced by catalog defaults.
  Future<void> initializeBundled(List<SceneryManifest> defaults) =>
      database.transaction(() async {
        final marker = await (database.select(
          database.appSettings,
        )..where((t) => t.key.equals(initializedKey))).getSingleOrNull();
        if (marker != null) {
          if (marker.value != '1') {
            throw const FormatException(
              'Invalid scenery initialization marker',
            );
          }
          return;
        }
        final legacy = DriftUserPreferencesRepository(database);
        final enabled = await legacy.getSceneryPreferences();
        final edits = await legacy.getSceneryEdits();
        final existing = {for (final m in await list()) m.id: m};
        for (final base in defaults) {
          if (existing.containsKey(base.id)) continue;
          var manifest = base.withEnabled(enabled[base.id] ?? base.enabled);
          if (edits[base.id] case final Map<String, dynamic> edit) {
            manifest = manifest.withLegacyEdit(edit, migrateLegacyBase: true);
          }
          existing[manifest.id] = manifest;
        }
        _validateCatalog(existing.values);
        for (final manifest in existing.values) {
          await database
              .into(database.sceneries)
              .insertOnConflictUpdate(
                SceneriesCompanion.insert(
                  id: manifest.id,
                  manifestJson: jsonEncode(manifest.toJson()),
                ),
              );
        }
        await database
            .into(database.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: initializedKey, value: '1'),
            );
      });

  Future<void> create(SceneryManifest manifest) =>
      _save(manifest, create: true);
  Future<void> update(SceneryManifest manifest) =>
      _save(manifest, create: false);
  Future<void> _save(SceneryManifest manifest, {required bool create}) =>
      database.transaction(() async {
        final current = {for (final m in await list()) m.id: m};
        if (current.containsKey(manifest.id) == create) {
          throw StateError(
            create ? 'Scenery already exists' : 'Unknown scenery',
          );
        }
        current[manifest.id] = manifest;
        _validateCatalog(current.values);
        await database
            .into(database.sceneries)
            .insertOnConflictUpdate(
              SceneriesCompanion.insert(
                id: manifest.id,
                manifestJson: jsonEncode(manifest.toJson()),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      });

  Future<void> remove(String id) async {
    final count = await (database.delete(
      database.sceneries,
    )..where((t) => t.id.equals(id))).go();
    if (count == 0) throw StateError('Unknown scenery');
  }

  static void validateStoredRow(String id, String json) {
    final manifest = SceneryManifest.fromJson(jsonDecode(json));
    if (manifest.id != id) throw const FormatException('Scenery ID mismatch');
  }

  static void _validateCatalog(Iterable<SceneryManifest> manifests) {
    final docs = manifests.map((m) => m.toJson()).toList();
    if (docs.length > maxCount ||
        utf8.encode(jsonEncode(docs)).length > maxCatalogBytes) {
      throw StateError('Scenery catalog exceeds storage limit');
    }
  }
}
