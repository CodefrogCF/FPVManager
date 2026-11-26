import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:fpvmanager/features/scenery/scenery_model_import.dart';
import 'package:fpvmanager/features/scenery/scenery_collision_import.dart';

/// Synthetic CC0 geometry; coordinates below are post-glTF local ENU metres.
class CollisionFixture {
  final vertices = <double>[];
  void quad(List<double> a, List<double> b, List<double> c, List<double> d) {
    for (final p in [a, b, c, a, c, d]) {
      vertices.addAll([p[1], p[2], p[0]]);
    }
  }

  void box(double x, double y, double z, double X, double Y, double Z) {
    final p = [
      for (var i = 0; i < 8; i++)
        [i & 1 == 0 ? x : X, i & 2 == 0 ? y : Y, i & 4 == 0 ? z : Z],
    ];
    for (final ids in [
      [0, 4, 6, 2],
      [1, 3, 7, 5],
      [0, 1, 5, 4],
      [2, 6, 7, 3],
      [0, 2, 3, 1],
      [4, 5, 7, 6],
    ]) {
      quad(p[ids[0]], p[ids[1]], p[ids[2]], p[ids[3]]);
    }
  }

  Future<PreparedSceneryModel> model({
    int mode = 4,
    Map<String, dynamic>? node,
  }) {
    final bytes = Uint8List(vertices.length * 4),
        data = ByteData.sublistView(bytes);
    for (var i = 0; i < vertices.length; i++) {
      data.setFloat32(i * 4, vertices[i], Endian.little);
    }
    final doc = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'uri': 'mesh.bin', 'byteLength': bytes.length},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': bytes.length},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': vertices.length ~/ 3,
          'type': 'VEC3',
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0},
              'mode': mode,
            },
          ],
        },
      ],
      'nodes': [
        node ?? {'mesh': 0},
      ],
      'scenes': [
        {
          'nodes': [0],
        },
      ],
      'scene': 0,
    };
    return const SceneryModelImporter().prepare(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(doc))),
      name: 'synthetic.gltf',
      readResource: (_) async => bytes,
    );
  }

  Future<PreparedSceneryCollision> collider() async =>
      generateSceneryCollision((await model()).bytes);
}

CollisionFixture collisionRoom() {
  final f = CollisionFixture();
  void wall(double y, double z, double Y, double Z) =>
      f.quad([0, y, z], [0, Y, z], [0, Y, Z], [0, y, Z]);
  wall(-15, 0, -2, 6);
  wall(2, 0, 8, 6);
  wall(-2, 0, 2, 1);
  wall(-2, 3, 2, 6);
  wall(8, 4, 10, 6);
  wall(10, 0, 15, 6);
  f.quad([0, -15, 0], [20, -15, 0], [20, 15, 0], [0, 15, 0]);
  f.quad([0, -15, 6], [20, -15, 6], [20, 15, 6], [0, 15, 6]);
  f.quad([20, -15, 0], [20, 15, 0], [20, 15, 6], [20, -15, 6]);
  f.box(7.8, 5.8, 0, 8.2, 6.2, 6);
  f.box(5, -6, 3, 15, -5.6, 3.4);
  // Hollow cylindrical pipe; its open bore must remain passable.
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
    f.quad(
      [5 + .5 * math.cos(a), 5 + .5 * math.sin(a), 0],
      [5 + .5 * math.cos(b), 5 + .5 * math.sin(b), 0],
      [5 + .5 * math.cos(b), 5 + .5 * math.sin(b), 6],
      [5 + .5 * math.cos(a), 5 + .5 * math.sin(a), 6],
    );
  }
  return f;
}

CollisionFixture collisionGrid({int cells = 70}) {
  final f = CollisionFixture();
  for (var y = 0; y < cells; y++) {
    for (var z = 0; z < cells; z++) {
      f.quad(
        [0, y.toDouble(), z.toDouble()],
        [0, y + 1.0, z.toDouble()],
        [0, y + 1.0, z + 1.0],
        [0, y.toDouble(), z + 1.0],
      );
    }
  }
  return f;
}
