import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import 'scenery_digest.dart';

/// Explicit import limits, not a promise of frame rate on a particular device.
abstract final class SceneryImportLimits {
  static const bytes = 64 * 1024 * 1024;
  static const jsonBytes = 4 * 1024 * 1024;
  static const resources = 128;
  static const nodes = 1024;
  static const elements = 2 * 1000 * 1000;
  static const residentBytes = 128 * 1024 * 1024;
  static const storageBytes = 512 * 1024 * 1024;
}

final class PreparedSceneryModel {
  PreparedSceneryModel._(
    Uint8List data,
    Map<String, dynamic> metadata,
    this.key,
  ) : bytes = data.asUnmodifiableView(),
      metadata = Map.unmodifiable(
        metadata.map(
          (k, v) => MapEntry(k, v is List ? List.unmodifiable(v) : v),
        ),
      );
  final Uint8List bytes;
  final String key;
  final Map<String, dynamic> metadata;
}

typedef SceneryResourceReader = Future<Uint8List?> Function(String relativeUri);
typedef SceneryImportProgress = void Function(String stage);

/// Reads only explicitly resolved local resources. Never follows a network URL.
final class SceneryModelImporter {
  const SceneryModelImporter();

  Future<PreparedSceneryModel> prepare({
    required Uint8List bytes,
    required String name,
    required SceneryResourceReader readResource,
    SceneryImportProgress? progress,
  }) async {
    progress?.call('Reading model');
    final parsed = _readDocument(bytes);
    final doc = parsed.$1;
    final resources = <String, Uint8List>{};
    var total = bytes.length;
    for (final value in [..._list(doc, 'buffers'), ..._list(doc, 'images')]) {
      final uri = _object(value)['uri'];
      if (uri == null) continue;
      if (uri is! String) _fail('Invalid resource URI');
      if (uri.startsWith('data:')) continue;
      final path = sceneryResourcePath(uri);
      if (resources.containsKey(path)) continue;
      if (resources.length >= SceneryImportLimits.resources) {
        _fail('Too many external resources');
      }
      progress?.call('Reading $path');
      final data = await readResource(path);
      if (data == null) _fail('Missing resource: $path');
      total += data.length;
      if (total > SceneryImportLimits.bytes) _fail('Model exceeds 64 MiB');
      resources[path] = data;
    }
    progress?.call('Validating geometry and textures');
    // compute uses an isolate on native targets. Web inputs are bounded and
    // the geometry scanner yields periodically to keep the UI responsive.
    (Uint8List, Map<String, dynamic>, String) result;
    try {
      result = await compute(_validateModel, (bytes, resources));
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException(
        'Invalid or unsupported glTF structure (${error.runtimeType})',
      );
    }
    return PreparedSceneryModel._(result.$1, result.$2, result.$3);
  }
}

String sceneryResourcePath(String raw) {
  String decoded;
  try {
    decoded = Uri.decodeComponent(raw);
  } on FormatException {
    _fail('Invalid resource escaping');
  }
  // Uri normalizes dot segments, so inspect the original decoded path first.
  if (RegExp(r'%(2f|5c|25)', caseSensitive: false).hasMatch(raw) ||
      decoded.split('/').any((p) => p == '.' || p == '..') ||
      decoded.runes.any((c) => c < 32 || c == 127)) {
    _fail('Unsafe resource reference: $raw');
  }
  if (raw.isEmpty || raw.length > 1024 || raw.contains('\\')) {
    _fail('Unsafe resource reference: $raw');
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      raw.startsWith('/')) {
    _fail('Only local relative resources are supported: $raw');
  }
  final parts = uri.pathSegments;
  if (parts.isEmpty ||
      parts.any(
        (p) =>
            p.isEmpty ||
            p == '.' ||
            p == '..' ||
            p.contains('/') ||
            p.contains('\\') ||
            p.contains(':') ||
            p.contains('%') ||
            p.runes.any((c) => c < 32 || c == 127),
      )) {
    _fail('Unsafe resource reference: $raw');
  }
  return parts.join('/');
}

(Map<String, dynamic>, Uint8List?) _readDocument(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > SceneryImportLimits.bytes) {
    _fail('Model is empty or exceeds 64 MiB');
  }
  Uint8List json = bytes;
  Uint8List? bin;
  final data = ByteData.sublistView(bytes);
  if (bytes.length >= 4 && data.getUint32(0, Endian.little) == 0x46546c67) {
    if (bytes.length < 20 ||
        data.getUint32(4, Endian.little) != 2 ||
        data.getUint32(8, Endian.little) != bytes.length) {
      _fail('Invalid GLB 2.0 header or length');
    }
    var offset = 12, chunks = 0;
    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) _fail('Truncated GLB chunk');
      final length = data.getUint32(offset, Endian.little);
      final kind = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (length % 4 != 0 || offset + length > bytes.length) {
        _fail('Invalid GLB chunk length');
      }
      if (chunks == 0 && kind == 0x4e4f534a) {
        json = Uint8List.sublistView(bytes, offset, offset + length);
      } else if (chunks == 1 && kind == 0x004e4942) {
        bin = Uint8List.sublistView(bytes, offset, offset + length);
      } else {
        _fail('Unsupported GLB chunk');
      }
      chunks++;
      offset += length;
    }
  }
  if (json.length > SceneryImportLimits.jsonBytes) {
    _fail('Model JSON exceeds 4 MiB');
  }
  Object? value;
  try {
    value = jsonDecode(utf8.decode(json));
  } on Object {
    _fail('Invalid glTF JSON');
  }
  final pending = <(Object?, int)>[(value, 0)];
  var count = 0;
  while (pending.isNotEmpty) {
    final (v, depth) = pending.removeLast();
    if (depth > 64 || ++count > 200000) {
      _fail('Model JSON exceeds structural limits');
    }
    if (v is Map) {
      for (final child in v.values) {
        pending.add((child, depth + 1));
      }
    } else if (v is List) {
      for (final child in v) {
        pending.add((child, depth + 1));
      }
    } else if (v is num && !v.isFinite) {
      _fail('Non-finite model value');
    }
  }
  final doc = _object(value);
  if (_object(doc['asset'])['version'] != '2.0' ||
      (_object(doc['asset'])['minVersion'] != null &&
          _object(doc['asset'])['minVersion'] != '2.0')) {
    _fail('Only glTF 2.0 is supported');
  }
  return (doc, bin);
}

Future<(Uint8List, Map<String, dynamic>, String)> _validateModel(
  (Uint8List, Map<String, Uint8List>) input,
) async {
  final (doc, glbBin) = _readDocument(input.$1);
  const extensions = {'KHR_materials_unlit', 'KHR_texture_transform'};
  final pending = <Object?>[doc];
  while (pending.isNotEmpty) {
    final v = pending.removeLast();
    if (v is Map) {
      if (v['extensions'] is Map) {
        for (final key in (v['extensions'] as Map).keys) {
          if (!extensions.contains(key)) {
            _fail(
              'Unsupported extension: $key. Export an uncompressed static glTF 2.0 model.',
            );
          }
        }
      }
      pending.addAll(v.values);
    } else if (v is List) {
      pending.addAll(v);
    }
  }
  for (final key in ['extensionsRequired', 'extensionsUsed']) {
    for (final extension in _list(doc, key)) {
      if (!extensions.contains(extension)) {
        _fail('Unsupported extension: $extension');
      }
    }
  }
  if (_list(doc, 'animations').isNotEmpty || _list(doc, 'skins').isNotEmpty) {
    _fail('Animated and skinned scenery is not supported');
  }
  final binary = BytesBuilder(copy: false);
  void align() {
    while (binary.length % 4 != 0) {
      binary.addByte(0);
    }
  }

  Uint8List resource(Object? raw) {
    if (raw is! String) _fail('Missing resource URI');
    if (!raw.startsWith('data:')) {
      final data = input.$2[sceneryResourcePath(raw)];
      if (data == null) _fail('Missing resource: $raw');
      return data;
    }
    final comma = raw.indexOf(',');
    if (comma < 0 ||
        !raw.substring(0, comma).endsWith(';base64') ||
        raw.length - comma > (SceneryImportLimits.bytes * 4 ~/ 3) + 8) {
      _fail('Invalid or oversized data URI');
    }
    try {
      return base64Decode(raw.substring(comma + 1));
    } on Object {
      _fail('Invalid base64 resource');
    }
  }

  final buffers = _list(doc, 'buffers');
  final offsets = <int>[], lengths = <int>[];
  for (final (i, raw) in buffers.indexed) {
    final b = _object(raw);
    final length = _integer(b['byteLength'], 1, SceneryImportLimits.bytes);
    final bytes = b['uri'] == null
        ? (i == 0 && glbBin != null ? glbBin : null)
        : resource(b['uri']);
    if (bytes == null ||
        bytes.length < length ||
        b['uri'] == null && bytes.length > length + 3) {
      _fail('Buffer $i is missing or truncated');
    }
    align();
    offsets.add(binary.length);
    lengths.add(length);
    if (binary.length + length > SceneryImportLimits.bytes) {
      _fail('Model exceeds 64 MiB');
    }
    binary.add(Uint8List.sublistView(bytes, 0, length));
  }
  final views = _list(doc, 'bufferViews');
  if (views.length > 8192) _fail('Too many buffer views');
  for (final raw in views) {
    final v = _object(raw);
    final b = _index(v['buffer'], buffers.length);
    final off = _integer(v['byteOffset'] ?? 0, 0, lengths[b]);
    final len = _integer(v['byteLength'], 1, lengths[b]);
    if (off + len > lengths[b]) _fail('Buffer view exceeds its buffer');
    if (v['byteStride'] != null) {
      final stride = _integer(v['byteStride'], 4, 252);
      if (stride % 4 != 0) _fail('Invalid buffer stride');
    }
    v['buffer'] = 0;
    v['byteOffset'] = offsets[b] + off;
  }
  var textureBytes = 0;
  final imageBytes = <int>[];
  final images = _list(doc, 'images');
  final originalViewCount = views.length;
  // Copy merged buffer data at most once for embedded image validation.
  final embeddedData = images.any((v) => _object(v)['bufferView'] != null)
      ? binary.toBytes()
      : null;
  for (final raw in images) {
    final im = _object(raw);
    Uint8List bytes;
    if (im['uri'] != null) {
      if (im['bufferView'] != null) _fail('Image has both URI and buffer view');
      bytes = resource(im['uri']);
      align();
      if (binary.length + bytes.length > SceneryImportLimits.bytes) {
        _fail('Model exceeds 64 MiB');
      }
      im['bufferView'] = views.length;
      views.add({
        'buffer': 0,
        'byteOffset': binary.length,
        'byteLength': bytes.length,
      });
      binary.add(bytes);
      im.remove('uri');
    } else {
      final v = _object(views[_index(im['bufferView'], originalViewCount)]);
      final all = embeddedData!;
      bytes = Uint8List.sublistView(
        all,
        v['byteOffset'] as int,
        (v['byteOffset'] as int) + (v['byteLength'] as int),
      );
    }
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final decoder = isPng
        ? image.PngDecoder()
        : isJpeg
        ? image.JpegDecoder()
        : null;
    final info = () {
      try {
        return decoder?.startDecode(bytes);
      } on Object {
        _fail('Invalid PNG/JPEG texture');
      }
    }();
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > 4096 ||
        info.height > 4096) {
      _fail('Only valid PNG/JPEG textures up to 4096 × 4096 are supported');
    }
    im['mimeType'] = isPng ? 'image/png' : 'image/jpeg';
    textureBytes += (info.width * info.height * 4 * 4 / 3).ceil();
    imageBytes.add((info.width * info.height * 4 * 4 / 3).ceil());
    if (textureBytes > SceneryImportLimits.residentBytes) {
      _fail('Textures exceed the 128 MiB decoded resource budget');
    }
  }
  doc['bufferViews'] = views;
  doc['buffers'] = [
    {'byteLength': binary.length},
  ];
  final bytes = binary.toBytes();
  final bd = ByteData.sublistView(bytes);
  final accessors = _list(doc, 'accessors');
  if (accessors.length > 8192) _fail('Too many accessors');
  const components = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4};
  const sizes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4};
  final layouts = <(int, int, int, int, int)>[];
  for (final raw in accessors) {
    final a = _object(raw);
    if (a['sparse'] != null) _fail('Sparse accessors are not supported');
    final v = _object(views[_index(a['bufferView'], views.length)]);
    final component = _integer(a['componentType'], 5120, 5126);
    final width = components[component], size = sizes[a['type']];
    if (width == null || size == null) _fail('Unsupported accessor type');
    final count = _integer(a['count'], 1, SceneryImportLimits.elements);
    final offset = _integer(a['byteOffset'] ?? 0, 0, bytes.length);
    final stride = (v['byteStride'] as int?) ?? size * width;
    if (stride < size * width ||
        offset % width != 0 ||
        ((v['byteOffset'] as int) + offset) % width != 0 ||
        offset + (count - 1) * stride + size * width >
            (v['byteLength'] as int)) {
      _fail('Accessor exceeds its buffer view or has invalid alignment');
    }
    layouts.add((
      (v['byteOffset'] as int) + offset,
      stride,
      count,
      component,
      size,
    ));
  }
  final meshes = _list(doc, 'meshes');
  final meshBounds = <List<double>>[], meshTriangles = <int>[];
  var scanned = 0;
  for (final raw in meshes) {
    final mesh = _object(raw);
    if (mesh['weights'] != null) _fail('Morph targets are not supported');
    final bounds = _emptyBounds();
    var triangles = 0;
    final primitives = _list(mesh, 'primitives');
    if (primitives.isEmpty || primitives.length > 1024) {
      _fail('Invalid mesh primitives');
    }
    for (final rawPrimitive in primitives) {
      final p = _object(rawPrimitive);
      if (p['targets'] != null) _fail('Morph targets are not supported');
      final attributes = _object(p['attributes']);
      final positionId = _index(attributes['POSITION'], accessors.length);
      final (offset, stride, count, component, size) = layouts[positionId];
      if (component != 5126 ||
          size != 3 ||
          _object(accessors[positionId])['normalized'] == true) {
        _fail('POSITION must use unnormalized FLOAT VEC3');
      }
      for (final entry in attributes.entries) {
        final layout = layouts[_index(entry.value, layouts.length)];
        if (layout.$3 != count ||
            !RegExp(r'^(POSITION|NORMAL|TANGENT|TEXCOORD_[01]|COLOR_0)$')
                .hasMatch(entry.key)) {
          _fail('Unsupported or inconsistent vertex attribute: ${entry.key}');
        }
        final normalized =
            _object(accessors[entry.value as int])['normalized'] == true;
        final expectedSize = entry.key == 'TANGENT'
            ? 4
            : entry.key.startsWith('TEXCOORD')
            ? 2
            : 3;
        final color = entry.key == 'COLOR_0';
        if (layout.$5 != expectedSize && !(color && layout.$5 == 4) ||
            layout.$4 != 5126 &&
                !((color || entry.key.startsWith('TEXCOORD')) &&
                    {5121, 5123}.contains(layout.$4) &&
                    normalized) ||
            layout.$4 == 5126 && normalized) {
          _fail('Invalid vertex attribute representation: ${entry.key}');
        }
        // Reject NaNs in every floating attribute before passing it to WebGL.
        if (layout.$4 == 5126) {
          for (var i = 0; i < count; i++) {
            for (var j = 0; j < layout.$5; j++) {
              if (!bd
                  .getFloat32(layout.$1 + i * layout.$2 + j * 4, Endian.little)
                  .isFinite) {
                _fail('Non-finite vertex data');
              }
            }
          }
        }
      }
      final local = _emptyBounds();
      for (var i = 0; i < count; i++) {
        final xyz = [
          for (var j = 0; j < 3; j++)
            bd.getFloat32(offset + i * stride + j * 4, Endian.little),
        ];
        if (xyz.any((v) => !v.isFinite || v.abs() > 1000000)) {
          _fail('Invalid or non-local vertex position');
        }
        _include(local, xyz);
        if (++scanned > SceneryImportLimits.elements) {
          _fail('Too many vertices');
        }
        if (scanned % 16384 == 0) await Future<void>.delayed(Duration.zero);
      }
      // Do not trust supplied min/max (wrong values make models disappear).
      final accessor = _object(accessors[positionId]);
      accessor['min'] = local.sublist(0, 3);
      accessor['max'] = local.sublist(3, 6);
      _include(bounds, local.sublist(0, 3));
      _include(bounds, local.sublist(3, 6));
      var indexCount = count;
      if (p['indices'] != null) {
        final l = layouts[_index(p['indices'], layouts.length)];
        if (l.$5 != 1 ||
            !{5121, 5123, 5125}.contains(l.$4) ||
            l.$2 != components[l.$4] ||
            _object(accessors[p['indices'] as int])['normalized'] == true) {
          _fail('Invalid triangle indices');
        }
        indexCount = l.$3;
        for (var i = 0; i < indexCount; i++) {
          final off = l.$1 + i * l.$2;
          final index = l.$4 == 5121
              ? bd.getUint8(off)
              : l.$4 == 5123
              ? bd.getUint16(off, Endian.little)
              : bd.getUint32(off, Endian.little);
          if (index >= count) _fail('Triangle index exceeds vertex count');
        }
      }
      final mode = p['mode'] ?? 4;
      if (!{4, 5, 6}.contains(mode) ||
          indexCount < 3 ||
          mode == 4 && indexCount % 3 != 0) {
        _fail('Only valid triangle primitives are supported');
      }
      triangles += mode == 4 ? indexCount ~/ 3 : indexCount - 2;
      if (p['material'] != null) {
        _index(p['material'], _list(doc, 'materials').length);
      }
    }
    meshBounds.add(bounds);
    meshTriangles.add(triangles);
  }
  final textures = _list(doc, 'textures'), samplers = _list(doc, 'samplers');
  var allocatedTextures = 0;
  for (final t in textures) {
    final texture = _object(t);
    _index(texture['source'], images.length);
    allocatedTextures += imageBytes[texture['source'] as int];
    if (texture['sampler'] != null) _index(texture['sampler'], samplers.length);
  }
  textureBytes = math.max(textureBytes, allocatedTextures);
  for (final raw in samplers) {
    final s = _object(raw);
    if (s['magFilter'] != null && !{9728, 9729}.contains(s['magFilter']) ||
        s['minFilter'] != null &&
            !{9728, 9729, 9984, 9985, 9986, 9987}.contains(s['minFilter']) ||
        !{33071, 33648, 10497}.contains(s['wrapS'] ?? 10497) ||
        !{33071, 33648, 10497}.contains(s['wrapT'] ?? 10497)) {
      _fail('Invalid texture sampler');
    }
  }
  final materialCoordinates = <Set<int>>[];
  for (final raw in _list(doc, 'materials')) {
    final material = _object(raw);
    if (!{
      'OPAQUE',
      'MASK',
      'BLEND',
    }.contains(material['alphaMode'] ?? 'OPAQUE')) {
      _fail('Invalid material alpha mode');
    }
    final coordinates = <int>{};
    void textureInfo(Object? v) {
      if (v == null) return;
      final info = _object(v);
      _index(info['index'], textures.length);
      final transform =
          (info['extensions'] as Map?)?['KHR_texture_transform'] as Map?;
      coordinates.add(
        _integer(transform?['texCoord'] ?? info['texCoord'] ?? 0, 0, 1),
      );
      if (transform != null) {
        for (final key in ['offset', 'scale']) {
          final values = transform[key];
          if (values != null &&
              (values is! List ||
                  values.length != 2 ||
                  values.any((v) => v is! num))) {
            _fail('Invalid texture transform');
          }
        }
        if (transform['rotation'] != null && transform['rotation'] is! num) {
          _fail('Invalid texture rotation');
        }
      }
    }

    final pbr = material['pbrMetallicRoughness'] == null
        ? <String, dynamic>{}
        : _object(material['pbrMetallicRoughness']);
    textureInfo(pbr['baseColorTexture']);
    textureInfo(pbr['metallicRoughnessTexture']);
    textureInfo(material['normalTexture']);
    textureInfo(material['occlusionTexture']);
    textureInfo(material['emissiveTexture']);
    void unitFactor(Map<String, dynamic> object, String key, {int? length}) {
      final value = object[key];
      if (value == null) return;
      final values = length == null ? [value] : value;
      if (values is! List ||
          length != null && values.length != length ||
          values.any((v) => v is! num || v < 0 || v > 1)) {
        _fail('Invalid material $key');
      }
    }

    unitFactor(pbr, 'baseColorFactor', length: 4);
    unitFactor(pbr, 'metallicFactor');
    unitFactor(pbr, 'roughnessFactor');
    unitFactor(material, 'emissiveFactor', length: 3);
    if (material['doubleSided'] != null && material['doubleSided'] is! bool ||
        material['alphaCutoff'] != null &&
            (material['alphaCutoff'] is! num ||
                (material['alphaCutoff'] as num) < 0)) {
      _fail('Invalid material alpha/sidedness');
    }
    materialCoordinates.add(coordinates);
  }
  for (final mesh in meshes) {
    for (final primitive in _list(_object(mesh), 'primitives')) {
      final p = _object(primitive);
      if (p['material'] != null) {
        for (final coordinate in materialCoordinates[p['material'] as int]) {
          if (!_object(p['attributes']).containsKey('TEXCOORD_$coordinate')) {
            _fail('Material texture is missing TEXCOORD_$coordinate');
          }
        }
      }
    }
  }
  final nodes = _list(doc, 'nodes');
  if (nodes.length > SceneryImportLimits.nodes) _fail('Too many model nodes');
  final parents = List<int>.filled(nodes.length, 0);
  for (final n in nodes) {
    for (final child in _list(_object(n), 'children')) {
      if (++parents[_index(child, nodes.length)] > 1) {
        _fail('Node has multiple parents');
      }
    }
  }
  final world = _emptyBounds();
  var drawnTriangles = 0;
  final visited = <int>{};
  void walk(int id, List<double> parent, Set<int> path, {bool render = true}) {
    if (path.length > 64 || !path.add(id)) {
      _fail('Cyclic or excessively deep node hierarchy');
    }
    visited.add(id);
    final n = _object(nodes[id]);
    if (n['skin'] != null || n['weights'] != null) {
      _fail('Skins/morph targets are not supported');
    }
    final transform = multiplySceneryMatrices(parent, _nodeMatrix(n));
    if (n['mesh'] != null) {
      final mesh = _index(n['mesh'], meshes.length),
          b = meshBounds[_index(n['mesh'], meshes.length)];
      if (render) {
        for (var mask = 0; mask < 8; mask++) {
          final xyz = transformSceneryPoint(transform, [
            for (var j = 0; j < 3; j++) b[j + ((mask & (1 << j)) == 0 ? 0 : 3)],
          ]);
          // Cesium's default Y-up/Z-forward glTF -> local ENU axis correction.
          _include(world, [xyz[2], xyz[0], xyz[1]]);
        }
        drawnTriangles += meshTriangles[mesh];
        if (drawnTriangles > SceneryImportLimits.elements) {
          _fail('Too many rendered triangles');
        }
      }
    }
    for (final child in _list(n, 'children')) {
      walk(_index(child, nodes.length), transform, path, render: render);
    }
    path.remove(id);
  }

  final scenes = _list(doc, 'scenes');
  if (scenes.isEmpty) _fail('A default model scene is required');
  for (final raw in scenes) {
    final ids = <int>{};
    for (final root in _list(_object(raw), 'nodes')) {
      final id = _index(root, nodes.length);
      if (!ids.add(id) || parents[id] != 0) _fail('Invalid scene root');
    }
  }
  final rootIds = _list(
    _object(scenes[_index(doc['scene'] ?? 0, scenes.length)]),
    'nodes',
  );
  final roots = <int>{};
  for (final root in rootIds) {
    final id = _index(root, nodes.length);
    if (!roots.add(id) || parents[id] != 0) _fail('Invalid scene root');
    walk(id, sceneryIdentityMatrix(), <int>{});
  }
  // Validate unused nodes too; never leave a hidden cyclic graph in the GLB.
  for (var id = 0; id < nodes.length; id++) {
    if (!visited.contains(id)) {
      walk(id, sceneryIdentityMatrix(), <int>{}, render: false);
    }
  }
  if (drawnTriangles == 0 || world.any((v) => !v.isFinite)) {
    _fail('The model contains no renderable triangles');
  }
  final estimated = bytes.length + textureBytes + scanned * 32;
  if (estimated > SceneryImportLimits.residentBytes) {
    _fail('Model exceeds the 128 MiB decoded resource budget');
  }
  final output = _writeGlb(doc, bytes);
  return (
    output,
    {
      'localBounds': world,
      'triangles': drawnTriangles,
      'vertices': scanned,
      'textures': images.length,
      'estimatedBytes': estimated,
      'byteLength': output.length,
    },
    '${await sceneryDigest(output)}.glb',
  );
}

List<double> sceneryIdentityMatrix() => [
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
];
List<double> multiplySceneryMatrices(List<double> a, List<double> b) => [
  for (var c = 0; c < 4; c++)
    for (var r = 0; r < 4; r++)
      [for (var k = 0; k < 4; k++) a[k * 4 + r] * b[c * 4 + k]]
          .reduce((a, b) => a + b),
];
List<double> transformSceneryPoint(List<double> m, List<double> v) => [
  for (var r = 0; r < 3; r++)
    m[r] * v[0] + m[4 + r] * v[1] + m[8 + r] * v[2] + m[12 + r],
];
List<double> _nodeMatrix(Map<String, dynamic> n) {
  List<double> vector(String key, List<double> fallback) {
    if (n[key] == null) return fallback;
    final v = n[key];
    if (v is! List ||
        v.length != fallback.length ||
        v.any((x) => x is! num || !x.isFinite)) {
      _fail('Invalid node $key');
    }
    return v.map((x) => (x as num).toDouble()).toList();
  }

  if (n['matrix'] != null) {
    if (['translation', 'rotation', 'scale'].any(n.containsKey)) {
      _fail('Node mixes matrix and TRS');
    }
    final m = vector('matrix', sceneryIdentityMatrix());
    if (m[3] != 0 || m[7] != 0 || m[11] != 0 || m[15] != 1) {
      _fail('Non-affine node matrix');
    }
    return m;
  }
  final t = vector('translation', [0, 0, 0]),
      q = vector('rotation', [0, 0, 0, 1]),
      s = vector('scale', [1, 1, 1]);
  final x = q[0], y = q[1], z = q[2], w = q[3];
  if ((x * x + y * y + z * z + w * w - 1).abs() > 1e-4 ||
      s.any((v) => v == 0)) {
    _fail('Invalid quaternion or scale');
  }
  return [
    (1 - 2 * (y * y + z * z)) * s[0],
    2 * (x * y + z * w) * s[0],
    2 * (x * z - y * w) * s[0],
    0,
    2 * (x * y - z * w) * s[1],
    (1 - 2 * (x * x + z * z)) * s[1],
    2 * (y * z + x * w) * s[1],
    0,
    2 * (x * z + y * w) * s[2],
    2 * (y * z - x * w) * s[2],
    (1 - 2 * (x * x + y * y)) * s[2],
    0,
    t[0],
    t[1],
    t[2],
    1,
  ];
}

Uint8List _writeGlb(Map<String, dynamic> doc, Uint8List bin) {
  final encoded = utf8.encode(jsonEncode(doc));
  final j = (encoded.length + 3) & ~3,
      b = (bin.length + 3) & ~3,
      total = 28 + j + b;
  if (total > SceneryImportLimits.bytes) {
    _fail('Self-contained model exceeds 64 MiB');
  }
  final out = Uint8List(total), d = ByteData.sublistView(out);
  d.setUint32(0, 0x46546c67, Endian.little);
  d.setUint32(4, 2, Endian.little);
  d.setUint32(8, total, Endian.little);
  d.setUint32(12, j, Endian.little);
  d.setUint32(16, 0x4e4f534a, Endian.little);
  out.fillRange(20, 20 + j, 32);
  out.setRange(20, 20 + encoded.length, encoded);
  d.setUint32(20 + j, b, Endian.little);
  d.setUint32(24 + j, 0x004e4942, Endian.little);
  out.setRange(28 + j, 28 + j + bin.length, bin);
  return out;
}

List<double> _emptyBounds() => [
  double.infinity,
  double.infinity,
  double.infinity,
  double.negativeInfinity,
  double.negativeInfinity,
  double.negativeInfinity,
];
void _include(List<double> b, List<double> p) {
  for (var j = 0; j < 3; j++) {
    b[j] = math.min(b[j], p[j]);
    b[j + 3] = math.max(b[j + 3], p[j]);
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) _fail('Expected glTF object');
  return value;
}

List<dynamic> _list(Map<String, dynamic> doc, String key) {
  final v = doc[key];
  if (v == null) return <dynamic>[];
  if (v is! List) _fail('Invalid glTF $key');
  return v;
}

int _integer(Object? v, int min, int max) {
  if (v is! int || v < min || v > max) {
    _fail('Invalid glTF integer or resource range');
  }
  return v;
}

int _index(Object? v, int length) => _integer(v, 0, length - 1);
Never _fail(String message) => throw FormatException(message);
