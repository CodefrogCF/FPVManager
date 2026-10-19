import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

void main() {
  group('GlobeController', () {
    late GlobeController controller;
    late List<Map<String, dynamic>> commands;

    setUp(() {
      controller = GlobeController();
      commands = [];

      controller.attach((message) async {
        commands.add(jsonDecode(message) as Map<String, dynamic>);
      });
    });

    tearDown(() {
      controller.dispose();
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
  });
}
