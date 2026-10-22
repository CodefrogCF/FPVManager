import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/airspace/uas_data_quality_banner.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/uas_zone_fixture.dart';

void main() {
  testWidgets(
    'aging and failed refresh warn about the actual displayed snapshot',
    (tester) async {
      var now = DateTime.utc(2026, 10, 22, 8);
      var offline = false;
      final client = MockClient((_) async {
        if (offline) throw http.ClientException('fixture offline');
        return http.Response(
          jsonEncode(uasFixtureCollection([uasFixtureFeature()])),
          200,
        );
      });
      final provider = SwissUasProvider(client: client, now: () => now);
      final controller = GlobeController(uasProvider: provider);
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      addTearDown(() {
        controller.dispose();
        provider.dispose();
        client.close();
      });
      await controller.setUasZonesVisible(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UasDataQualityBanner(
              controller: controller,
              onDetails: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Stale cached data'), findsNothing);
      now = now.add(const Duration(hours: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(find.textContaining('Stale cached data'), findsOneWidget);
      expect(find.textContaining('check official sources'), findsOneWidget);
      offline = true;
      await expectLater(
        controller.refreshUasZones(),
        throwsA(isA<OsintProviderException>()),
      );
      await tester.pump();
      expect(find.textContaining('Latest refresh failed'), findsOneWidget);
      expect(controller.uasDisplayedDataset, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('clearing the cache also removes the displayed UAS layer and source metadata', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(uasFixtureCollection([uasFixtureFeature()])),
        200,
      ),
    );
    final provider = SwissUasProvider(client: client);
    final controller = GlobeController(uasProvider: provider);
    final renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      client.close();
    });
    await controller.setUasZonesVisible(true);
    await controller.clearUasCache();
    expect(controller.uasDisplayedDataset, isNull);
    expect(controller.uasDatasetAssessment, isNull);
    expect(controller.uasDisplayedStatus.dataState, OsintDataState.unavailable);
    expect(controller.uasZonesVisible, isFalse);
    expect(renderer.commands.last['type'], 'set-uas-zones');
    expect(renderer.commands.last['visible'], isFalse);
  });
}
