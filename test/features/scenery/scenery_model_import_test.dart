import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_model_import.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';
import 'package:fpvmanager/features/scenery/scenery_asset_provider.dart';

import '../../support/scenery_model_fixture.dart';

void main() {
  test('browser fixture imports with its PNG, alpha material and local bounds intact', () async {
    final model = await const SceneryModelImporter().prepare(
      bytes: await File('test/fixtures/scenery/imported_triangle.glb')
          .readAsBytes(),
      name: 'imported_triangle.glb',
      readResource: (_) async => throw StateError('Self-contained fixture'),
    );
    expect(model.metadata['localBounds'], [3, -4, 2, 3, 6, 12]);
    expect(model.metadata['textures'], 1);
    final doc = readTestGlb(model.bytes).$1;
    expect(doc['materials'][0]['alphaMode'], 'BLEND');
    expect(doc['images'][0]['uri'], isNull);
  });
  test(
    'external glTF becomes a self-contained GLB and repairs culling bounds',
    () async {
      final model = await prepareTriangle();
      final (doc, bin) = readTestGlb(model.bytes);
      expect((doc['buffers'] as List).single, {'byteLength': 36});
      expect(bin, triangleBytes());
      expect(doc['accessors'][0]['max'], [2, 3, 0]);
      expect(model.metadata['localBounds'], [0, 0, 0, 0, 2, 3]);
      expect(model.metadata['triangles'], 1);
      expect(() => model.bytes[0] = 1, throwsUnsupportedError);
      final again = await const SceneryModelImporter().prepare(
        bytes: model.bytes,
        name: 'saved.glb',
        readResource: (_) =>
            throw StateError('Must not access external resources'),
      );
      expect(again.key, model.key);
    },
  );
  test('nested and encoded local resource names resolve once', () async {
    final doc = triangleGltf();
    doc['buffers'][0]['uri'] = 'mesh%20data/triangle.bin';
    final model = await prepareTriangle(
      doc: doc,
      files: {'mesh data/triangle.bin': triangleBytes()},
    );
    expect(model.metadata['triangles'], 1);
  });
  for (final uri in [
    '../mesh.bin',
    '/mesh.bin',
    'file:///mesh.bin',
    'https://example.invalid/mesh.bin',
    '//example/mesh.bin',
    'textures/%2e%2e/mesh.bin',
    'x%2f..%2fmesh.bin',
    'x\\mesh.bin',
    'mesh.bin?x=1',
    'mesh.bin#x',
    'x/%252e%252e/y.bin',
  ]) {
    test('reject unsafe resource $uri before resolving', () async {
      final doc = triangleGltf();
      doc['buffers'][0]['uri'] = uri;
      var reads = 0;
      await expectLater(
        const SceneryModelImporter().prepare(
          bytes: Uint8List.fromList(utf8.encode(jsonEncode(doc))),
          name: 'bad.gltf',
          readResource: (_) async {
            reads++;
            return triangleBytes();
          },
        ),
        throwsFormatException,
      );
      expect(reads, 0);
    });
  }
  test('missing resources fail explicitly', () async {
    await expectLater(
      prepareTriangle(files: {}),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Missing resource'),
        ),
      ),
    );
  });
  test('base64 buffers, embedded PNG and alpha materials survive canonicalization', () async {
    final doc = triangleGltf();
    doc['buffers'][0]['uri'] =
        'data:application/octet-stream;base64,${base64Encode(triangleBytes())}';
    doc['images'] = [
      {
        'uri': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a8O8AAAAASUVORK5CYII=',
      },
    ];
    doc['textures'] = [
      {'source': 0},
    ];
    doc['materials'] = [
      {
        'alphaMode': 'BLEND',
        'doubleSided': true,
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
          'baseColorFactor': [1, 1, 1, .5],
        },
      },
    ];
    doc['meshes'][0]['primitives'][0]['material'] = 0;
    doc['buffers'].add({
      'uri':
          'data:application/octet-stream;base64,${base64Encode(Uint8List(24))}',
      'byteLength': 24,
    });
    doc['bufferViews'].add({'buffer': 1, 'byteLength': 24});
    doc['accessors'].add({
      'bufferView': 1,
      'componentType': 5126,
      'count': 3,
      'type': 'VEC2',
    });
    doc['meshes'][0]['primitives'][0]['attributes']['TEXCOORD_0'] = 1;
    final model = await prepareTriangle(doc: doc, files: {});
    final result = readTestGlb(model.bytes).$1;
    expect(result['images'][0]['uri'], isNull);
    expect(result['images'][0]['mimeType'], 'image/png');
    expect(result['materials'], doc['materials']);
    expect(model.metadata['textures'], 1);
  });
  test(
    'node transforms and Cesium axis correction contribute to model bounds',
    () async {
      final doc = triangleGltf();
      doc['nodes'][0]['translation'] = [10, 20, 30];
      doc['nodes'][0]['scale'] = [2, 2, 2];
      expect((await prepareTriangle(doc: doc)).metadata['localBounds'], [
        30,
        10,
        20,
        30,
        14,
        26,
      ]);
    },
  );
  for (final extension in [
    'KHR_draco_mesh_compression',
    'EXT_meshopt_compression',
    'KHR_texture_basisu',
  ]) {
    test(
      'compressed $extension is rejected with an actionable error',
      () async {
        final doc = triangleGltf();
        doc['extensionsRequired'] = [extension];
        await expectLater(
          prepareTriangle(doc: doc),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(extension),
            ),
          ),
        );
      },
    );
  }
  test('bad lengths, non-finite vertices, absent scene, cycles and sparse data fail', () async {
    final changes = <void Function(Map<String, dynamic>)>[
      (d) => d['buffers'][0]['byteLength'] = 100,
      (d) => d['accessors'][0]['count'] = 4,
      (d) => d['accessors'][0]['sparse'] = {},
      (d) => d['nodes'][0]['children'] = [0],
      (d) => d['scenes'] = [],
      (d) => d['scenes'][0]['nodes'] = [],
      (d) => d['nodes'][0]['matrix'] = [
        1,
        0,
        0,
        1,
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
      ],
      (d) => d['animations'] = [{}],
      (d) => d['accessors'][0]['count'] = SceneryImportLimits.elements + 1,
    ];
    for (final change in changes) {
      final doc = triangleGltf();
      change(doc);
      await expectLater(prepareTriangle(doc: doc), throwsFormatException);
    }
    final bad = triangleBytes();
    ByteData.sublistView(bad).setFloat32(0, double.nan, Endian.little);
    await expectLater(
      prepareTriangle(files: {'mesh.bin': bad}),
      throwsFormatException,
    );
    final glb = Uint8List.fromList((await prepareTriangle()).bytes);
    glb[8] = 0;
    await expectLater(
      const SceneryModelImporter().prepare(
        bytes: glb,
        name: 'bad.glb',
        readResource: (_) async => null,
      ),
      throwsFormatException,
    );
  });
  test(
    'invalid triangle indices and oversized texture dimensions are rejected',
    () async {
      final doc = triangleGltf();
      doc['buffers'].add({'uri': 'indices.bin', 'byteLength': 3});
      doc['bufferViews'].add({'buffer': 1, 'byteLength': 3});
      doc['accessors'].add({
        'bufferView': 1,
        'componentType': 5121,
        'count': 3,
        'type': 'SCALAR',
      });
      doc['meshes'][0]['primitives'][0]['indices'] = 1;
      await expectLater(
        prepareTriangle(
          doc: doc,
          files: {
            'mesh.bin': triangleBytes(),
            'indices.bin': Uint8List.fromList([0, 1, 3]),
          },
        ),
        throwsFormatException,
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a8O8AAAAASUVORK5CYII=',
      );
      ByteData.sublistView(png).setUint32(16, 8192, Endian.big);
      final imageDoc = triangleGltf();
      imageDoc['images'] = [
        {'uri': 'large.png'},
      ];
      await expectLater(
        prepareTriangle(
          doc: imageDoc,
          files: {'mesh.bin': triangleBytes(), 'large.png': png},
        ),
        throwsFormatException,
      );
    },
  );
  test('managed manifests persist resource metadata and recalculate geographic bounds', () async {
    final model = await prepareTriangle(),
        manifest = importedTriangle(await prepareTriangle());
    final doc = manifest.toJson();
    expect(doc['extensions']['modelBounds']['reference'], 'WGS84_ECEF');
    expect(doc['bounds']['west'], lessThan(13.8));
    expect(doc['bounds']['east'], greaterThan(13.8));
    doc['anchor']['longitude'] = 179.99999;
    doc['scale'] = 100;
    final moved = SceneryManifest.fromJson(doc).toJson();
    expect(moved['bounds']['west'], greaterThan(moved['bounds']['east']));
    doc['anchor']['reference'] = 'TERRAIN_RELATIVE';
    expect(
      SceneryManifest.fromJson(doc).toJson()['extensions']['modelBounds'],
      {'reference': 'TERRAIN_RELATIVE', 'pendingTerrain': true},
    );
    final catalog = SceneryAssetProviders().compile([manifest]);
    expect(
      catalog['sceneries'][0]['assets'][0]['path'],
      'managed/${model.key}',
    );
    expect(catalog['sceneries'][0]['sourceUrl'], isNull);
  });
}
