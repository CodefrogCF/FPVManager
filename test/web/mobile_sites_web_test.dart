import 'dart:async';
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
  final replaced = Completer<void>();
  @override
  Future<MobileSiteSnapshot?> read(MobileSiteArea area) async =>
      value?.area.key == area.key ? value!.cached() : null;
  @override
  Future<void> replace(MobileSiteSnapshot snapshot) async {
    value = snapshot;
    if (!replaced.isCompleted) {
      replaced.complete();
    }
  }

  @override
  Future<List<MobileSite>> viewport(
    MobileSiteArea area,
    List<double> bounds, {
    int limit = 180,
  }) async => value?.stations.take(limit).toList() ?? [];
}

void main() {
  testWidgets(
    'BAKOM search is opt-in, preserves source fields, never creates height',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.host, 'api3.geo.admin.ch');
        expect(request.url.queryParameters['limit'], '200');
        return http.Response(
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
          200,
        );
      });
      final httpTransport = MobilityHttp(client: client);
      final store = MemoryMobileSiteStore();
      final service = MobileSitesService(
        store: store,
        transport: httpTransport,
        budget: MobileSitesBudget(clock: () => DateTime.utc(2026, 11, 3)),
        clock: () => DateTime.utc(2026, 11, 3),
      );
      addTearDown(() async {
        await service.dispose();
        httpTransport.dispose();
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
      expect(calls, 0);
      await tester.tap(find.text('BAKOM Mobilfunk-Basisstationen'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('mobile_sites_search'));
      expect(tester.widget<FilledButton>(search).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pump();
      // The request uses compute() on Android/VM. Waiting for pumpAndSettle()
      // while the progress indicator is animating can exhaust virtual time
      // before the background isolate returns. Synchronize on persistence
      // instead, then pump the completed UI state.
      await tester.runAsync(
        () => store.replaced.future.timeout(const Duration(seconds: 10)),
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Station ZH'), findsOneWidget);
      expect(
        find.textContaining('STAC-Metadatenstand: unbekannt'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Station ZH'));
      await tester.tap(find.text('Station ZH'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Objekthöhe: unbekannt'),
      );
    },
  );
}
