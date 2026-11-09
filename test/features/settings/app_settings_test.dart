import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/settings/app_settings_screen.dart';
import 'package:fpvmanager/features/help/guides_screen.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late GlobeController globe;
  late UserPreferencesRepository preferences;
  setUp(() {
    db = FpvDatabase(NativeDatabase.memory());
    globe = GlobeController();
    preferences = UserPreferencesRepository(db);
  });
  tearDown(() async {
    globe.dispose();
    await globe.preferencesSettled;
    await db.close();
  });
  Future<void> noop() async {}
  Widget screen({AppSettingsSection? section}) => MaterialApp(
    home: AppSettingsScreen(
      globe: globe,
      onFlightSettings: noop,
      onWeather: noop,
      onTraffic: noop,
      onAirspace: noop,
      onData: noop,
      section: section,
    ),
  );

  testWidgets(
    'drawer opens app settings before globe readiness and does not fetch providers',
    (tester) async {
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            globeController: globe,
            spotRepository: SpotRepository(db),
            preferencesRepository: preferences,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Einstellungen'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.text('Karte & Ansicht'), findsOneWidget);
      expect(find.text('Datenquellen'), findsOneWidget);
      expect(globe.isReady, false);
      await tester.tap(find.text('Hilfe'));
      await tester.pumpAndSettle();
      expect(find.text('Offline-Karten und Backups'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'shared map values survive contextual help, settings reopening and a controller restart',
    (tester) async {
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.runAsync(() => globe.initializePreferences(preferences));
      await tester.pumpWidget(screen());
      await tester.tap(find.text('Karte & Ansicht'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Orts- und Straßennamen'));
      await tester.tap(find.text('Orts- und Straßennamen'));
      await tester.pumpAndSettle();
      expect(globe.labelsVisible, true);
      expect(globe.roadsVisible, false);
      await tester.ensureVisible(find.text('Hilfe zur Karte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hilfe zur Karte'));
      await tester.pumpAndSettle();
      expect(find.text('Orientierung'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(globe.labelsVisible, true);
      peer.sessionId = 'settings-reload';
      peer.sequence = 0;
      peer.emit({'type': 'renderer-loading'});
      peer.ready();
      await tester.pumpAndSettle();
      expect(
        peer.commands
            .where((c) => c['type'] == 'set-map-labels')
            .last['visible'],
        true,
      );
      expect((await preferences.getPreferences()).labelsVisible, true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      globe.dispose();
      globe = GlobeController();
      FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await globe.initializePreferences(preferences);
      expect(globe.labelsVisible, true);
    },
  );
  testWidgets(
    'settings recover from malformed preferences without overwriting them before explicit retry',
    (tester) async {
      await tester.runAsync(
        () => db.customStatement(
          "INSERT INTO app_settings (key,value,updated_at) VALUES ('map.labels.visible','invalid',0)",
        ),
      );
      await tester.runAsync(() => globe.initializePreferences(preferences));
      await tester.pumpWidget(screen(section: AppSettingsSection.display));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to load map preferences'),
        findsOneWidget,
      );
      expect(find.text('Erneut versuchen'), findsOneWidget);
      await tester.runAsync(
        () => db.customStatement(
          "UPDATE app_settings SET value='true' WHERE key='map.labels.visible'",
        ),
      );
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(globe.labelsVisible, true);
      expect(globe.preferencesError, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'compact landscape and large text keep controls, help and source shortcuts reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var traffic = 0;
      for (final size in [const Size(320, 640), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: AppSettingsScreen(
              key: ValueKey(size),
              globe: globe,
              onFlightSettings: noop,
              onWeather: noop,
              onTraffic: () async {
                traffic++;
              },
              onAirspace: noop,
              onData: noop,
            ),
          ),
        );
        await tester.tap(find.text('Datenquellen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verkehr & Zugänge'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Kurzhilfe: Datenschutz und API-Zugänge'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kurzhilfe: Datenschutz und API-Zugänge'));
        await tester.pumpAndSettle();
        expect(find.byType(GuideArticleScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      expect(traffic, 2);
    },
  );
  testWidgets(
    'map settings use the shared hub without a second set of switches',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppSettingsScreen(
            globe: globe,
            onFlightSettings: noop,
            onWeather: noop,
            onTraffic: noop,
            onAirspace: noop,
            onData: noop,
            onMapLayers: () async {
              opened++;
            },
          ),
        ),
      );
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tap(find.text('Karte & Ansicht'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(AppSettingsScreen), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    },
  );
  testWidgets('open-source notices remain reachable from data sources', (
    tester,
  ) async {
    await tester.pumpWidget(screen(section: AppSettingsSection.sources));
    await tester.scrollUntilVisible(
      find.text('Open-Source-Lizenzen'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open-Source-Lizenzen'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);
  });
}
