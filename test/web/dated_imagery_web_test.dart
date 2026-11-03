import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_models.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_service.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_section.dart';

class BrowserImageryCache implements DatedImageryCache {
  DatedImagerySnapshot? current;
  @override
  Future<DatedImagerySnapshot?> read(DatedImageryProduct p) async =>
      current?.product == p ? current!.saved() : null;
  @override
  Future<void> write(DatedImagerySnapshot s) async {
    current = s;
  }
}

void main() {
  testWidgets(
    'dated STAC is opt-in; acquisition and cloudy coverage stay visible',
    (tester) async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final isItems = request.url.path.endsWith('/items');
        return http.Response(
          isItems
              ? '{"features":[{"id":"scene-1",'
                    '"collection":"ch.swisstopo.swisseo_s2-sr_v200",'
                    '"bbox":[7.0,46.0,8.0,47.5],'
                    '"properties":{"datetime":"2026-11-02T11:00:00Z",'
                    '"eo:cloud_cover":91}}]}'
              : '{"id":"ch.swisstopo.swisseo_s2-sr_v200"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = MobilityHttp(client: client);
      final service = DatedImageryService(
        cache: BrowserImageryCache(),
        transport: transport,
        clock: () => DateTime.utc(2026, 11, 3, 12),
      );
      final globe = GlobeController();
      addTearDown(globe.dispose);
      addTearDown(() async {
        await service.dispose();
        transport.dispose();
        client.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DatedImagerySection(
                globe: globe,
                initialCenter: MobilityPoint(46.95, 7.44),
                service: service,
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(
        find.text('Datierte Satelliten- & Rapid-Mapping-Bilder'),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('dated_imagery_search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('91.0 %'), findsOneWidget);
      expect(find.textContaining('2026-11-02'), findsWidgets);
      expect(find.textContaining('Keine Live-Beobachtung'), findsOneWidget);
      // The user has not selected a frame and the default basemap is untouched.
      expect(globe.datedImageryVisible, false);
    },
  );
}
