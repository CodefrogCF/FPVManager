import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/simulation/failsafe_settings.dart';

void main() {
  test('Simulated failsafe preferences persist and reset locally', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = UserPreferencesRepository(db);
    expect((await repo.getPreferences()).failsafe.enabled, false);
    const chosen = FailsafeSettings(
      enabled: true,
      mode: 'gpsRescue',
      rescueAltitudeMeters: 75,
      recoveryDelaySeconds: 4,
      autoRecover: false,
    );
    await repo.savePreferences(const UserPreferences(failsafe: chosen));
    final stored = (await UserPreferencesRepository(
      db,
    ).getPreferences()).failsafe;
    expect(stored.toJson(), chosen.toJson());
    await repo.savePreferences(
      (await repo.getPreferences()).copyWith(roadsVisible: true),
    );
    expect((await repo.getPreferences()).failsafe.toJson(), chosen.toJson());
    await repo.resetPreferences();
    expect((await repo.getPreferences()).failsafe.enabled, false);
  });
}
