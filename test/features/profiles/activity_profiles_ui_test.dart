import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/activity_profile.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/home/home_navigation_drawer.dart';
import 'package:fpvmanager/features/profiles/activity_profile_editor.dart';
import 'package:fpvmanager/features/profiles/activity_profile_files.dart';
import 'package:fpvmanager/features/profiles/activity_profiles_repository.dart';
import 'package:fpvmanager/features/profiles/activity_profiles_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late ActivityProfilesController controller;
  setUp(() async {
    db = FpvDatabase(NativeDatabase.memory());
    controller = ActivityProfilesController(ActivityProfilesRepository(db));
    await controller.load();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<void> openProfiles(
    WidgetTester tester, {
    ActivityProfileFiles files = const ActivityProfileFiles(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Profile öffnen'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityProfilesScreen(
                    controller: controller,
                    onActivate: (_) async {},
                    files: files,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Profile öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first use offers editable presets, custom profiles and an explicit skip',
    (tester) async {
      await openProfiles(tester);
      expect(find.text('Womit möchtest du starten?'), findsOneWidget);
      expect(find.text('FPV'), findsOneWidget);
      expect(find.text('Wandern'), findsOneWidget);
      await tester.tap(find.text('Überspringen · alle Werkzeuge'));
      await tester.pumpAndSettle();
      expect(controller.catalog!.firstUseDone, isTrue);
      expect(controller.selected, isNull);
      await tester.tap(find.text('Profile öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Ohne Profil · alle Werkzeuge'), findsOneWidget);
      await tester.tap(find.text('Wandern'));
      await tester.pumpAndSettle();
      expect(controller.selected!.id, 'hiking');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'profile editor saves an empty custom workspace and retains unsaved edits on cancelled back',
    (tester) async {
      await openProfiles(tester);
      await tester.scrollUntilVisible(
        find.text('Eigenes Profil'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Eigenes Profil'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Meine Tour');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.text('Meine Tour'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Profil speichern'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil speichern'));
      await tester.pumpAndSettle();
      final custom = controller.catalog!.profiles.singleWhere(
        (p) => p.name == 'Meine Tour',
      );
      expect(custom.tools, isEmpty);
      expect(custom.actions, isEmpty);
      expect(custom.map.style, isNull);
      expect(controller.selected, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'import requires review, cancellation changes nothing and accepted import stays inactive',
    (tester) async {
      final imported = decodeActivityProfile(
        encodeActivityProfile(activityProfileTemplates().first),
      );
      await openProfiles(tester, files: _Files(imported));
      final importButton = find.widgetWithText(OutlinedButton, 'Importieren');
      await tester.scrollUntilVisible(
        importButton,
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(importButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(controller.catalog!.profiles, hasLength(6));
      await tester.tap(importButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Importieren'));
      await tester.pumpAndSettle();
      expect(controller.catalog!.profiles, hasLength(7));
      expect(controller.selected, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed profile save keeps the editable draft and retry saves it',
    (tester) async {
      var fail = true;
      ActivityProfile? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Entwurf öffnen'),
                onPressed: () => Navigator.push<ActivityProfile>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityProfileEditor(
                      initial: ActivityProfile(id: 'draft', name: ''),
                      onSave: (p) async {
                        if (fail) throw StateError('disk unavailable');
                        saved = p;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Entwurf öffnen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Abendlicht');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Profil speichern'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Profil speichern'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil speichern'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.byType(ActivityProfileEditor), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      fail = false;
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Profil speichern'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil speichern'));
      await tester.pumpAndSettle();
      expect(saved!.name, 'Abendlicht');
      expect(find.text('Entwurf öffnen'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'the complete-tools map shortcut opens full groups directly before renderer readiness',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            profilesRepository: ActivityProfilesRepository(db),
            preferencesRepository: UserPreferencesRepository(db),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Profil wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wandern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Map actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle Werkzeuge'));
      await tester.pumpAndSettle();
      expect(find.text('Dein Arbeitsbereich'), findsNothing);
      expect(find.text('Gespeicherte Orte'), findsOneWidget);
      expect(find.text('Flugvorbereitung'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a stored activity restores its workspace and map defaults after startup',
    (tester) async {
      await controller.select('hiking');
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            globeController: globe,
            profilesRepository: ActivityProfilesRepository(db),
            preferencesRepository: UserPreferencesRepository(db),
            spotRepository: SpotRepository(db),
          ),
        ),
      );
      final renderer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Aktivitätsprofil: Wandern'), findsOneWidget);
      expect(
        renderer.commands.lastWhere(
          (c) => c['type'] == 'set-map-style',
        )['style'],
        'topographic',
      );
      expect(globe.location.enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'profile management and editor fit landscape and large text with keyboard focus',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: ActivityProfileEditor(
            initial: activityProfileTemplates().first,
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.scrollUntilVisible(
        find.text('Profil speichern'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Profil speichern'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'profile-aware home preserves globe, selection and active simulation; all tools remain available',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            globeController: globe,
            profilesRepository: ActivityProfilesRepository(db),
            preferencesRepository: UserPreferencesRepository(db),
            spotRepository: SpotRepository(db),
          ),
        ),
      );
      final globeElement = tester.element(find.byType(GlobeView));
      final renderer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      renderer.emit({
        'type': 'point-selected',
        'latitude': 46.8,
        'longitude': 8.3,
        'altitude': 1200,
        'heightReference': 'wgs84Ellipsoid',
      });
      await tester.pumpAndSettle();
      final point = globe.selectedPoint;
      renderer.emit({
        'type': 'simulation-state',
        'active': true,
        'pending': false,
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aktivitätsprofile'));
      await tester.pumpAndSettle();
      renderer.commands.clear();
      await tester.tap(find.text('Wandern'));
      await tester.pumpAndSettle();
      expect(globe.simulationActive, isTrue);
      expect(globe.selectedPoint, same(point));
      expect(
        renderer.commands.where((c) => c['type'] == 'set-map-style'),
        isEmpty,
      );
      expect(tester.element(find.byType(GlobeView)), same(globeElement));
      renderer.emit({
        'type': 'simulation-state',
        'active': false,
        'pending': false,
      });
      await tester.pumpAndSettle();
      expect(
        renderer.commands
            .where((c) => c['type'] == 'set-map-style')
            .single['style'],
        'topographic',
      );
      expect(globe.selectedPoint, same(point));
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Gespeicherte Orte'), findsOneWidget);
      expect(find.text('Flugvorbereitung'), findsNothing);
      await tester.ensureVisible(find.text('Alle Werkzeuge'));
      await tester.tap(find.text('Alle Werkzeuge'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Flugvorbereitung'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Flugvorbereitung'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty profile still exposes complete tools and settings', (
    tester,
  ) async {
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: HomeNavigationDrawer(
            profile: ActivityProfile(id: 'empty', name: 'Leer'),
            onSpots: noop,
            onRoutes: noop,
            onWeather: noop,
            onDrones: noop,
            onBatteries: noop,
            onRadio: noop,
            onSettings: noop,
            onPreflight: noop,
          ),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('Menü'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Alle Werkzeuge'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
    await tester.tap(find.text('Alle Werkzeuge'));
    await tester.pumpAndSettle();
    expect(find.text('Gespeicherte Orte'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Android exports use the bounded native document flow and contain only profile settings',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('com.codefrog.fpvmanager/route_files');
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return true;
          });
      expect(
        await const ActivityProfileFiles().save(
          activityProfileTemplates().first,
        ),
        isTrue,
      );
      expect(received!.method, 'saveActivityProfile');
      expect(received!.arguments['name'], endsWith('.fpvprofile'));
      final content = utf8.decode(
        (received!.arguments['bytes'] as List).cast<int>(),
      );
      expect(decodeActivityProfile(content).name, 'FPV');
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _Files extends ActivityProfileFiles {
  const _Files(this.profile);
  final ActivityProfile profile;
  @override
  Future<ActivityProfile?> pick() async => profile;
}
