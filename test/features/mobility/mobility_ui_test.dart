import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/mobility_preferences.dart';
import 'package:fpvmanager/features/mobility/mobility_screen.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_layers_section.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';
import 'mobility_test.dart' show routeBody;

void main() {
  testWidgets('free coordinates calculate a route without any saved spots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var requests = 0;
    final router = RoadRouter(
      client: MockClient((r) async {
        requests++;
        expect(r.url.path, endsWith('8.6,47.4'));
        return http.Response(routeBody, 200);
      }),
    );
    addTearDown(router.dispose);
    final globe = GlobeController();
    addTearDown(globe.dispose);
    FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await tester.pumpWidget(
      MaterialApp(
        home: MobilityScreen(
          spots: SpotRepository(db),
          preferences: MobilityPreferences(db),
          globe: globe,
          router: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('destinationSearch')), findsOneWidget);
    for (final pair in [
      ('destinationLat', '47.4'),
      ('destinationLon', '8.6'),
      ('originLat', '47.3'),
      ('originLon', '8.5'),
    ]) {
      final field = find.byKey(ValueKey(pair.$1));
      await tester.ensureVisible(field);
      await tester.enterText(field, pair.$2);
    }
    final consent = find.text(
      'Allow sending start and destination to FOSSGIS / OpenStreetMap routing.',
    );
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    final calculate = find.text('Calculate driving route');
    await tester.ensureVisible(calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('1.2 km · 6 min estimated'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'road planning requires consent, prefers saved parking and returns a route to the globe',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final spots = SpotRepository(db);
      final id = await spots.createSpot(
        name: 'Hill',
        latitude: 47.4,
        longitude: 8.6,
      );
      final preferences = MobilityPreferences(db);
      await preferences.saveAccess(
        id,
        SpotAccess(parking: MobilityPoint(47.35, 8.55)),
      );
      var requests = 0;
      final router = RoadRouter(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, endsWith('8.55,47.35'));
          return http.Response(routeBody, 200);
        }),
      );
      addTearDown(router.dispose);
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MobilityScreen(
                      spots: spots,
                      preferences: preferences,
                      globe: globe,
                      initialSpotId: id,
                      router: router,
                    ),
                  ),
                ),
                child: const Text('Open mobility'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open mobility'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      final calculate = find.widgetWithText(
        FilledButton,
        'Calculate driving route',
      );
      expect(tester.widget<FilledButton>(calculate).onPressed, isNull);
      for (final entry in [('originLat', '47.3'), ('originLon', '8.5')]) {
        final field = find.byKey(ValueKey(entry.$1));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.$2);
      }
      final consent = find.text(
        'Allow sending start and destination to FOSSGIS / OpenStreetMap routing.',
      );
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('1.2 km · 6 min estimated'), findsOneWidget);
      expect(find.text('Navigation starten'), findsOneWidget);
      final show = find.text('Show driving route on map');
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.byType(MobilityScreen), findsNothing);
      expect(globe.situationalVisible('road'), isTrue);
      expect(peer.commands.last['type'], 'set-situational-overlay');
      expect(peer.commands.last['id'], 'road');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'environment layers are independently controllable and source limits remain visible',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SituationalLayersSection(globe: globe),
            ),
          ),
        ),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Published aerodromes & heliports'),
      );
      await tester.pumpAndSettle();
      final wildfire = find.widgetWithText(SwitchListTile, 'Wildfire danger');
      await tester.ensureVisible(wildfire);
      await tester.tap(wildfire);
      await tester.pumpAndSettle();
      expect(globe.situationalVisible('heliports'), isTrue);
      expect(globe.situationalVisible('wildfire'), isTrue);
      expect(
        peer.commands.where((c) => c['type'] == 'set-situational-overlay'),
        hasLength(2),
      );
      peer.emit({
        'type': 'situational-status',
        'id': 'wildfire',
        'state': 'failed',
      });
      await tester.pumpAndSettle();
      expect(find.text('Retry tiles'), findsOneWidget);
      expect(
        find.textContaining('source publication/validity: unknown'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
