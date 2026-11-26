import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';

import '../../support/scenery_fixture.dart';

void main() {
  test('bounds handle the dateline and pole; deeply nested/non-finite data fail explicitly', () {
    final bounds = sceneryCoverageBounds(179.99, 0, 4000);
    expect(bounds['west']! > bounds['east']!, true);
    final pole = sceneryCoverageBounds(10, 89.99, 4000);
    expect(pole['west'], -180);
    expect(pole['east'], 180);
    final doc = sceneryFixture().toJson();
    doc['scale'] = double.infinity;
    expect(() => SceneryManifest.fromJson(doc), throwsFormatException);
    Object nested = 0;
    for (var i = 0; i < 30; i++) {
      nested = {'child': nested};
    }
    doc['scale'] = 1;
    doc['extensions'] = {'nested': nested};
    expect(() => SceneryManifest.fromJson(doc), throwsFormatException);
  });
  test(
    'manifest roundtrip snapshots all metadata, assets and transformation',
    () {
      final m = sceneryFixture();
      final copy = m.toJson();
      expect(SceneryManifest.fromJson(copy).toJson(), copy);
      (copy['anchor'] as Map)['heightM'] = 200;
      expect((m.toJson()['anchor'] as Map)['heightM'], 100);
      expect(m.verticalReference, VerticalReference.wgs84Ellipsoid);
      expect(m.altitudeMode, FlightAltitudeMode.absolute);
      expect(m.assets.length, 2);
    },
  );
  test(
    'manifest rejects invalid versions, data, bounds, references and resources',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (d) => d['schemaVersion'] = 2,
        (d) => d['id'] = '../site',
        (d) => d['scale'] = 0,
        (d) => (d['anchor'] as Map)['latitude'] = 91,
        (d) => (d['anchor'] as Map)['reference'] = 'unknown',
        (d) => (d['bounds'] as Map)['north'] = 0,
        (d) => (d['rotation'] as Map)['pitchDeg'] = 100,
        (d) => d['minimumAppVersion'] = 'tomorrow',
        (d) => (d['assets'] as List).add((d['assets'] as List).first),
        (d) => ((d['assets'] as List).first as Map)['uri'] = '../outside.glb',
        (d) => ((d['assets'] as List).first as Map)['uri'] =
            'https://user:secret@example.invalid/a.glb',
        (d) => (d['collision'] as Map)['assetIds'] = ['absent'],
        (d) => (d['visibility'] as Map)['unloadRadiusM'] = 100,
      ];
      for (final mutate in mutations) {
        final d = sceneryFixture().toJson();
        mutate(d);
        expect(() => SceneryManifest.fromJson(d), throwsFormatException);
      }
    },
  );
  test('asset definitions allow future formats but cannot execute scripts', () {
    final d = sceneryFixture().toJson();
    final a = (d['assets'] as List).first as Map;
    a.addAll(<String, dynamic>{
      'provider': 'remote',
      'format': '3d-tiles',
      'uri': 'https://example.invalid/tileset.json',
    });
    expect(SceneryManifest.fromJson(d).assets.first.format, '3d-tiles');
    for (final uri in [
      'javascript:alert(1)',
      'file:///secret.glb',
      '//host/a.glb',
      'a.glb?x=1',
      '%2e%2e/a.glb',
    ]) {
      a['uri'] = uri;
      expect(() => SceneryManifest.fromJson(d), throwsFormatException);
    }
  });
  test(
    'provider resolution preserves valid scenes beside unsupported ones',
    () {
      final unsupported = sceneryFixture(id: 'remote-site').toJson();
      ((unsupported['assets'] as List).first as Map)['provider'] = 'future';
      final version = sceneryFixture(id: 'future-version').toJson()
        ..['minimumAppVersion'] = '99.0.0';
      final result = SceneryAssetProviders().compile([
        sceneryFixture(),
        SceneryManifest.fromJson(unsupported),
        SceneryManifest.fromJson(version),
      ]);
      expect((result['sceneries'] as List).length, 1);
      expect((result['unavailable'] as List).length, 2);
      final item = (result['sceneries'] as List).single as Map;
      expect(item['collisionAssets'], ['synthetic.fpc']);
      expect((item['alignment'] as Map)['rotationDeg'], 20);
      expect(item['heightAlignmentMode'], 'fixed');
    },
  );
  test(
    'terrain-relative placement explicitly requires a real terrain sample',
    () {
      final d = sceneryFixture().toJson();
      (d['anchor'] as Map).addAll(<String, dynamic>{
        'reference': 'TERRAIN_RELATIVE',
        'heightM': 12.0,
      });
      final m = SceneryManifest.fromJson(d);
      expect(m.altitudeMode, FlightAltitudeMode.aboveGroundLevel);
      final item =
          (SceneryAssetProviders().compile([m])['sceneries'] as List).single
              as Map;
      expect(item['requireGroundCalibration'], true);
      expect(item['heightOffsetM'], 12);
    },
  );
  test('previous development scenery remains compatible', () {
    final previous = sceneryFixture(id: 'previous-version').toJson()
      ..['minimumAppVersion'] = '0.19.29';
    final future = sceneryFixture(id: 'future-version').toJson()
      ..['minimumAppVersion'] = '0.20.1';
    final providers = SceneryAssetProviders(applicationVersion: '0.20.0');
    final result = providers.compile([
      SceneryManifest.fromJson(previous),
      SceneryManifest.fromJson(future),
    ]);
    expect((result['sceneries'] as List).length, 1);
    expect((result['unavailable'] as List).length, 1);
  });
  test('runtime application version matches the shipped pubspec', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: $sceneryApplicationVersion+'),
    );
  });
}
