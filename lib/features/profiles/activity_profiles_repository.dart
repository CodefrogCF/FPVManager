import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/fpv_database.dart';
import '../../core/models/activity_profile.dart';

class ActivityProfilesRepository {
  const ActivityProfilesRepository(this.database);
  final FpvDatabase database;

  Future<ActivityProfileCatalog> load() async {
    final row = await (database.select(
      database.appSettings,
    )..where((t) => t.key.equals(activityProfilesKey))).getSingleOrNull();
    return row == null
        ? ActivityProfileCatalog.initial()
        : ActivityProfileCatalog.decode(row.value);
  }

  Future<void> save(ActivityProfileCatalog catalog) async {
    final text = catalog.encode();
    ActivityProfileCatalog.decode(text);
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: activityProfilesKey,
            value: text,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }
}

class ActivityProfilesController extends ChangeNotifier {
  ActivityProfilesController(this.repository);
  final ActivityProfilesRepository repository;
  ActivityProfileCatalog? _catalog;
  ActivityProfileCatalog? get catalog => _catalog;
  ActivityProfile? get selected => _catalog?.selected;
  bool busy = false;
  String? error;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void>? _writing;
  Future<void> get settled => _loading ?? _writing ?? Future.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _writing?.then((_) => _load()) ?? _load();
  Future<void> _load() async {
    busy = true;
    error = null;
    _notify();
    try {
      _catalog = await repository.load();
    } catch (_) {
      _catalog = null;
      error = 'Profile konnten nicht geladen werden. Erneut versuchen oder ein persönliches Backup wiederherstellen.';
    } finally {
      busy = false;
      _loading = null;
      _notify();
    }
  }

  Future<void> replace(ActivityProfileCatalog next) {
    if (busy || _catalog == null) {
      throw StateError('Profile sind noch nicht verfügbar');
    }
    return _writing = _replace(next);
  }

  Future<void> _replace(ActivityProfileCatalog next) async {
    busy = true;
    error = null;
    _notify();
    try {
      await repository.save(next);
      if (!_disposed) _catalog = next;
    } catch (_) {
      error = 'Profiländerung wurde nicht gespeichert. Bitte erneut versuchen.';
      rethrow;
    } finally {
      busy = false;
      _writing = null;
      _notify();
    }
  }

  Future<void> select(String? id) => replace(
    ActivityProfileCatalog(
      profiles: _catalog!.profiles,
      selectedId: id,
      firstUseDone: true,
    ),
  );

  Future<void> put(ActivityProfile profile) {
    final current = _catalog!;
    return replace(
      ActivityProfileCatalog(
        profiles: [
          for (final p in current.profiles)
            if (p.id == profile.id) profile else p,
          if (!current.profiles.any((p) => p.id == profile.id)) profile,
        ],
        selectedId: current.selectedId,
        firstUseDone: current.firstUseDone,
      ),
    );
  }

  Future<void> remove(String id) => replace(
    ActivityProfileCatalog(
      profiles: _catalog!.profiles.where((p) => p.id != id),
      selectedId: _catalog!.selectedId == id ? null : _catalog!.selectedId,
      firstUseDone: true,
    ),
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
