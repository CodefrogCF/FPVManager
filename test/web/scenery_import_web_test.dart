@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:fpvmanager/features/scenery/scenery_storage_web.dart';

import '../support/scenery_model_fixture.dart';

void main() {
  test('Web importer and CacheStorage retain verified self-contained models across store reopen', () async {
    final model = await prepareTriangle();
    final store = WebSceneryStorage();
    try {
      expect(await store.put(model.key, model.bytes), true);
      expect(await store.put(model.key, model.bytes), false);
      final reopened = WebSceneryStorage();
      expect(await reopened.read(model.key), model.bytes);
      expect(store.rendererOptions['backend'], 'cache');
      expect(
        store.rendererOptions['cacheRoot'],
        endsWith('/scenery-local/v1/'),
      );
    } finally {
      await store.remove(model.key);
    }
    expect(await store.read(model.key), isNull);
  });
  test(
    'Web corruption is explicit and reimport repairs the stored file',
    () async {
      final model = await prepareTriangle();
      final store = WebSceneryStorage();
      final root = store.rendererOptions['cacheRoot']!,
          cache = await web.window.caches
              .open('fpvmanager-scenery-v1:$root')
              .toDart;
      final headers = web.Headers();
      headers.set('x-fpv-size', '3');
      try {
        await cache
            .put(
              '$root${model.key}'.toJS,
              web.Response(
                Uint8List.fromList([1, 2, 3]).toJS,
                web.ResponseInit(headers: headers),
              ),
            )
            .toDart;
        await expectLater(store.read(model.key), throwsFormatException);
        expect(await store.put(model.key, model.bytes), true);
        expect(await store.read(model.key), model.bytes);
        await expectLater(
          store.put('../bad.glb', model.bytes),
          throwsFormatException,
        );
      } finally {
        await store.remove(model.key);
      }
    },
  );
}
