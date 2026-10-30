import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/ground_routes/ground_route.dart';
import 'package:fpvmanager/features/ground_routes/ground_route_repository.dart';
import 'package:fpvmanager/features/ground_routes/ground_routes_screen.dart';
import 'package:fpvmanager/features/ground_routes/ground_router.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'ground routing requires explicit mode and endpoint consent; saves and failed recalculations retain the correct mode',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      void point(double lat, double lon) => peer.emit({
        'type': 'point-selected',
        'latitude': lat,
        'longitude': lon,
        'altitude': 500,
        'heightReference': 'wgs84Ellipsoid',
      });
      var calls = 0, fail = false, time = DateTime.utc(2026, 10, 30, 12);
      final router = GroundRouter(
        now: () => time,
        client: MockClient((r) async {
          calls++;
          if (fail) return http.Response('down', 503);
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 2200,
                  'duration': 1800,
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [8, 47],
                      [8.02, 47.01],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(router.dispose);
      final repo = GroundRouteRepository(db);
      await tester.pumpWidget(
        MaterialApp(
          home: GroundRoutesScreen(
            repository: repo,
            spots: SpotRepository(db),
            globe: globe,
            router: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final calculate = find.widgetWithText(
        FilledButton,
        'Bodenroute berechnen',
      );
      expect(tester.widget<FilledButton>(calculate).onPressed, isNull);
      expect(calls, 0);
      await tester.tap(find.byType(DropdownButtonFormField<GroundTravelMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zu Fuß').last);
      await tester.pumpAndSettle();
      point(47, 8);
      await tester.tap(find.text('Start wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gewählten Kartenpunkt übernehmen'));
      await tester.pumpAndSettle();
      point(47.01, 8.02);
      await tester.tap(find.text('Ziel wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gewählten Kartenpunkt übernehmen'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(calculate).onPressed, isNull);
      expect(calls, 0);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(calls, 1);
      final save = find.text('Bodenroute speichern');
      await tester.scrollUntilVisible(
        save,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(() => repo.watch().first);
      expect(saved!.single.mode, GroundTravelMode.walking);
      fail = true;
      time = time.add(const Duration(seconds: 2));
      final mode = find.byType(DropdownButtonFormField<GroundTravelMode>);
      await tester.scrollUntilVisible(
        mode,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(mode), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Velo').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(calculate);
      await tester.pumpAndSettle();
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.textContaining('zuvor berechnete Route bleibt erhalten'),
        findsOneWidget,
      );
      expect(find.text('Angezeigte Route: Zu Fuß'), findsOneWidget);
      expect(
        (await tester.runAsync(() => repo.read(saved.single.id)))!.mode,
        GroundTravelMode.walking,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
