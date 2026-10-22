import '../../helpers/fake_globe_renderer.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/core/osint/geojson_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late GlobeController controller;
  late MockClient client;
  late List<Map<String, dynamic>> commands;
  late int downloads;
  late FakeGlobeRenderer renderer;

  setUp(() {
    downloads = 0;
    commands = [];
    client = MockClient((_) async {
      downloads++;
      return http.Response('{"type":"FeatureCollection","features":[]}', 200);
    });
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller, commands: commands);
    renderer.attach();
    controller.handleEvent(
      renderer.encode({
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
      renderer.encode({
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
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Swiss UAS Geographical Zones',
      );

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
    expect(find.text('Loading zone data...'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Swiss UAS Geographical Zones'),
          )
          .onChanged,
      isNull,
    );

    status(visible: false, error: 'Dataset import failed');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Dataset import failed'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Swiss UAS Geographical Zones'),
          )
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('opacity controls reflect confirmed renderer values', (
    tester,
  ) async {
    await openSheet(tester);
    status(visible: true);
    await tester.pump();
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('uas-fill-opacity')))
          .value,
      0.4,
    );
    expect(find.text('Polygon fill opacity: 40%'), findsOneWidget);
  });

  testWidgets(
    'replacement provenance, cache expiry and failed updates stay truthful',
    (tester) async {
      controller.dispose();
      client.close();
      var now = DateTime.utc(2026, 10, 19, 8);
      var fail = false;
      var attempts = 0;
      client = MockClient((_) async {
        attempts++;
        return http.Response(
          fail ? 'Unavailable' : '{"type":"FeatureCollection","features":[]}',
          fail ? 503 : 200,
        );
      });
      final source = OsintSource(
        id: 'replacement',
        name: 'Alternative airspace',
        publisher: 'Fixture publisher',
        dataUri: Uri.parse('https://example.invalid/zones'),
        metadataUri: Uri.parse('https://example.invalid/metadata'),
        licenseName: 'Fixture terms',
        coordinateReference: 'EPSG:4326',
      );
      final provider = GeoJsonOsintProvider(
        source: source,
        client: client,
        now: () => now,
      );
      addTearDown(provider.dispose);
      controller = GlobeController(uasProvider: provider);
      renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      await openSheet(tester);
      await controller.setUasZonesVisible(true);
      status(visible: true);
      await tester.pump();
      expect(find.text('Alternative airspace'), findsOneWidget);
      expect(find.text('Fixture terms'), findsOneWidget);
      expect(find.text('example.invalid'), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Official validity'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.text('Not supplied by this dataset'),
        ),
        findsOneWidget,
      );
      expect(find.text('Within local cache lifetime'), findsOneWidget);
      final displayed = controller.uasDisplayedDataset;
      now = now.add(const Duration(hours: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Cache expired — refresh recommended'), findsOneWidget);
      expect(attempts, 1); // Visible ageing performs no network update.
      fail = true;
      await expectLater(
        controller.refreshUasZones(),
        throwsA(isA<OsintProviderException>()),
      );
      await tester.pump();
      expect(controller.uasDisplayedDataset, same(displayed));
      expect(
        find.text('Update failed — previous map data retained'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('Downloaded'), matching: find.byType(Row))
              .first,
          matching: find.text('2026-10-19 08:00 UTC'),
        ),
        findsOneWidget,
      );
      expect(controller.isReady, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
