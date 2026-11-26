import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'scenery_model_import.dart';
import 'scenery_storage.dart';

SceneryStorage createSceneryStorage() => WebSceneryStorage();

final class WebSceneryStorage implements SceneryStorage {
  String get root => Uri.base.resolve('scenery-local/v1/').toString();
  Future<web.Cache> get _cache async {
    if (!web.window.isSecureContext) {
      throw StateError('Local scenery import requires HTTPS or localhost');
    }
    return web.window.caches.open('fpvmanager-scenery-v1:$root').toDart;
  }

  @override
  Map<String, String> get rendererOptions => {
    'backend': 'cache',
    'cacheRoot': root,
  };
  void _key(String key) {
    if (!isManagedSceneryKey(key)) {
      throw const FormatException('Invalid scenery key');
    }
  }

  @override
  Future<Uint8List?> read(String key) async {
    _key(key);
    final response = await (await _cache).match('$root$key'.toJS).toDart;
    if (response == null) return null;
    final size = int.tryParse(response.headers.get('x-fpv-size') ?? '');
    if (size == null || size < 1 || size > SceneryImportLimits.bytes) {
      throw const FormatException('Invalid cached scenery length');
    }
    final bytes = (await response.arrayBuffer().toDart).toDart.asUint8List();
    if (bytes.length != size) {
      throw const FormatException('Truncated cached scenery');
    }
    await verifyManagedScenery(key, bytes);
    return bytes;
  }

  @override
  Future<bool> put(String key, Uint8List bytes) async {
    _key(key);
    if (bytes.length > SceneryImportLimits.bytes) {
      throw const FormatException('Scenery file exceeds 64 MiB');
    }
    // Read-only Dart views cannot be cast directly to JavaScript typed arrays.
    // Snapshot before asynchronous verification and CacheStorage.put.
    final data = Uint8List.fromList(bytes);
    await verifyManagedScenery(key, data);
    try {
      if (await read(key) != null) return false;
    } on FormatException {
      /* Repair corrupt cache. */
    }
    final cache = await _cache;
    var used = 0;
    for (final request in (await cache.keys().toDart).toDart) {
      if (request.url == '$root$key') continue;
      final response = await cache.match(request).toDart;
      used +=
          int.tryParse(response?.headers.get('x-fpv-size') ?? '') ??
          SceneryImportLimits.bytes;
    }
    if (used + bytes.length > SceneryImportLimits.storageBytes) {
      throw const FormatException(
        'Local scenery storage limit (512 MiB) reached',
      );
    }
    final headers = web.Headers();
    headers.set(
      'content-type',
      key.endsWith('.fpc') ? 'application/octet-stream' : 'model/gltf-binary',
    );
    headers.set('x-fpv-size', '${bytes.length}');
    await cache
        .put(
          '$root$key'.toJS,
          web.Response(data.toJS, web.ResponseInit(headers: headers)),
        )
        .toDart;
    return true;
  }

  @override
  Future<void> remove(String key) async {
    _key(key);
    await (await _cache).delete('$root$key'.toJS).toDart;
  }
}

Future<Uint8List?> readAdjacentSceneryResource(
  String modelPath,
  String relative,
) async => null;
