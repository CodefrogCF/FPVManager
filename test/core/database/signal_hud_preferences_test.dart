import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/simulation/signal_hud_settings.dart';

void main() {
  test(
    'Signal warning preferences persist in local SQLite and reset cleanly',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = UserPreferencesRepository(db);
      expect(
        (await repository.getPreferences()).signalHud.analogNoise,
        isFalse,
      );
      const chosen = SignalHudSettings(
        djiWarning: true,
        betaflightBars: true,
        analogNoise: true,
        terrainIllustration: true,
        weakThreshold: .7,
        criticalThreshold: .4,
        lostThreshold: .12,
        analogIntensity: .8,
      );
      await repository.savePreferences(
        const UserPreferences(signalHud: chosen),
      );
      final stored = (await UserPreferencesRepository(
        db,
      ).getPreferences()).signalHud;
      expect(stored.toJson(), chosen.toJson());
      await repository.savePreferences(
        (await repository.getPreferences()).copyWith(roadsVisible: true),
      );
      expect(
        (await repository.getPreferences()).signalHud.toJson(),
        chosen.toJson(),
      );
      await repository.resetPreferences();
      expect(
        (await repository.getPreferences()).signalHud.toJson(),
        const SignalHudSettings().toJson(),
      );
    },
  );
}
