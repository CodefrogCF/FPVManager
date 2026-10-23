import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/airspace/uas_zone_details_panel.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/uas_zone_fixture.dart';

void main() {
  late GlobeController controller;
  late FakeGlobeRenderer renderer;
  late MockClient client;

  setUp(() async {
    final first = uasFixtureFeature(
      overrides: {'name': 'First zone', 'restriction': 'PROHIBITED'},
    );
    final second = uasFixtureFeature(
      overrides: {'name': 'Second zone', 'restriction': 'CONDITIONAL'},
    );
    final hole = uasFixtureFeature(overrides: {'name': 'Hole zone'});
    (hole['geometry']['coordinates'] as List).add([
      [8.06, 47.01],
      [8.09, 47.01],
      [8.09, 47.04],
      [8.06, 47.04],
      [8.06, 47.01],
    ]);
    client = MockClient(
      (_) async => http.Response(
        jsonEncode(uasFixtureCollection([first, second, hole])),
        200,
      ),
    );
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
    await controller.setUasZonesVisible(true);
  });

  tearDown(() {
    controller.dispose();
    client.close();
  });

  void select() => renderer.emit({
    'type': 'uas-zone-selected',
    'id': 'rendered-first',
    'name': 'First zone',
    'attributes': uasFixtureAttributes,
    'latitude': 47.025,
    'longitude': 8.075,
  });

  test('map selection exposes every overlap, retaining duplicate IDs and excluding holes', () async {
    select();
    for (
      var attempt = 0;
      attempt < 100 && controller.selectedUasZones.length != 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(controller.selectedUasZones.map((z) => z.name), [
      'First zone',
      'Second zone',
    ]);
    expect(controller.selectedUasZones.map((z) => z.id).toSet(), hasLength(1));
    controller.selectUasZone(1);
    expect(controller.selectedUasZone!.value('restriction'), 'CONDITIONAL');
    expect(controller.selectedUasZoneIndex, 1);
    controller.selectUasZone(2);
    expect(controller.selectedUasZoneIndex, 1);
  });

  test(
    'a late overlap calculation cannot restore a dismissed selection',
    () async {
      select();
      controller.clearSelectedUasZone();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.selectedUasZone, isNull);
      expect(controller.selectedUasZones, isEmpty);
    },
  );

  testWidgets(
    'each overlapping zone is accessible in compact details on a narrow display',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        select();
        for (
          var attempt = 0;
          attempt < 100 && controller.selectedUasZones.length != 2;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(controller.selectedUasZones, hasLength(2));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => UasZoneDetailsPanel(
                zone: controller.selectedUasZone!,
                zones: controller.selectedUasZones,
                selectedIndex: controller.selectedUasZoneIndex,
                onZoneSelected: controller.selectUasZone,
                source: controller.uasSource,
                downloadedAtUtc: controller.uasDisplayedDataset!.fetchedAtUtc,
                onClose: controller.clearSelectedUasZone,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Zone 1 of 2 at this position'), findsOneWidget);
      await tester.tap(find.byTooltip('Next zone'));
      await tester.pump();
      expect(find.text('Second zone'), findsOneWidget);
      expect(find.text('Zone 2 of 2 at this position'), findsOneWidget);
      await tester.tap(find.text('Inspect restrictions'));
      await tester.pumpAndSettle();
      expect(find.byType(UasZoneDetailsSheet), findsOneWidget);
      expect(find.text('CONDITIONAL'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
