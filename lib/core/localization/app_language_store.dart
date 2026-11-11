import '../database/fpv_database.dart';
import 'app_localizations.dart';

class AppLanguageStore {
  const AppLanguageStore(this.database);

  final FpvDatabase database;
  static const _key = 'ui.language';

  Future<AppLanguage> read() async {
    final setting = await (database.select(
      database.appSettings,
    )..where((row) => row.key.equals(_key))).getSingleOrNull();
    return AppLanguage.fromCode(setting?.value);
  }

  Future<void> write(AppLanguage language) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: _key, value: language.code),
        );
  }
}
