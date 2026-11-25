import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

Map<String, dynamic> tilesetMetadata() => {
  'version': '1.1',
  'anchor': {
    'longitude': 13.8,
    'latitude': 52.4,
    'heightM': 100,
    'reference': 'WGS84_ELLIPSOID',
  },
  'bounds': {'west': 13.79, 'south': 52.39, 'east': 13.81, 'north': 52.41},
  'boundingSphere': {
    'center': [3787292.237531, 930245.043917, 5030166.351224],
    'radiusM': 1000,
  },
  'copyright': 'Synthetic fixture, CC0-1.0',
};
SceneryManifest sceneryTilesetFixture({String id = 'synthetic-tileset'}) {
  final metadata = tilesetMetadata();
  return SceneryManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': 'Synthetic tileset',
    'description': 'Synthetic provider',
    'source': {
      'author': 'FPVManager tests',
      'url': 'https://provider.example/terms',
      'license': 'CC0-1.0',
      'attribution': 'Synthetic fixture, CC0-1.0',
    },
    'anchor': metadata['anchor'],
    'bounds': metadata['bounds'],
    'rotation': {'headingDeg': 0, 'pitchDeg': 0, 'rollDeg': 0},
    'scale': 1,
    'assets': [
      {
        'id': 'visual',
        'role': 'visual',
        'provider': 'remote-tiles',
        'format': '3d-tiles',
        'uri': 'https://provider.example/tileset.json?key=fixture',
        'tileset': {
          'version': '1.1',
          'boundingSphere': metadata['boundingSphere'],
          'cachePolicy': 'no-store',
          'maximumScreenSpaceError': 16,
        },
      },
    ],
    'collision': {
      'enabled': false,
      'assetIds': <String>[],
      'sidedness': 'double',
    },
    'visibility': {'enabled': true, 'loadRadiusM': 2500, 'unloadRadiusM': 4000},
    'minimumAppVersion': '0.19.29',
  });
}
