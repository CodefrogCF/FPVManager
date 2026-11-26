import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

SceneryManifest sceneryFixture({
  String id = 'synthetic-site',
  bool enabled = true,
}) => SceneryManifest.fromJson({
  'schemaVersion': 1,
  'id': id,
  'name': 'Synthetic site',
  'description': 'Synthetic test geometry',
  'source': {
    'author': 'FPVManager tests',
    'url': 'https://example.invalid/synthetic',
    'license': 'CC0-1.0',
    'attribution': 'Synthetic fixture, CC0-1.0',
  },
  'anchor': {
    'longitude': 13.8,
    'latitude': 52.4,
    'heightM': 100.0,
    'reference': 'WGS84_ELLIPSOID',
  },
  'bounds': {'west': 13.79, 'east': 13.81, 'south': 52.39, 'north': 52.41},
  'rotation': {'headingDeg': 20.0, 'pitchDeg': 0.0, 'rollDeg': 0.0},
  'scale': 1.0,
  'assets': [
    {
      'id': 'exterior',
      'role': 'visual',
      'provider': 'bundled',
      'format': 'glb',
      'uri': 'synthetic.glb',
    },
    {
      'id': 'walls',
      'role': 'collision',
      'provider': 'bundled',
      'format': 'fpc',
      'uri': 'synthetic.fpc',
    },
  ],
  'collision': {
    'enabled': true,
    'assetIds': ['walls'],
    'sidedness': 'double',
  },
  'visibility': {
    'enabled': enabled,
    'loadRadiusM': 2500.0,
    'unloadRadiusM': 4000.0,
  },
  'minimumAppVersion': '0.20.0',
});
