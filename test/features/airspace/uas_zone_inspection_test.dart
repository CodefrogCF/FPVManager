import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';
import 'package:fpvmanager/features/airspace/uas_zone_details_panel.dart';
import 'package:fpvmanager/features/airspace/uas_data_quality_banner.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/uas_zone_fixture.dart';

void main() {
  final source = OsintSource(
    id: 'fixture',
    name: 'Fixture source',
    publisher: 'Fixture publisher',
    dataUri: Uri.parse('https://example.invalid/data'),
    metadataUri: Uri.parse('https://example.invalid/metadata'),
  );
  const zone = UasZoneDetails(
    id: 'fixture',
    name: 'Fixture zone',
    attributes: uasFixtureAttributes,
  );

  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'compact map details open scrollable source restrictions with separate AGL and AMSL limits',
    (tester) async {
      narrow(tester);
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: UasZoneDetailsPanel(
              zone: zone,
              source: source,
              downloadedAtUtc: DateTime.utc(2026, 10, 21),
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inspect restrictions'));
      await tester.pumpAndSettle();
      final sheet = find.byType(UasZoneDetailsSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('0 M · AGL')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('900 M · AMSL')),
        findsOneWidget,
      );
      expect(find.textContaining('Source details missing:'), findsNothing);
      await tester.ensureVisible(find.text('Dataset provenance'));
      expect(
        find.descendant(of: sheet, matching: find.text('Fixture publisher')),
        findsOneWidget,
      );
      expect(find.text('https://example.invalid/data'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Close zone inspection'));
      await tester.tap(find.byTooltip('Close zone inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close details'));
      expect(closed, isTrue);
    },
  );

  testWidgets(
    'missing details and display limits are explicit and raw attributes stay plain text',
    (tester) async {
      narrow(tester);
      final limited = UasZoneDetails(
        id: 'x',
        name: 'Limited zone',
        attributes: {
          ...uasFixtureAttributes,
          'restriction': '',
          'extra': '<b>Untrusted source text</b>',
        },
        omittedAttributeCount: 2,
        truncatedAttributes: ['message'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UasZoneDetailsSheet(
              zone: limited,
              source: source,
              downloadedAtUtc: null,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Source details missing: Restriction code'),
        findsOneWidget,
      );
      expect(find.textContaining('2 attributes omitted'), findsOneWidget);
      expect(
        find.textContaining('Shortened or unavailable values: message'),
        findsOneWidget,
      );
      final raw = find.text(
        'All source attributes (${limited.attributes.length})',
      );
      await tester.ensureVisible(raw);
      await tester.tap(raw);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('<b>Untrusted source text</b>'));
      expect(find.text('<b>Untrusted source text</b>'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty-source banner and layer metadata update when visibility changes',
    (tester) async {
      narrow(tester);
      final client = MockClient(
        (_) async =>
            http.Response('{"type":"FeatureCollection","features":[]}', 200),
      );
      final controller = GlobeController(
        uasProvider: SwissUasProvider(client: client),
      );
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      await controller.setUasZonesVisible(true);
      void visible(bool value) => renderer.emit({
        'type': 'uas-zones-status',
        'visible': value,
        'loading': false,
      });
      visible(true);
      var details = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UasDataQualityBanner(
                  controller: controller,
                  onDetails: () => details = true,
                ),
                Expanded(
                  child: MapLayersSheet(
                    controller: controller,
                    initialTab: MapLayerTab.airspace,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.textContaining('UAS data limited'), findsOneWidget);
      expect(find.text('Limited / incomplete data'), findsOneWidget);
      expect(
        find.text('The source returned an empty dataset.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('UAS data quality'));
      expect(details, isTrue);
      visible(false);
      await tester.pump();
      expect(find.textContaining('UAS data limited'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      client.close();
    },
  );
}
