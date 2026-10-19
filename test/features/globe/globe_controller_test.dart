import 'dart:convert';

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

      controller.attach((message) async {
        commands.add(jsonDecode(message) as Map<String, dynamic>);
      });
    });

    tearDown(() {
      controller.dispose();
      mockClient.close();
    });

    test('processes globe-ready event', () {
      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      await controller.resetCamera();

      expect(commands.single['type'], 'reset-camera');
    });

    test('sends coordinate navigation command', () async {
      controller.handleEvent(
        jsonEncode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      await controller.flyTo(latitude: 46.7, longitude: 8.4, altitude: 12000);

      expect(commands.single['type'], 'fly-to');
      expect(commands.single['latitude'], 46.7);
      expect(commands.single['longitude'], 8.4);
    });

    test('rejects invalid coordinates', () {
      controller.handleEvent(
        jsonEncode({'source': 'fpvmanager-globe', 'type': 'globe-ready'}),
      );

      expect(
        () => controller.flyTo(latitude: 95, longitude: 8.4),
        throwsArgumentError,
      );
    });

    test('handles map style updates', () {
      controller.handleEvent(
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'map-style-changed',
          'style': 'topographic',
        }),
      );

      expect(controller.mapStyle, GlobeMapStyle.topographic);
    });

    test('ignores messages from unknown sources', () {
      controller.handleEvent(
        jsonEncode({'source': 'other-application', 'type': 'globe-ready'}),
      );

      expect(controller.isReady, isFalse);
    });

    test('toggles UAS zone overlay and processes status', () async {
      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({
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
        jsonEncode({
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
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'uas-zones-status',
          'visible': false,
          'loading': false,
        }),
      );

      expect(controller.uasZonesVisible, isFalse);
    });

    test('selects and clears UAS zone details', () {
      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({'source': 'fpvmanager-globe', 'type': 'uas-zone-cleared'}),
      );

      expect(controller.selectedUasZone, isNull);
    });

    test('updates UAS opacity and source metadata', () async {
      controller.handleEvent(
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await controller.setUasZonesFillOpacity(0.4);

      expect(commands.last['type'], 'set-uas-opacity');
      expect(commands.last['opacity'], 0.4);

      controller.handleEvent(
        jsonEncode({
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

    test('refreshes UAS zones through the provider', () async {
      controller.handleEvent(
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );

      await controller.setUasZonesVisible(true);

      expect(commands.last['type'], 'set-uas-zones');

      expect(commands.last['geojson']['type'], 'FeatureCollection');

      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({
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
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'terrain-elevation-result',
          'requestId': command['requestId'],
          'latitude': 46.7,
          'longitude': 8.4,
          'heightMeters': 1450.5,
          'samplingMethod': 'most-detailed',
        }),
      );

      final result = await request;

      expect(result.heightMeters, 1450.5);
      expect(result.samplingMethod, 'most-detailed');
    });

    test('rejects invalid terrain coordinates', () async {
      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({
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
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'terrain-elevation-result',
          'requestId': requestId,
          'error': 'Terrain unavailable',
        }),
      );

      await expectation;
    });

    test('focuses a spot using sampled terrain height', () async {
      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'terrain-elevation-result',
          'requestId': terrainCommand['requestId'],
          'latitude': 46.95108,
          'longitude': 7.43863,
          'heightMeters': 550.0,
          'samplingMethod': 'most-detailed',
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
  });
}
