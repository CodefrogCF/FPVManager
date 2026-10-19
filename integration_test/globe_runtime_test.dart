import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local renderer works offline and restores state after reload/resume',
    (tester) async {
      var downloads = 0;
      final client = MockClient((_) async {
        downloads++;
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': 'fixture',
                'properties': {'name': 'Integration test zone'},
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [
                    [
                      [8.4, 46.7],
                      [8.5, 46.7],
                      [8.5, 46.8],
                      [8.4, 46.7],
                    ],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final controller = GlobeController(
        uasProvider: SwissUasProvider(client: client),
      );
      addTearDown(() {
        controller.dispose();
        client.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobeView(controller: controller, offline: true),
          ),
        ),
      );

      Future<void> until(
        bool Function() predicate, {
        GlobeController? observed,
      }) async {
        final clock = Stopwatch()..start();
        while (!predicate()) {
          final error = (observed ?? controller).error;
          if (error != null) fail(error);
          if (clock.elapsed > const Duration(seconds: 40)) {
            fail('Renderer did not reach expected state');
          }
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      await until(() => controller.isReady);
      expect(controller.terrainAvailable, isFalse);
      await controller.setMapStyle(GlobeMapStyle.topographic);
      await controller.setUasZonesFillOpacity(0.45);
      await controller.setSpotMarkers([
        const SpotMapMarker(
          id: 1,
          name: 'Integration fixture',
          latitude: 46.7,
          longitude: 8.4,
        ),
      ]);
      await controller.setUasZonesVisible(true);
      await until(
        () => controller.uasZonesVisible && !controller.uasZonesLoading,
      );
      expect(controller.uasZonesFeatureCount, 1);
      expect(controller.mapStyle, GlobeMapStyle.topographic);
      expect(controller.uasZonesFillOpacity, 0.45);
      // Give Cesium's real worker/primitive pipeline time to render the local polygon.
      await tester.pump(const Duration(seconds: 2));
      expect(controller.error, isNull);
      await expectLater(
        controller.queryTerrainElevation(latitude: 46.7, longitude: 8.4),
        throwsStateError,
      );

      var loadingSeen = false;
      void observeReload() {
        if (!controller.isReady) loadingSeen = true;
      }

      controller.addListener(observeReload);
      await controller.reloadRenderer();
      await until(
        () => loadingSeen && controller.isReady && controller.uasZonesVisible,
      );
      controller.removeListener(observeReload);
      expect(controller.mapStyle, GlobeMapStyle.topographic);
      expect(controller.uasZonesFillOpacity, 0.45);
      expect(controller.uasZonesFeatureCount, 1);
      expect(downloads, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.isReady, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(() => controller.isReady && controller.uasZonesVisible);
      expect(controller.mapStyle, GlobeMapStyle.topographic);
      expect(controller.uasZonesFillOpacity, 0.45);

      final replacement = GlobeController(
        uasProvider: SwissUasProvider(client: client),
      );
      addTearDown(replacement.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobeView(controller: replacement, offline: true),
          ),
        ),
      );
      await until(() => replacement.isReady, observed: replacement);
      expect(controller.isReady, isFalse);
      await replacement.setMapStyle(GlobeMapStyle.relief);
      await replacement.setUasZonesFillOpacity(0.65);
      expect(replacement.mapStyle, GlobeMapStyle.relief);
      expect(replacement.uasZonesFillOpacity, 0.65);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
