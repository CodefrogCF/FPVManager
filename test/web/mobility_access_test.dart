@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/mobility_preferences.dart';
import 'package:fpvmanager/features/mobility/mobility_screen.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

class _Spots extends Fake implements SpotRepository {
  @override
  Future<List<Spot>> getAllSpots() async => [];
}

class _Preferences extends Fake implements MobilityPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Web traffic refresh explains CORS without reading keys or attempting transport; local import remains usable', () async {
    var keyReads = 0, requests = 0;
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      readTrafficKey: () async {
        keyReads++;
        return 'test-key';
      },
      client: MockClient((_) async {
        requests++;
        throw StateError('No Web requests expected');
      }),
    );
    addTearDown(provider.dispose);
    final imported = await provider.importText(
      '<d2LogicalModel><payloadPublication><publicationTime>2026-10-24T10:00:00Z</publicationTime></payloadPublication></d2LogicalModel>',
    );
    expect(imported.requiresRevalidation, isTrue);
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(
        isA<OsintProviderException>().having(
          (e) => e.message,
          'message',
          contains('CORS'),
        ),
      ),
    );
    expect(keyReads, 0);
    expect(requests, 0);
    expect(identical(provider.status.dataset, imported), isTrue);
  });

  testWidgets(
    'Web Traffic offers XML import and explains why direct refresh and credential entry are unavailable',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MobilityScreen(
            spots: _Spots(),
            preferences: _Preferences(),
            globe: globe,
            initialTab: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'The ASTRA API rejects direct browser requests (CORS)',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Refresh traffic'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Import DATEX XML'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Save key'), findsNothing);
      expect(find.text('Own ASTRA API key'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
