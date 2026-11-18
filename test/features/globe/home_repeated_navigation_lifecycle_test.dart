import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/home/home_navigation_drawer.dart';
import 'package:fpvmanager/features/offline/base_map_cache_preference.dart';
import 'package:fpvmanager/features/settings/app_settings_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

void main() {
  testWidgets(
    'repeated settings navigation keeps same globe and offline records',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      final controller = GlobeController();
      addTearDown(() async {
        controller.dispose();
        await controller.preferencesSettled;
        await db.close();
      });
      final repository = SpotRepository(db);
      final spotId = await repository.createSpot(
        name: 'Offline retained',
        latitude: 46.7,
        longitude: 8.4,
      );
      await BaseMapCachePreference(db).write(true);
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            globeController: controller,
            spotRepository: repository,
            preferencesRepository: UserPreferencesRepository(db),
          ),
        ),
      );
      // The very first renderer must use the saved choice.
      for (final view in tester.widgetList<GlobeView>(find.byType(GlobeView))) {
        expect(view.cachedMaps, isTrue);
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).cachedMaps,
        isTrue,
      );
      final globeElement = tester.element(find.byType(GlobeView));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        // Scroll the drawer itself. The globe can contain other Scrollables,
        // so find.byType(Scrollable).first is not a reliable navigation target.
        final drawer = find.byType(HomeNavigationDrawer);
        final settingsTile = find.descendant(
          of: drawer,
          matching: find.widgetWithText(ListTile, 'Einstellungen'),
        );
        final drawerScroll = find.descendant(
          of: drawer,
          matching: find.byType(Scrollable),
        );
        expect(drawer, findsOneWidget);
        expect(drawerScroll, findsOneWidget);
        await tester.scrollUntilVisible(
          settingsTile,
          180,
          scrollable: drawerScroll,
        );
        await tester.ensureVisible(settingsTile);
        await tester.pumpAndSettle();
        // Fail if the item is still obscured, rather than silently missing it.
        expect(settingsTile.hitTestable(), findsOneWidget);
        await tester.tap(settingsTile);
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsScreen), findsOneWidget);
        expect(find.text('Karte & Ansicht'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(GlobeView)), same(globeElement));
        expect(
          tester.widget<GlobeView>(find.byType(GlobeView)).cachedMaps,
          isTrue,
        );
        expect(controller.isReady, isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final spot = await repository.getSpot(spotId);
      expect(spot?.name, 'Offline retained');
      expect(tester.takeException(), isNull);
    },
  );
}
