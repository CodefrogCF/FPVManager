import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_model_bounds.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/scenery/bounds_reference.json').readAsStringSync(),
  ) as Map;
  for (final (i, raw) in (fixture['cases'] as List).indexed) {
    test('ECEF model bounds agree with pinned Cesium matrix case $i', () {
      final pose = raw['pose'] as Map;
      final doc = <String, dynamic>{
        'anchor': {
          'longitude': pose['longitude'],
          'latitude': pose['latitude'],
          'heightM': pose['ellipsoidHeightM'],
          'reference': 'WGS84_ELLIPSOID',
        },
        'rotation': {
          'headingDeg': pose['rotationDeg'],
          'pitchDeg': pose['pitchDeg'],
          'rollDeg': pose['rollDeg'],
        },
        'scale': pose['scale'],
        'assets': [
          {
            'model': {'localBounds': raw['localBounds']},
          },
        ],
      };
      final result = transformedSceneryBounds(doc);
      for (final key in ['minimum', 'maximum']) {
        for (var j = 0; j < 3; j++) {
          expect(result[key][j], closeTo(raw[key][j] as num, 1e-7));
        }
      }
      (doc['anchor'] as Map)['reference'] = 'TERRAIN_RELATIVE';
      final ground = (pose['ellipsoidHeightM'] as num).toDouble() - 5;
      (doc['anchor'] as Map)['heightM'] = 5;
      expect(transformedSceneryBounds(doc)['pendingTerrain'], true);
      final relative = transformedSceneryBounds(doc, terrainHeightM: ground);
      for (var j = 0; j < 3; j++) {
        expect(relative['minimum'][j], closeTo(raw['minimum'][j] as num, 1e-7));
      }
    });
  }
}
