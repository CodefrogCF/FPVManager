import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_asset_server.dart';

void main() {
  test('managed asset route restricts key, method and origin', () async {
    var reads = 0;
    final key = '${'a' * 64}.glb';
    final server = await GlobeAssetServer.start(
      paths: {},
      managedScenery: (value) async {
        reads++;
        expect(value, key);
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final client = HttpClient();
    try {
      final uri = server.origin.resolve('/assets/scenery/managed/$key');
      final valid = await (await client.getUrl(uri)).close();
      expect(valid.statusCode, 200);
      expect(valid.headers.contentType?.mimeType, 'model/gltf-binary');
      await valid.drain<void>();
      for (final path in [
        '/assets/scenery/managed/not-a-hash.glb',
        '/assets/scenery/managed/../$key',
        '/assets/scenery/managed/$key?x=1',
      ]) {
        final response = await (await client.getUrl(
          server.origin.resolve(path),
        )).close();
        expect(response.statusCode, 404);
        await response.drain<void>();
      }
      final foreign = await client.getUrl(uri);
      foreign.headers.set('Origin', 'https://other.invalid');
      final r = await foreign.close();
      expect(r.statusCode, 403);
      await r.drain<void>();
      expect(reads, 1);
    } finally {
      client.close(force: true);
      await server.close();
    }
  });
  test('managed reads coalesce, cap concurrency and recover after missing or failed files', () async {
    final gates = <String, Completer<Uint8List?>>{};
    final started = Completer<void>();
    var reads = 0;
    final server = await GlobeAssetServer.start(
      paths: {},
      managedScenery: (key) {
        reads++;
        final job = gates.putIfAbsent(key, () => Completer<Uint8List?>());
        if (gates.length == 2 && !started.isCompleted) started.complete();
        return job.future;
      },
    );
    final client = HttpClient();
    Future<HttpClientResponse> get(String letter) async => (await client.getUrl(
      server.origin.resolve('/assets/scenery/managed/${letter * 64}.glb'),
    )).close();
    try {
      final a = get('a'), duplicate = get('a'), b = get('b');
      await started.future;
      final overflow = await get('c');
      expect(overflow.statusCode, 503);
      await overflow.drain<void>();
      expect(reads, 2);
      gates['${'a' * 64}.glb']!.complete(Uint8List.fromList([1]));
      gates['${'b' * 64}.glb']!.complete(null);
      for (final response in await Future.wait([a, duplicate, b])) {
        await response.drain<void>();
      }
      gates.clear();
      final retry = get('c');
      while (!gates.containsKey('${'c' * 64}.glb')) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      gates.values.single.completeError(const FormatException('Corrupted'));
      final failed = await retry;
      expect(failed.statusCode, 500);
      await failed.drain<void>();
      gates.clear();
      final recovered = get('c');
      while (gates.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      gates.values.single.complete(Uint8List.fromList([2]));
      final result = await recovered;
      expect(result.statusCode, 200);
      await result.drain<void>();
    } finally {
      client.close(force: true);
      await server.close();
    }
  });
}
