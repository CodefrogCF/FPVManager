import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pinned Cesium runtime, workers and Wasm are all bundled Flutter assets',
    () async {
      final manifest = jsonDecode(
        File('web/cesium/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(manifest['version'], '1.145.0');
      final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
          .listAssets()
          .toSet();
      for (final path in (manifest['files'] as Map).keys) {
        expect(
          assets,
          contains('web/cesium/$path'),
          reason: 'Missing native asset $path',
        );
      }
      for (final path in [
        'Cesium.js',
        'Widgets/widgets.css',
        'ThirdParty/draco_decoder.wasm',
      ]) {
        expect(
          (await rootBundle.load('web/cesium/$path')).lengthInBytes,
          greaterThan(0),
        );
      }
      // Issue #124 uses bundled, generated glTF assets. The app must never
      // rely on a network request for these obstacle models.
      for (final model in [
        'communication-tower',
        'communication-lattice',
        'observation-tower',
      ]) {
        final asset = 'web/models/obstacles/$model.glb';
        expect(assets, contains(asset));
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(1000));
      }
      final html = await rootBundle.loadString('web/globe.html');
      expect(html, contains('"./cesium/"'));
      expect(html, isNot(contains('cdn.jsdelivr.net')));
      expect(
        await rootBundle.loadString('web/core/globe_bridge.js'),
        contains('createBridge'),
      );
      expect(html, contains('src="features/terrain/terrain_service.js"'));
      expect(html, contains('id="hud-battery-readout"'));
      expect(html, contains('src="features/map/map_providers.js"'));
      for (final module in [
        'features/navigation/ground_navigation.js',
        'features/navigation/navigation_controls.js',
        'features/navigation/controller_input.js',
        'features/flight/physics/battery_chemistries.generated.js',
        'features/flight/physics/battery_simulation.js',
        'features/signal/simulated_failsafe.js',
        'features/flight/physics/body_axis_aerodynamics.js',
        'features/flight/physics/descent_aerodynamics.js',
        'features/flight/physics/collision_response.js',
        'features/flight/physics/rotational_dynamics.js',
        'features/flight/autonomous_flight_control.js',
        'features/weather/environmental_wind.js',
        'features/flight/free_flight.js',
        'features/flight/hud/flight_hud.js',
        'features/flight/hud/signal_hud.js',
        'features/signal/rf_estimation.js',
        'features/flight/physics/rescue_velocity.js',
        'features/flight/flight_rendering.js',
        'features/infrastructure/bridge_supports.js',
        'features/infrastructure/bridge_source.js',
        'core/scene_performance.js',
        'features/navigation/route_editor.js',
        'features/infrastructure/obstacle_layers.js',
        'features/infrastructure/obstacle_models.js',
        'offline_map_client.js',
        'features/overlays/situational_layers.js',
        'features/navigation/road_navigation.js',
        'features/map/map_compass.js',
        'core/globe_positions.js',
        'features/map/map_labels.js',
      ]) {
        expect(html, contains('src="$module"'));
        expect(await rootBundle.loadString('web/$module'), isNotEmpty);
      }
      expect(html, contains('href="features/flight/hud/flight_hud.css"'));
      expect(await rootBundle.loadString('web/features/flight/hud/flight_hud.css'), isNotEmpty);
      for (final model in [
        'power-pylon',
        'utility-pole',
        'antenna-mast',
        'lattice-tower',
        'tower-crane',
        'chimney',
        'wind-turbine',
        'cableway-support',
      ]) {
        final bytes = await rootBundle.load('web/models/obstacles/$model.glb');
        expect(bytes.getUint32(0, Endian.little), 0x46546c67);
        expect(bytes.getUint32(8, Endian.little), bytes.lengthInBytes);
      }
      expect(
        await rootBundle.loadString('web/features/map/map_providers.js'),
        contains('createAdapters'),
      );
      expect(
        await rootBundle.loadString('web/features/terrain/terrain_service.js'),
        contains('createTerrainManager'),
      );
    },
  );
}
