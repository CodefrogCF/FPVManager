import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_asset_server.dart';

void main() {
  test(
    'serves only allowed local assets with worker/Wasm MIME types',
    () async {
      final loaded = <String>[];
      final server = await GlobeAssetServer.start(
        paths: {
          'web/globe.html',
          'web/cesium/Workers/test.js',
          'web/cesium/ThirdParty/test.wasm',
          'web/models/obstacles/test.glb',
        },
        load: (path) async {
          loaded.add(path);
          return ByteData.sublistView(Uint8List.fromList(utf8.encode('asset')));
        },
      );
      final client = HttpClient();
      try {
        for (final asset in {
          'globe.html': 'text/html',
          'cesium/Workers/test.js': 'application/javascript',
          'cesium/ThirdParty/test.wasm': 'application/wasm',
          'models/obstacles/test.glb': 'model/gltf-binary',
        }.entries) {
          final response = await (await client.getUrl(
            server.origin.resolve('/${asset.key}'),
          )).close();
          expect(response.statusCode, 200);
          expect(response.headers.contentType?.mimeType, asset.value);
          expect(await utf8.decoder.bind(response).join(), 'asset');
        }
        final head = await (await client.openUrl(
          'HEAD',
          server.origin.resolve('/globe.html'),
        )).close();
        expect(head.statusCode, 200);
        expect(
          await head.fold<int>(0, (size, bytes) => size + bytes.length),
          0,
        );
        final before = loaded.length;
        for (final path in [
          '/pubspec.yaml',
          '/..%2fpubspec.yaml',
          '/cesium/missing.js',
        ]) {
          final response = await (await client.getUrl(
            server.origin.resolve(path),
          )).close();
          expect(response.statusCode, 404);
          await response.drain<void>();
        }
        expect(loaded.length, before);
        final post = await (await client.postUrl(
          server.origin.resolve('/globe.html'),
        )).close();
        expect(post.statusCode, 405);
        await post.drain<void>();
        final request = await client.getUrl(
          server.origin.resolve('/globe.html'),
        );
        request.headers.host = 'other.example';
        final invalidHost = await request.close();
        expect(invalidHost.statusCode, 404);
        await invalidHost.drain<void>();
      } finally {
        client.close(force: true);
        await server.close();
      }
    },
  );
}
