import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/airspace_safety_panel.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
}
