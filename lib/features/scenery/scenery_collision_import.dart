import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'scenery_digest.dart';
import 'scenery_model_import.dart';
import 'scenery_manifest.dart';

final class PreparedSceneryCollision {
  PreparedSceneryCollision._(
    Uint8List bytes,
    Map<String, dynamic> metadata,
    this.key,
  ) : bytes = bytes.asUnmodifiableView(),
      metadata = Map.unmodifiable(
        metadata.map(
          (key, value) =>
              MapEntry(key, value is List ? List.unmodifiable(value) : value),
        ),
      );
  final Uint8List bytes;
  final Map<String, dynamic> metadata;
  final String key;
}

Map<String, dynamic> sceneryCollisionAsset(PreparedSceneryCollision mesh) => {
  'id': 'collider-${mesh.key.substring(0, 16)}',
  'role': 'collision',
  'provider': 'managed',
  'format': 'fpc',
  'uri': mesh.key,
  'model': mesh.metadata,
};
SceneryManifest configureSceneryCollision(
  SceneryManifest base,
  List<Map<String, dynamic>> assets, {
  required bool enabled,
  required String sidedness,
}) {
  if (assets.length > 16 || assets.any((a) => a['role'] != 'collision')) {
    _fail('Invalid collision asset selection');
  }
  final doc = base.toJson();
  doc['assets'] = [
    ...(doc['assets'] as List).where((a) => a['role'] == 'visual'),
    ...assets,
  ];
  doc['collision'] = {
    'enabled': enabled,
    'assetIds': assets.map((a) => a['id']).toList(),
    'sidedness': sidedness,
  };
  if (assets.fold<num>(
        0,
        (n, a) => n + ((a['model'] as Map?)?['byteLength'] as num? ?? 0),
      ) >
      SceneryImportLimits.residentBytes) {
    _fail('Collision assets exceed the 128 MiB active budget');
  }
  return SceneryManifest.fromJson(doc);
}

/// Local, texture-free FPC1 geometry. No simplification or hole filling.
Future<PreparedSceneryCollision> prepareSceneryCollision(
  Uint8List bytes,
) async {
  final data = Uint8List.fromList(bytes);
  final metadata = await compute(validateSceneryCollision, data);
  return PreparedSceneryCollision._(
    data,
    Map.unmodifiable(metadata),
    '${await sceneryDigest(data)}.fpc',
  );
}

Future<PreparedSceneryCollision> generateSceneryCollision(
  Uint8List validatedGlb,
) async {
  final geometry = await extractSceneryCollisionGeometry(validatedGlb);
  final generated = await compute(_build, geometry);
  return prepareSceneryCollision(generated);
}

Never _fail(String message) => throw FormatException(message);
const _limit = 64 * 1024 * 1024;
bool _degenerate(Float32List v, int a, int b, int c) {
  final x = List.generate(3, (j) => v[b * 3 + j] - v[a * 3 + j]),
      y = List.generate(3, (j) => v[c * 3 + j] - v[a * 3 + j]);
  return math.pow(x[1] * y[2] - x[2] * y[1], 2) +
          math.pow(x[2] * y[0] - x[0] * y[2], 2) +
          math.pow(x[0] * y[1] - x[1] * y[0], 2) <
      1e-20;
}

Map<String, dynamic> validateSceneryCollision(Uint8List bytes) {
  if (bytes.length < 16 || bytes.length > _limit) {
    _fail('Collision mesh must be a nonempty FPC1 file up to 64 MiB');
  }
  final d = ByteData.sublistView(bytes),
      v = d.getUint32(4, Endian.little),
      t = d.getUint32(8, Endian.little),
      n = d.getUint32(12, Endian.little);
  if (d.getUint32(0, Endian.little) != 0x31435046 ||
      v < 1 ||
      v > 2000000 ||
      t < 1 ||
      t > 2000000 ||
      n < 1 ||
      n > 2 * t ||
      16 + 12 * v + 12 * t + 32 * n != bytes.length) {
    _fail('Invalid FPC1 header');
  }
  // ByteData also validates buffers whose starting offset is not word aligned.
  final vertices = Float32List(3 * v),
      indices = Uint32List(3 * t),
      bounds = Float32List(6 * n),
      children = Int32List(2 * n);
  var offset = 16;
  for (var i = 0; i < vertices.length; i++, offset += 4) {
    final x = d.getFloat32(offset, Endian.little);
    if (!x.isFinite || x.abs() > 1e5) {
      _fail(
        'Collision vertices must be finite local coordinates within 100 km',
      );
    }
    vertices[i] = x;
  }
  for (var i = 0; i < indices.length; i++, offset += 4) {
    final x = d.getUint32(offset, Endian.little);
    if (x >= v) _fail('Invalid collision triangle index');
    indices[i] = x;
  }
  for (var i = 0; i < bounds.length; i++, offset += 4) {
    bounds[i] = d.getFloat32(offset, Endian.little);
  }
  for (var i = 0; i < children.length; i++, offset += 4) {
    children[i] = d.getInt32(offset, Endian.little);
  }
  var node = 0, triangle = 0;
  void visit(int id, int parent, int depth) {
    if (id != node++ || id >= n || depth > 48) {
      _fail('Invalid collision BVH topology');
    }
    final b = id * 6;
    for (var j = 0; j < 3; j++) {
      if (!bounds[b + j].isFinite ||
          !bounds[b + j + 3].isFinite ||
          bounds[b + j] > bounds[b + j + 3] ||
          parent >= 0 &&
              (bounds[b + j] < bounds[parent + j] ||
                  bounds[b + j + 3] > bounds[parent + j + 3])) {
        _fail('Invalid collision BVH bounds');
      }
    }
    final left = children[id * 2], right = children[id * 2 + 1];
    if (left < 0) {
      final start = -left - 1;
      if (start != triangle || right < 1 || right > 16 || start + right > t) {
        _fail('Invalid collision BVH leaf');
      }
      triangle += right;
      for (var k = start; k < start + right; k++) {
        final a = indices[k * 3],
            bb = indices[k * 3 + 1],
            c = indices[k * 3 + 2];
        if (_degenerate(vertices, a, bb, c)) {
          _fail('Collision mesh contains degenerate triangles');
        }
        for (var q = k * 3; q < k * 3 + 3; q++) {
          for (var j = 0; j < 3; j++) {
            final x = vertices[indices[q] * 3 + j];
            if (x < bounds[b + j] || x > bounds[b + j + 3]) {
              _fail('Triangle lies outside its BVH leaf');
            }
          }
        }
      }
    } else {
      visit(left, b, depth + 1);
      visit(right, b, depth + 1);
    }
  }

  visit(0, -1, 0);
  if (node != n || triangle != t) _fail('Incomplete collision BVH');
  return {
    'localBounds': bounds.sublist(0, 6),
    'vertices': v,
    'triangles': t,
    'textures': 0,
    'estimatedBytes': bytes.length,
    'byteLength': bytes.length,
  };
}

Future<Uint8List> _build((Float32List, Uint32List) geometry) async {
  final (vertices, source) = geometry;
  if (vertices.length % 3 != 0 || source.length % 3 != 0) {
    _fail('Invalid collision geometry');
  }
  final triangles = <int>[];
  for (var t = 0; t < source.length ~/ 3; t++) {
    if (!_degenerate(
      vertices,
      source[t * 3],
      source[t * 3 + 1],
      source[t * 3 + 2],
    )) {
      triangles.add(t);
    }
    if (t % 8192 == 0) await Future<void>.delayed(Duration.zero);
  }
  if (triangles.isEmpty) _fail('No nondegenerate collision triangles');
  final nodes = <List<double>>[], links = <List<int>>[], ordered = <int>[];
  Future<int> build(List<int> ids) async {
    final index = nodes.length;
    nodes.add(List.filled(6, 0));
    links.add([0, 0]);
    final bounds = [
      double.infinity,
      double.infinity,
      double.infinity,
      double.negativeInfinity,
      double.negativeInfinity,
      double.negativeInfinity,
    ];
    for (final id in ids) {
      for (var k = 0; k < 3; k++) {
        for (var j = 0; j < 3; j++) {
          final x = vertices[source[id * 3 + k] * 3 + j];
          bounds[j] = math.min(bounds[j], x);
          bounds[j + 3] = math.max(bounds[j + 3], x);
        }
      }
    }
    nodes[index] = bounds;
    if (ids.length <= 16) {
      links[index] = [-ordered.length - 1, ids.length];
      ordered.addAll(ids);
    } else {
      var axis = 0;
      for (var j = 1; j < 3; j++) {
        if (bounds[j + 3] - bounds[j] > bounds[axis + 3] - bounds[axis]) {
          axis = j;
        }
      }
      double centroid(int id) =>
          (vertices[source[id * 3] * 3 + axis] +
              vertices[source[id * 3 + 1] * 3 + axis] +
              vertices[source[id * 3 + 2] * 3 + axis]) /
          3;
      ids.sort((a, b) {
        final order = centroid(a).compareTo(centroid(b));
        return order == 0 ? a.compareTo(b) : order;
      });
      final middle = ids.length ~/ 2;
      links[index] = [
        await build(ids.sublist(0, middle)),
        await build(ids.sublist(middle)),
      ];
    }
    if (index % 512 == 0) await Future<void>.delayed(Duration.zero);
    return index;
  }

  await build(triangles);
  final size =
      16 + vertices.length * 4 + ordered.length * 12 + nodes.length * 32;
  if (size > _limit) _fail('Generated collision mesh exceeds 64 MiB');
  final bytes = Uint8List(size), data = ByteData.sublistView(bytes);
  var offset = 0;
  for (final n in [
    0x31435046,
    vertices.length ~/ 3,
    ordered.length,
    nodes.length,
  ]) {
    data.setUint32(offset, n, Endian.little);
    offset += 4;
  }
  for (final x in vertices) {
    data.setFloat32(offset, x, Endian.little);
    offset += 4;
  }
  for (final id in ordered) {
    for (var k = 0; k < 3; k++) {
      data.setUint32(offset, source[id * 3 + k], Endian.little);
      offset += 4;
    }
  }
  for (final box in nodes) {
    for (final x in box) {
      data.setFloat32(offset, x, Endian.little);
      offset += 4;
    }
  }
  for (final pair in links) {
    for (final x in pair) {
      data.setInt32(offset, x, Endian.little);
      offset += 4;
    }
  }
  return bytes;
}
