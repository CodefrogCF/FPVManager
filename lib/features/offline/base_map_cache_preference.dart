import '../../core/database/fpv_database.dart';

/// Device-specific. Portable backups preserve the destination device's choice.
class BaseMapCachePreference {
  const BaseMapCachePreference(this.database);

  final FpvDatabase database;
  static const _key = 'map.base.cacheOnly';

  Future<bool> read() async {
    final setting = await (database.select(
      database.appSettings,
    )..where((row) => row.key.equals(_key))).getSingleOrNull();
    // Existing installs with no saved choice retain their ordinary online map.
    // If a stored value is malformed, prefer the local-only behavior.
    return setting != null && setting.value != 'false';
  }

  Future<void> write(bool cachedOnly) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: _key, value: cachedOnly.toString()),
        );
  }
}
