import 'dart:convert';
import 'dart:typed_data';

import 'package:fpvmanager/features/scenery/scenery_model_import.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

Uint8List triangleBytes() {
  final out = Uint8List(36), b = ByteData.sublistView(out);
  final values = [0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 3.0, 0.0];
  for (var i = 0; i < values.length; i++) {
    b.setFloat32(i * 4, values[i], Endian.little);
  }
  return out;
}

Map<String, dynamic> triangleGltf() => jsonDecode(
  jsonEncode({
    'asset': {'version': '2.0'},
    'buffers': [
      {'uri': 'mesh.bin', 'byteLength': 36},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteLength': 36},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0, 0, 0],
        'max': [0, 0, 0],
      },
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0},
          },
        ],
      },
    ],
    'nodes': [
      {'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'scene': 0,
  }),
) as Map<String, dynamic>;
Future<PreparedSceneryModel> prepareTriangle({
  Map<String, dynamic>? doc,
  Map<String, Uint8List>? files,
}) => const SceneryModelImporter().prepare(
  bytes: Uint8List.fromList(utf8.encode(jsonEncode(doc ?? triangleGltf()))),
  name: 'triangle.gltf',
  readResource: (uri) async => (files ?? {'mesh.bin': triangleBytes()})[uri],
);
SceneryManifest importedTriangle(
  PreparedSceneryModel model, {
  String id = 'imported-triangle',
}) => SceneryManifest.fromJson({
  'schemaVersion': 1,
  'id': id,
  'name': 'Triangle',
  'description': 'Synthetic, CC0',
  'source': {
    'author': 'FPVManager tests',
    'url': null,
    'license': 'CC0-1.0',
    'attribution': 'Synthetic test fixture',
  },
  'anchor': {
    'longitude': 13.8,
    'latitude': 52.4,
    'heightM': 100,
    'reference': 'WGS84_ELLIPSOID',
  },
  'bounds': {'west': 0, 'south': 0, 'east': 0, 'north': 0},
  'rotation': {'headingDeg': 0, 'pitchDeg': 0, 'rollDeg': 0},
  'scale': 1,
  'assets': [
    {
      'id': 'visual',
      'role': 'visual',
      'provider': 'managed',
      'format': 'glb',
      'uri': model.key,
      'model': model.metadata,
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
(Map<String, dynamic>, Uint8List) readTestGlb(Uint8List bytes) {
  final data = ByteData.sublistView(bytes),
      j = data.getUint32(12, Endian.little);
  return (
    jsonDecode(utf8.decode(bytes.sublist(20, 20 + j))) as Map<String, dynamic>,
    Uint8List.sublistView(bytes, 28 + j),
  );
}
