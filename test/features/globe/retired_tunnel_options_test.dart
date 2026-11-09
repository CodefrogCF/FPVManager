import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old tunnel options cannot return after restoring preferences',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      final repository = UserPreferencesRepository(db);
      await repository.savePreferences(
        const UserPreferences(
          tunnelRoutesVisible: true,
          tunnelExplorationEnabled: true,
          schematicTunnel3dEnabled: true,
        ),
      );
      final globe = GlobeController();
      final peer = FakeGlobeRenderer(globe)..attach();
      try {
        await globe.initializePreferences(repository);
        peer.ready();
        await globe.preferencesSettled;
        await Future<void>.delayed(Duration.zero);
        expect(globe.tunnelRoutesVisible, isFalse);
        expect(globe.tunnelExplorationEnabled, isFalse);
        expect(globe.schematicTunnel3dEnabled, isTrue);
        final command = peer.commands.lastWhere(
          (command) => command['type'] == 'set-tunnel-infrastructure',
        );
        expect(command['routesVisible'], isFalse);
        expect(command['explorationAllowed'], isFalse);
        expect(command['autoModels'], isTrue);
        await globe.setTunnelInfrastructure(
          routesVisible: true,
          explorationAllowed: true,
          autoModels: true,
        );
        expect(peer.commands.last['routesVisible'], isFalse);
        expect(peer.commands.last['explorationAllowed'], isFalse);
        expect(peer.commands.last['autoModels'], isTrue);
      } finally {
        globe.dispose();
        await globe.preferencesSettled;
        await db.close();
      }
    },
  );
}
