import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../offline/offline_map_store_native.dart';

/// Serves only manifest-listed Flutter Web assets on IPv4 loopback.
/// HTTP keeps Cesium workers/Wasm on a real origin without file-URL exceptions.
class GlobeAssetServer {
  GlobeAssetServer._(this._server, this._paths, this._load, this._offlineCache);

  final HttpServer _server;
  final Set<String> _paths;
  final Future<ByteData> Function(String) _load;
  final NativeOfflineMapStore? _offlineCache;

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<GlobeAssetServer> start({
    Set<String>? paths,
    Future<ByteData> Function(String)? load,
    NativeOfflineMapStore? offlineCache,
  }) async {
    final manifest =
        paths ??
        (await AssetManifest.loadFromAssetBundle(rootBundle))
            .listAssets()
            .where((path) => path.startsWith('web/'))
            .toSet();
    final socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = GlobeAssetServer._(
      socket,
      manifest,
      load ?? rootBundle.load,
      offlineCache,
    );
    socket.listen(server._serve);
    return server;
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.headers.set('Cache-Control', 'no-store');
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      // Never expose local files, alternate authorities, traversal or arbitrary assets.
      final requestOrigin = request.headers.value('Origin');
      if ((requestOrigin != null && requestOrigin != origin.toString()) ||
          request.headers.value('Sec-Fetch-Site') == 'cross-site') {
        request.response.statusCode = HttpStatus.forbidden;
        return;
      }
      final parts = request.uri.pathSegments;
      if (_offlineCache != null &&
          request.headers.host == '127.0.0.1' &&
          request.headers.port == _server.port &&
          !request.uri.hasAuthority &&
          parts.length >= 4 &&
          parts[0] == 'offline' &&
          parts[1] == 'maps') {
        try {
          final tile = await _offlineCache.load(
            parts.skip(2).join('/'),
            cacheOnly: request.uri.queryParameters['cacheOnly'] == '1',
          );
          request.response.headers.set('Content-Type', tile.mime);
          request.response.headers.set(
            'X-FPV-Fetched-At',
            tile.fetchedAt.toIso8601String(),
          );
          request.response.contentLength = tile.bytes.length;
          if (request.method == 'GET') request.response.add(tile.bytes);
        } catch (_) {
          request.response.statusCode = HttpStatus.notFound;
        }
        return;
      }
      final path = 'web/${parts.join('/')}';
      if (request.headers.host != '127.0.0.1' ||
          request.headers.port != _server.port ||
          request.uri.hasAuthority ||
          parts.any(
            (part) =>
                part == '..' ||
                part == '.' ||
                part.contains('\\') ||
                part.contains('/'),
          ) ||
          !_paths.contains(path)) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }
      var data = await _load(path);
      if (path == 'web/globe.html' && _offlineCache != null) {
        final source = utf8
            .decode(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            )
            .replaceFirst(
              '<script src="offline_map_client.js">',
              '<script>window.FPVNativeOfflineCache=true;</script><script src="offline_map_client.js">',
            );
        data = ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
      }
      final extension = path.split('.').last.toLowerCase();
      if (extension == 'glb') {
        request.response.headers.set(
          'Cache-Control',
          'private, max-age=86400, immutable',
        );
      }
      request.response.headers.set('Content-Type', switch (extension) {
        'html' => 'text/html; charset=utf-8',
        'js' || 'mjs' => 'application/javascript; charset=utf-8',
        'css' => 'text/css; charset=utf-8',
        'json' => 'application/json',
        'wasm' => 'application/wasm',
        'glb' => 'model/gltf-binary',
        'svg' => 'image/svg+xml',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        _ => 'application/octet-stream',
      });
      request.response.contentLength = data.lengthInBytes;
      if (request.method == 'GET') {
        request.response.add(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {
        // The browser may have cancelled this request during reload/disposal.
      }
    } finally {
      try {
        await request.response.close();
      } catch (_) {
        // Closing an interrupted local asset connection is harmless.
      }
    }
  }

  Future<void> close() async {
    await _server.close(force: true);
    await _offlineCache?.close();
  }
}
