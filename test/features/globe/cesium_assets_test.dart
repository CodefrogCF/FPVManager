import 'dart:convert';
import 'dart:io';

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
      final html = await rootBundle.loadString('web/globe.html');
      expect(html, contains('"./cesium/"'));
      expect(html, isNot(contains('cdn.jsdelivr.net')));
      expect(
        await rootBundle.loadString('web/globe_bridge.js'),
        contains('createBridge'),
      );
      expect(html, contains('src="terrain_service.js"'));
      expect(html, contains('src="map_providers.js"'));
      expect(
        await rootBundle.loadString('web/map_providers.js'),
        contains('createAdapters'),
      );
      expect(
        await rootBundle.loadString('web/terrain_service.js'),
        contains('createTerrainManager'),
      );
    },
  );
}
