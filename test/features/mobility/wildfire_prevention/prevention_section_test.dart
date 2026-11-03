import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_models.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_service.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_section.dart';

class MemorySectionCache implements PreventionCache {
  PreventionSnapshot? snapshot;
  @override
  Future<PreventionSnapshot?> read(String key) async => snapshot?.cached();
  @override
  Future<void> write(String key, PreventionSnapshot value) async {
    snapshot = value;
  }
}

void main() {
  testWidgets(
    'official source and dated measure displayed only after explicit consent',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/legend')) {
          return http.Response('Datenstand: 02.11.2026 12:00', 200);
        }
        return http.Response(
          jsonEncode({
            'results': [
              {
                'featureId': 'ZH-100',
                'properties': {
                  'title_de': 'Absolutes Feuerverbot im Freien',
                  'description_de': 'Generell kein Feuer im Freien erlaubt',
                  'canton': 'ZH',
                  'valid_from': '02.11.2026',
                },
              },
            ],
          }),
          200,
        );
      });
      final transport = MobilityHttp(client: mock);
      final service = PreventionService(
        cache: MemorySectionCache(),
        transport: transport,
        now: () => DateTime.utc(2026, 11, 3, 12),
      );
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        mock.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WildfirePreventionSection(
                globe: globe,
                service: service,
                initialCenter: MobilityPoint(47.37, 8.54),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kantonale Waldbrand-Präventionsmassnahmen'));
      await tester.pumpAndSettle();
      final query = find.byKey(const ValueKey('fire_prevention_query'));
      await tester.ensureVisible(query);
      await tester.tap(query);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.textContaining('Confirm that the chosen coordinate'),
        findsOneWidget,
      );
      final permission = find.byType(CheckboxListTile);
      await tester.ensureVisible(permission);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      await tester.ensureVisible(query);
      await tester.tap(query);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Absolutes Feuerverbot: im Freien'), findsOneWidget);
      expect(find.textContaining('BAFU Feature-ID: ZH-100'), findsOneWidget);
      expect(
        find.textContaining('Publikationsstand der Quelle: 02.11.2026'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
