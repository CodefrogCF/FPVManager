import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_models.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_service.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_store.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_sites_section.dart';

class MemoryMobileSiteStore implements MobileSiteStore {
  MobileSiteSnapshot? value;

  @override
  Future<MobileSiteSnapshot?> read(MobileSiteArea area) async =>
      value?.area.key == area.key ? value!.cached() : null;

  @override
  Future<void> replace(MobileSiteSnapshot snapshot) async {
    value = snapshot;
  }

  @override
  Future<List<MobileSite>> viewport(
    MobileSiteArea area,
    List<double> bounds, {
    int limit = 180,
  }) async => value?.stations.take(limit).toList() ?? [];
}

/// Tests widget interactions without an HTTP request or a background isolate.
/// The real HTTP, async parser and storage paths have their own service tests.
class FixtureMobileSitesService extends MobileSitesService {
  FixtureMobileSitesService(this.fixtureStore, MobilityHttp transport)
    : super(store: fixtureStore, transport: transport);

  final MemoryMobileSiteStore fixtureStore;
  int searches = 0;

  @override
  Future<MobileSiteSnapshot> search(
    MobileSiteArea area, {
    bool refresh = false,
  }) async {
    searches++;
    final stations = parseMobileSites(
      jsonEncode({
        'results': [
          {
            'featureId': 77,
            'attributes': {
              'station': 'Station ZH',
              'koord': '2600000,1200000',
              'techno_de': 'Technologie 4G,5G',
              'power_de': 'Leistungsklasse : mittel (bis 5000 W)',
            },
          },
        ],
      }),
    );
    final snapshot = MobileSiteSnapshot(
      area: area,
      stations: stations,
      fetchedUtc: DateTime.utc(2026, 11, 3),
      truncated: false,
    );
    await fixtureStore.replace(snapshot);
    return snapshot;
  }
}

void main() {
  testWidgets(
    'BAKOM search is opt-in, preserves source fields, never creates height',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);

      // A widget test must not use an actual network connection.
      var unexpectedHttpCalls = 0;
      final client = MockClient((request) async {
        unexpectedHttpCalls++;
        return http.Response('Unexpected widget-test request', 500);
      });
      final transport = MobilityHttp(client: client);
      final store = MemoryMobileSiteStore();
      final service = FixtureMobileSitesService(store, transport);
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MobileSitesSection(
                globe: globe,
                initialCenter: MobilityPoint(46.95, 7.44),
                service: service,
              ),
            ),
          ),
        ),
      );

      expect(service.searches, 0);
      await tester.tap(find.text('BAKOM Mobilfunk-Basisstationen'));
      await tester.pumpAndSettle();

      final search = find.byKey(const ValueKey('mobile_sites_search'));
      expect(tester.widget<FilledButton>(search).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(search).onPressed, isNotNull);
      expect(service.searches, 0);

      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();

      expect(service.searches, 1);
      expect(unexpectedHttpCalls, 0);
      expect(find.text('Station ZH'), findsOneWidget);
      expect(
        find.textContaining('STAC-Metadatenstand: unbekannt'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Station ZH'));
      await tester.tap(find.text('Station ZH'));
      await tester.pumpAndSettle();
      final details = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data;
      expect(details, contains('Technologie 4G,5G'));
      expect(details, contains('bis 5000 W'));
      expect(details, contains('Originalkoordinaten LV95: 2600000, 1200000'));
      expect(details, contains('Objekthöhe: unbekannt'));
    },
  );
}
