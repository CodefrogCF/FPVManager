import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';

import 'dart:convert';
import 'dart:async';

import '../../helpers/fake_globe_renderer.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

void main() {
  group('GlobeController', () {
    late GlobeController controller;
    late List<Map<String, dynamic>> commands;
    late MockClient mockClient;
    late FakeGlobeRenderer renderer;

    setUp(() {
      commands = [];

      mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [8.5, 47.4],
                },
                'properties': {'name': 'Test UAS Zone'},
              },
            ],
          }),
          200,
        );
      });

      controller = GlobeController(
        uasProvider: SwissUasProvider(client: mockClient),
      );

      renderer = FakeGlobeRenderer(controller, commands: commands);
      renderer.attach();
    });

    tearDown(() {
      controller.dispose();
      mockClient.close();
    });

    test(
      'UAS transport diagnostics separate inflate, parse and Cesium stages',
      () {
        renderer.ready();
        renderer.emit({
          'type': 'uas-bridge-decode-metrics',
          'commandType': 'set-uas-zones',
          'characters': 2000000,
          'chunkCount': 4,
          'transport': 'gzip-base64',
          'decodeMs': 12.5,
          'parseMs': 38.2,
        });
        final observed = controller.uasBridgeDecodeMetrics;
        expect(observed, isNotNull);
        expect(observed!.transport, 'gzip-base64');
        expect(observed.expandMs, 12.5);
        expect(observed.parseMs, 38.2);
        expect(observed.characters, 2000000);
      },
    );

    test('processes globe-ready event', () {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      expect(controller.isReady, isTrue);
      expect(controller.terrainAvailable, isTrue);
    });

    test('sends reset camera command', () async {
      controller.handleEvent(
        renderer.encode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      await controller.resetCamera();

      expect(commands.single['type'], 'reset-camera');
    });

    test('sends coordinate navigation command', () async {
      controller.handleEvent(
        renderer.encode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      await controller.flyTo(latitude: 46.7, longitude: 8.4, altitude: 12000);

      expect(commands.single['type'], 'fly-to');
      expect(commands.single['latitude'], 46.7);
      expect(commands.single['longitude'], 8.4);
    });

    test('rejects invalid coordinates', () {
      controller.handleEvent(
        renderer.encode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      expect(
        () => controller.flyTo(latitude: 95, longitude: 8.4),
        throwsArgumentError,
      );
    });

    test('handles map style updates', () {
      renderer.ready();
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'map-style-changed',
          'style': 'topographic',
        }),
      );

      expect(controller.mapStyle, GlobeMapStyle.topographic);
    });

    test('ignores messages from unknown sources', () {
      controller.handleEvent(
        renderer.encode({'source': 'other-application', 'type': 'globe-ready'}),
      );

      expect(controller.isReady, isFalse);
    });

    test('toggles UAS zone overlay and processes status', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      // Request activation.
      await controller.setUasZonesVisible(true);

      expect(commands.last['type'], 'set-uas-zones');

      expect(commands.last['visible'], isTrue);

      // Cesium reports that the download has started.
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': false,
          'loading': true,
        }),
      );

      expect(controller.uasZonesLoading, isTrue);
      expect(controller.uasZonesVisible, isFalse);

      // Cesium reports successful activation.
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': true,
          'loading': false,
        }),
      );

      expect(controller.uasZonesLoading, isFalse);
      expect(controller.uasZonesVisible, isTrue);
      expect(controller.uasZonesError, isNull);

      // Request deactivation.
      await controller.setUasZonesVisible(false);

      expect(commands.last['visible'], isFalse);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': false,
          'loading': false,
        }),
      );

      expect(controller.uasZonesVisible, isFalse);
    });

    test('zone attributes preserve display-limit metadata and reject malformed envelopes', () {
      renderer.ready();
      final event = {
        'type': 'uas-zone-selected',
        'id': 'fixture',
        'name': 'Fixture zone',
        'attributes': {
          'restriction': 'FUTURE_CODE',
          'lowerLimit': '0',
          'uomDimensions': 'FT',
          'lowerVerticalReference': 'AGL',
        },
        'omittedAttributeCount': 2,
        'truncatedAttributes': ['message'],
      };
      renderer.emit(event);
      final zone = controller.selectedUasZone!;
      expect(zone.omittedAttributeCount, 2);
      expect(zone.truncatedAttributes, ['message']);
      expect(zone.heightLimit(upper: false), '0 FT · AGL');
      expect(zone.value('restriction'), 'FUTURE_CODE');
      renderer.emit({
        ...event,
        'truncatedAttributes': [7],
      });
      expect(controller.selectedUasZone, same(zone));
      renderer.emit({
        ...event,
        'attributes': {'message': 'x' * 8001},
      });
      expect(controller.selectedUasZone, same(zone));
    });

    test('selects and clears UAS zone details', () {
      renderer.ready();
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zone-selected',
          'id': 'test-zone-123',
          'name': 'Example UAS Zone',
          'attributes': {
            'category': 'Test category',
            'authority': 'Test authority',
          },
        }),
      );

      expect(controller.selectedUasZone, isNotNull);

      expect(controller.selectedUasZone!.name, 'Example UAS Zone');

      expect(
        controller.selectedUasZone!.attributes['authority'],
        'Test authority',
      );

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zone-cleared',
        }),
      );

      expect(controller.selectedUasZone, isNull);
    });

    test('updates UAS opacity and source metadata', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await controller.setUasZonesFillOpacity(0.4);

      expect(commands.last['type'], 'set-uas-opacity');
      expect(commands.last['opacity'], 0.4);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': true,
          'loading': false,
          'fillOpacity': 0.4,
          'featureCount': 42,
          'downloadedAtUtc': '2026-10-19T08:00:00.000Z',
        }),
      );

      expect(controller.uasZonesFillOpacity, 0.4);
      expect(controller.uasZonesFeatureCount, 42);
      expect(controller.uasZonesDownloadedAt, isNotNull);
      expect(controller.uasZonesDownloadedAt!.isUtc, isTrue);
    });

    test('rejects invalid UAS opacity', () {
      expect(
        () => controller.setUasZonesFillOpacity(-0.1),
        throwsArgumentError,
      );

      expect(() => controller.setUasZonesFillOpacity(1.5), throwsArgumentError);
    });

    test('notifies listeners after applying a complete UAS status', () {
      renderer.ready();
      var notifications = 0;
      controller.addListener(() {
        notifications++;
        expect(controller.uasZonesVisible, isTrue);
        expect(controller.uasZonesLoading, isFalse);
        expect(controller.uasZonesFillOpacity, 0.4);
        expect(controller.uasZonesFeatureCount, 42);
        expect(controller.uasZonesDownloadedAt, DateTime.utc(2026, 10, 19, 8));
        expect(controller.uasZonesError, 'Refresh failed');
      });

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': true,
          'loading': false,
          'fillOpacity': 0.4,
          'featureCount': 42,
          'downloadedAtUtc': '2026-10-19T08:00:00.000Z',
          'error': 'Refresh failed',
        }),
      );

      expect(notifications, 1);
    });

    test('ignores malformed UAS status without changing state', () {
      renderer.ready();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': 'true',
          'loading': false,
          'fillOpacity': 0.8,
        }),
      );

      expect(notifications, 0);
      expect(controller.uasZonesVisible, isFalse);
      expect(controller.uasZonesFillOpacity, 0.2);
    });

    test(
      'keeps point, saved spot and UAS selections mutually exclusive',
      () async {
        renderer.ready();
        await controller.setSpotMarkers([
          const SpotMapMarker(
            id: 1,
            name: 'Spot B',
            latitude: 47,
            longitude: 8.5,
          ),
        ]);

        void selectPoint() => controller.handleEvent(
          renderer.encode({
            'source': 'fpvmanager-globe',
            'type': 'point-selected',
            'latitude': 46.7,
            'longitude': 8.4,
            'altitude': 500,
          }),
        );
        void selectSpot() => controller.handleEvent(
          renderer.encode({
            'source': 'fpvmanager-globe',
            'type': 'spot-selected',
            'id': 1,
          }),
        );
        void selectZone() => controller.handleEvent(
          renderer.encode({
            'source': 'fpvmanager-globe',
            'type': 'uas-zone-selected',
            'id': 'zone',
            'attributes': <String, String>{},
          }),
        );

        selectPoint();
        selectSpot();
        expect(controller.selectedSpotId, 1);
        expect(controller.selectedPoint, isNull);
        expect(controller.selectedUasZone, isNull);

        selectZone();
        expect(controller.selectedUasZone, isNotNull);
        expect(controller.selectedSpotId, isNull);
        expect(controller.selectedPoint, isNull);

        selectPoint();
        expect(controller.selectedPoint?.latitude, 46.7);
        expect(controller.selectedSpotId, isNull);
        expect(controller.selectedUasZone, isNull);

        selectZone();
        controller.clearSelectedUasZone();
        expect(controller.selectedPoint, isNull);

        selectZone();
        selectSpot();
        expect(controller.selectedUasZone, isNull);
        selectPoint();
        expect(controller.selectedSpotId, isNull);

        selectSpot();
        controller.clearSelectedSpot();
        expect(controller.selectedPoint, isNull);
      },
    );

    test('refreshes UAS zones through the provider', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await controller.setUasZonesVisible(true);

      expect(commands.last['type'], 'set-uas-zones');

      expect(commands.last['geojson']['type'], 'FeatureCollection');

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': true,
          'loading': false,
        }),
      );

      await controller.refreshUasZones();

      expect(commands.last['type'], 'replace-uas-zones');

      expect(commands.last['geojson']['features'], isNotEmpty);
    });

    test('queries terrain elevation and receives result', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      final request = controller.queryTerrainElevation(
        latitude: 46.7,
        longitude: 8.4,
      );

      await Future<void>.delayed(Duration.zero);

      final command = commands.last;

      expect(command['type'], 'query-terrain-elevation');

      expect(command['latitude'], 46.7);
      expect(command['longitude'], 8.4);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'command-result',
          'commandType': 'query-terrain-elevation',
          'ok': true,
          'requestId': command['requestId'],
          'result': {
            'latitude': 46.7,
            'longitude': 8.4,
            'heightMeters': 1450.5,
            'heightReference': 'wgs84Ellipsoid',
            'samplingMethod': 'most-detailed',
          },
        }),
      );

      final result = await request;

      expect(result.heightMeters, 1450.5);
      expect(result.elevation.reference, VerticalReference.wgs84Ellipsoid);
      expect(result.samplingMethod, 'most-detailed');
    });

    test('rejects terrain heights without a matching explicit datum', () async {
      renderer.ready();
      for (final reference in [null, 'ln02', 'unverified', 'unknown']) {
        final request = controller.queryTerrainElevation(
          latitude: 46.7,
          longitude: 8.4,
        );
        renderer.acknowledge(
          commands.last,
          result: {
            'latitude': 46.7,
            'longitude': 8.4,
            'heightMeters': 550,
            'heightReference': ?reference,
            'samplingMethod': 'most-detailed',
          },
        );
        await expectLater(request, throwsFormatException);
      }
    });

    test('rejects invalid terrain coordinates', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await expectLater(
        controller.queryTerrainElevation(latitude: 95, longitude: 8.4),
        throwsArgumentError,
      );
    });

    test('propagates terrain sampling errors', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      final request = controller.queryTerrainElevation(
        latitude: 46.7,
        longitude: 8.4,
      );

      final expectation = expectLater(request, throwsStateError);

      await Future<void>.delayed(Duration.zero);

      final requestId = commands.last['requestId'];

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'command-result',
          'commandType': 'query-terrain-elevation',
          'ok': false,
          'requestId': requestId,
          'error': 'Terrain unavailable',
        }),
      );

      await expectation;
    });

    test('focuses a spot using sampled terrain height', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      final request = controller.focusSpot(
        latitude: 46.95108,
        longitude: 7.43863,
        rangeMeters: 300,
      );

      await Future<void>.delayed(Duration.zero);

      final terrainCommand = commands.last;

      expect(terrainCommand['type'], 'query-terrain-elevation');

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'command-result',
          'commandType': 'query-terrain-elevation',
          'ok': true,
          'requestId': terrainCommand['requestId'],
          'result': {
            'latitude': 46.95108,
            'longitude': 7.43863,
            'heightMeters': 550.0,
            'heightReference': 'wgs84Ellipsoid',
            'samplingMethod': 'most-detailed',
          },
        }),
      );

      await request;

      final focusCommand = commands.last;

      expect(focusCommand['type'], 'focus-spot');
      expect(focusCommand['latitude'], 46.95108);
      expect(focusCommand['longitude'], 7.43863);
      expect(focusCommand['terrainHeightMeters'], 550.0);
      expect(focusCommand['rangeMeters'], 300);
    });

    test('rejects invalid spot focus distance', () async {
      await expectLater(
        controller.focusSpot(
          latitude: 46.95108,
          longitude: 7.43863,
          rangeMeters: -100,
        ),
        throwsArgumentError,
      );
    });

    test('synchronizes saved spot markers', () async {
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await controller.setSpotMarkers([
        const SpotMapMarker(
          id: 7,
          name: 'FPV Test Spot',
          latitude: 46.95108,
          longitude: 7.43863,
        ),
      ]);

      final command = commands.last;

      expect(command['type'], 'set-spot-markers');
      expect(command['spots'], hasLength(1));
      expect(command['spots'][0]['id'], 7);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'spot-selected',
          'id': 7,
        }),
      );

      expect(controller.selectedSpotId, 7);

      await controller.setSpotMarkers([]);

      expect(controller.selectedSpotId, isNull);
      expect(commands.last['spots'], isEmpty);
    });

    test('transfers 10000 markers and rejects larger snapshots', () async {
      renderer.ready();
      final markers = List.generate(
        10000,
        (i) => SpotMapMarker(
          id: i + 1,
          name: 'Spot $i',
          latitude: 47,
          longitude: 8,
        ),
      );
      await controller.setSpotMarkers(markers);
      expect(commands.last['type'], 'set-spot-markers');
      expect(commands.last['spots'], hasLength(10000));
      await expectLater(
        controller.setSpotMarkers([
          ...markers,
          const SpotMapMarker(
            id: 10001,
            name: 'Over limit',
            latitude: 47,
            longitude: 8,
          ),
        ]),
        throwsArgumentError,
      );
      renderer.emit({'type': 'spot-selected', 'id': 10000});
      expect(controller.selectedSpotId, 10000);
    });

    test('rejects invalid and unknown spot markers', () async {
      await expectLater(
        controller.setSpotMarkers([
          const SpotMapMarker(
            id: 1,
            name: 'Invalid Spot',
            latitude: 120,
            longitude: 8,
          ),
        ]),
        throwsArgumentError,
      );

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'spot-selected',
          'id': 999,
        }),
      );

      expect(controller.selectedSpotId, isNull);
    });

    test(
      'restores requested layers, opacity and markers for a new renderer',
      () async {
        renderer.ready();
        await controller.setMapStyle(GlobeMapStyle.topographic);
        await controller.setUasZonesFillOpacity(0.45);
        await controller.setSpotMarkers([
          const SpotMapMarker(
            id: 1,
            name: 'Saved',
            latitude: 46.7,
            longitude: 8.4,
          ),
        ]);
        await controller.setUasZonesVisible(true);
        commands.clear();
        renderer.sessionId = 'renderer-2';
        renderer.sequence = 0;
        renderer.emit({'type': 'renderer-loading'});
        expect(controller.isReady, isFalse);
        expect(controller.uasZonesVisible, isFalse);
        renderer.ready();
        await Future<void>.delayed(Duration.zero);
        expect(
          commands.map((command) => command['type']),
          containsAllInOrder([
            'set-map-style',
            'set-uas-opacity',
            'set-spot-markers',
            'set-uas-zones',
          ]),
        );
        expect(
          commands.every((command) => command['sessionId'] == 'renderer-2'),
          isTrue,
        );
        expect(commands.first['style'], 'topographic');
        expect(commands[1]['opacity'], 0.45);
        expect(commands[2]['spots'], hasLength(1));
        expect(commands.last['geojson'], isNotNull);
      },
    );

    test(
      'suspension cancels terrain requests and accepts the resumed renderer',
      () async {
        renderer.ready();
        final query = controller.queryTerrainElevation(
          latitude: 46.7,
          longitude: 8.4,
        );
        final check = expectLater(query, throwsStateError);
        controller.suspend();
        expect(controller.isReady, isFalse);
        await check;
        renderer.emit({
          'type': 'uas-zones-status',
          'visible': true,
          'loading': true,
        });
        renderer.emit({
          'type': 'point-selected',
          'latitude': 46.7,
          'longitude': 8.4,
          'altitude': 500,
        });
        expect(controller.uasZonesVisible, isFalse);
        expect(controller.uasZonesLoading, isFalse);
        expect(controller.selectedPoint, isNull);
        renderer.ready();
        expect(controller.isReady, isTrue);
      },
    );

    test(
      'a download completed after reload only goes to the current renderer',
      () async {
        controller.dispose();
        mockClient.close();
        final response = Completer<http.Response>();
        mockClient = MockClient((_) => response.future);
        controller = GlobeController(
          uasProvider: SwissUasProvider(client: mockClient),
        );
        renderer = FakeGlobeRenderer(controller, commands: commands);
        renderer.attach();
        renderer.ready();
        final original = controller.setUasZonesVisible(true);
        renderer.sessionId = 'new-renderer';
        renderer.sequence = 0;
        renderer.emit({'type': 'renderer-loading'});
        renderer.ready();
        response.complete(
          http.Response('{"type":"FeatureCollection","features":[]}', 200),
        );
        await original;
        await Future<void>.delayed(Duration.zero);
        final datasets = commands.where(
          (command) => command['geojson'] != null,
        );
        expect(datasets, hasLength(1));
        expect(datasets.single['sessionId'], 'new-renderer');
      },
    );
  });
}
