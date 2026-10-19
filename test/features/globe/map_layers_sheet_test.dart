import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late GlobeController controller;
  late MockClient client;
  late List<Map<String, dynamic>> commands;
  late int downloads;

  setUp(() {
    downloads = 0;
    commands = [];
    client = MockClient((_) async {
      downloads++;
      return http.Response('{"type":"FeatureCollection","features":[]}', 200);
    });
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    controller.attach((message) async {
      commands.add(jsonDecode(message) as Map<String, dynamic>);
    });
    controller.handleEvent(
      jsonEncode({
        'source': 'fpvmanager-globe',
        'type': 'globe-ready',
        'terrainAvailable': true,
      }),
    );
  });

  tearDown(() {
    controller.dispose();
    client.close();
  });

  void status({required bool visible, bool loading = false, String? error}) {
    controller.handleEvent(
      jsonEncode({
        'source': 'fpvmanager-globe',
        'type': 'uas-zones-status',
        'visible': visible,
        'loading': loading,
        'fillOpacity': 0.4,
        'featureCount': 42,
        'downloadedAtUtc': '2026-10-19T08:00:00.000Z',
        'error': error,
      }),
    );
  }

  Future<void> openSheet(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MapLayersSheet(controller: controller)),
    ),
  );

  testWidgets(
    'cached overlay reactivation immediately updates layer controls',
    (tester) async {
      await openSheet(tester);
      final toggle = find.byType(SwitchListTile);

      await tester.tap(toggle);
      await tester.pump();
      expect(downloads, 1);
      status(visible: true);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('2026-10-19 08:00 UTC'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();
      status(visible: false);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pump();
      expect(downloads, 1);
      expect(commands.last['visible'], isTrue);
      expect(commands.last.containsKey('geojson'), isFalse);
      status(visible: true);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    },
  );

  testWidgets('renderer loading and errors are visible without another event', (
    tester,
  ) async {
    await openSheet(tester);
    status(visible: false, loading: true);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Loading official zone data...'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );

    status(visible: false, error: 'Dataset import failed');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Dataset import failed'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
  });

  testWidgets('opacity controls reflect confirmed renderer values', (
    tester,
  ) async {
    await openSheet(tester);
    status(visible: true);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.4);
    expect(find.text('Polygon fill opacity: 40%'), findsOneWidget);
  });
}
