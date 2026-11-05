import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/geojson_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late DateTime now;
  late int downloads;
  late MockClient client;
  late GeoJsonOsintProvider provider;
  late GlobeController controller;
  late FakeGlobeRenderer renderer;
  setUp(() {
    now = DateTime.utc(2026, 10, 20, 8);
    downloads = 0;
    client = MockClient((_) async {
      downloads++;
      return http.Response('{"type":"FeatureCollection","features":[]}', 200);
    });
    provider = GeoJsonOsintProvider(
      source: OsintSource(
        id: 'fixture',
        name: 'Airspace fixture',
        publisher: 'Fixture publisher',
        dataUri: Uri.parse('https://example.invalid/data'),
        metadataUri: Uri.parse('https://example.invalid/metadata'),
        coordinateReference: 'EPSG:4326',
      ),
      client: client,
      now: () => now,
    );
    controller = GlobeController(uasProvider: provider);
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
  });
  tearDown(() {
    controller.dispose();
    provider.dispose();
    client.close();
  });

  test(
    'expired renderer data is replaced on reactivation; fresh data is reused',
    () async {
      await controller.setUasZonesVisible(true);
      final first = controller.uasDisplayedDataset;
      await controller.setUasZonesVisible(false);
      await controller.setUasZonesVisible(true);
      expect(downloads, 1);
      expect(renderer.commands.last.containsKey('geojson'), isFalse);
      await controller.setUasZonesVisible(false);
      now = now.add(const Duration(hours: 1));
      await controller.setUasZonesVisible(true);
      expect(downloads, 2);
      expect(renderer.commands.last['type'], 'replace-uas-zones');
      expect(renderer.commands.last['sourceAttribution'], 'Fixture publisher');
      expect(controller.uasDisplayedDataset, isNot(same(first)));
    },
  );

  test(
    'a failed renderer import does not relabel the previously displayed data',
    () async {
      await controller.setUasZonesVisible(true);
      final first = controller.uasDisplayedDataset;
      now = now.add(const Duration(hours: 2));
      renderer.autoAcknowledge = false;
      final request = controller.refreshUasZones();
      final check = expectLater(request, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      renderer.acknowledge(
        renderer.commands.last,
        error: 'Fixture import failed',
      );
      await check;
      expect(provider.cached, isNot(same(first)));
      expect(controller.uasDisplayedDataset, same(first));
      expect(controller.uasDataFreshness, OsintFreshness.stale);
      expect(controller.isReady, isTrue);
    },
  );
  test(
    'HTTP 304 updates freshness without resending or reparsing UAS zones',
    () async {
      var requests = 0;
      final etagClient = MockClient((request) async {
        requests++;
        if (requests > 1) expect(request.headers['If-None-Match'], '"rev1"');
        if (requests == 2) return http.Response('', 304);
        return http.Response(
          '{"type":"FeatureCollection","features":['
          '{"type":"Feature","geometry":{"type":"Point",'
          '"coordinates":[8.5,47.3]},"properties":{"name":"Zone"}}]}',
          200,
          headers: {'etag': '"rev1"'},
        );
      });
      final localProvider = GeoJsonOsintProvider(
        source: provider.source,
        client: etagClient,
        now: () => now,
      );
      final localController = GlobeController(uasProvider: localProvider);
      final localRenderer = FakeGlobeRenderer(localController)..attach();
      localRenderer.ready();
      try {
        await localController.setUasZonesVisible(true);
        final imported = localController.uasDisplayedDataset;
        expect(localRenderer.commands.last['geojson'], isNotNull);
        now = now.add(const Duration(hours: 2));
        await localController.refreshUasZones();
        expect(requests, 2);
        expect(localRenderer.commands.last['type'], 'set-uas-zones');
        expect(localRenderer.commands.last.containsKey('geojson'), isFalse);
        expect(localController.uasDisplayedDataset?.data, same(imported?.data));
        expect(
          localController.uasDisplayedDataset?.fetchedAtUtc,
          imported?.fetchedAtUtc,
        );
        expect(localController.uasNetworkMetrics?.httpStatusCode, 304);
        now = now.add(const Duration(hours: 2));
        await localController.refreshUasZones();
        expect(requests, 3);
        expect(localRenderer.commands.last['type'], 'replace-uas-zones');
        expect(localController.uasNetworkMetrics?.httpStatusCode, 200);
      } finally {
        localController.dispose();
        localProvider.dispose();
        etagClient.close();
      }
    },
  );
}
