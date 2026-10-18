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
  });
}
