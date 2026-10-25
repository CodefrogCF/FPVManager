import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/navigation_location.dart';
import 'package:fpvmanager/features/mobility/road_navigation.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';
import 'package:fpvmanager/features/mobility/traffic_bulletin.dart';

import 'traffic_incident_test.dart' show trafficGroup;
import 'road_navigation_test.dart' show exampleRoute;

class _Locations implements NavigationLocationSource {
  final source = StreamController<NavigationFix>.broadcast();
  @override
  Stream<NavigationFix> watch() => source.stream;
}

void main() {
  testWidgets(
    'search and temporal filters include unlocated public events; grouped details and metrics fit a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = SituationalProvider(
        kind: SituationalKind.traffic,
        center: MobilityPoint(47, 8),
        now: () => DateTime.utc(2026, 10, 25, 10),
      );
      addTearDown(provider.dispose);
      String group(String document) => document.substring(
        document.indexOf('<situation id='),
        document.indexOf('</situation>') + '</situation>'.length,
      );
      final missing = group(trafficGroup(id: 'missing', located: false))
          .replaceAll('A1 Zürich', 'A2 Basel');
      final planned = group(trafficGroup(id: 'planned'))
          .replaceAll('2026-10-25T09:00:00Z', '2026-10-26T09:00:00Z')
          .replaceAll('A1 Zürich', 'A3 Chur');
      await tester.runAsync(
        () => provider.importText(
          trafficGroup().replaceFirst(
            '</payloadPublication>',
            '$missing$planned</payloadPublication>',
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrafficBulletin(provider: provider),
            ),
          ),
        ),
      );
      expect(find.textContaining('3 Ereignisse'), findsOneWidget);
      expect(find.textContaining('Ohne Kartenposition'), findsOneWidget);
      expect(find.text('Staulänge: 2.5 km'), findsNWidgets(2));
      expect(find.textContaining('A3 Chur'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Basel');
      await tester.pump();
      expect(find.textContaining('A1 Zürich'), findsNothing);
      expect(find.textContaining('A2 Basel'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.ensureVisible(find.text('Geplant'));
      await tester.tap(find.text('Geplant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A3 Chur'), findsOneWidget);
      expect(find.textContaining('A2 Basel'), findsNothing);
      final title = find.textContaining('A3 Chur');
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.textContaining('Meldung geändert:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic updates use a one-minute cadence, pause in background, and stop when switched off',
    (tester) async {
      var now = DateTime.utc(2026, 10, 25, 10), requests = 0;
      final provider = SituationalProvider(
        kind: SituationalKind.traffic,
        center: MobilityPoint(47, 8),
        now: () => now,
        readTrafficKey: () async => 'fixture-only',
        client: MockClient((_) async {
          requests++;
          return http.Response(
            trafficGroup(time: now.toIso8601String()),
            200,
            headers: {'content-type': 'text/xml; charset=utf-8'},
          );
        }),
      );
      final locations = _Locations(), router = RoadRouter();
      final nav = RoadNavigation(
        route: exampleRoute(),
        router: router,
        locations: locations,
        traffic: provider,
        automaticTrafficUpdates: true,
        now: () => now,
      );
      addTearDown(() async {
        nav.dispose();
        provider.dispose();
        router.dispose();
        await locations.source.close();
      });
      await tester.runAsync(() => provider.fetch());
      nav.start();
      await tester.pump();
      expect(requests, 1);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(requests, 2);
      nav.pause();
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      expect(requests, 2);
      nav.start();
      await tester.pump();
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(requests, 3);
      nav.setAutomaticTrafficUpdates(false);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(requests, 3);
      nav.pause();
      await tester.pump();
    },
  );
}
