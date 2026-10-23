import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';
import 'package:fpvmanager/features/airspace/airspace_safety_panel.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test('official validity shows actual UTC bounds and leaves unknown bounds explicit', () {
    expect(officialValidityLabel(null), 'Not supplied / not verified');
    expect(
      officialValidityLabel(OsintValidityPeriod()),
      'Not supplied / not verified',
    );
    final from = DateTime.utc(2026, 10, 23);
    final until = from.add(const Duration(days: 1));
    expect(
      officialValidityLabel(OsintValidityPeriod(from: from, until: until)),
      '${from.toIso8601String()} to ${until.toIso8601String()} (UTC)',
    );
    expect(
      officialValidityLabel(OsintValidityPeriod(until: until)),
      contains('Start not supplied'),
    );
  });
  testWidgets(
    'safety panel discloses missing NOTAM connection and no safety guarantee',
    (tester) async {
      final client = MockClient(
        (_) async =>
            http.Response('{"type":"FeatureCollection","features":[]}', 200),
      );
      final controller = GlobeController(
        uasProvider: SwissUasProvider(client: client),
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AirspaceSafetyPanel(controller: controller)),
        ),
      );
      expect(find.text('Airspace & flight safety'), findsOneWidget);
      expect(
        find.textContaining('cannot issue a flight authorisation'),
        findsOneWidget,
      );
      expect(find.textContaining('Preflight information only'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('official fallback endpoints use HTTPS', () {
    for (final uri in [
      AirspaceOfficialSources.dabs,
      AirspaceOfficialSources.notam,
      AirspaceOfficialSources.uasMap,
      AirspaceOfficialSources.bazl,
      AirspaceOfficialSources.skyguide,
    ]) {
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    }
  });

  testWidgets(
    'an open safety panel updates when cached data expires without another controller event',
    (tester) async {
      var now = DateTime.utc(2026, 10, 23, 12);
      final client = MockClient(
        (_) async =>
            http.Response('{"type":"FeatureCollection","features":[]}', 200),
      );
      final controller = GlobeController(
        uasProvider: SwissUasProvider(
          client: client,
          now: () => now,
          cacheDuration: const Duration(minutes: 1),
        ),
      );
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      await tester.runAsync(() => controller.setUasZonesVisible(true));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AirspaceSafetyPanel(controller: controller)),
        ),
      );
      expect(
        find.text('Local data state: Cached · within local lifetime'),
        findsOneWidget,
      );
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(
        find.text('Local data state: Stale cached data · refresh required'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      client.close();
    },
  );
}
