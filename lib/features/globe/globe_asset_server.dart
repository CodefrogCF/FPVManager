import 'dart:io';

import 'package:flutter/services.dart';

/// Serves only manifest-listed Flutter Web assets on IPv4 loopback.
/// HTTP keeps Cesium workers/Wasm on a real origin without file-URL exceptions.
class GlobeAssetServer {
  GlobeAssetServer._(this._server, this._paths, this._load);

  final HttpServer _server;
  final Set<String> _paths;
  final Future<ByteData> Function(String) _load;

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<GlobeAssetServer> start({
    Set<String>? paths,
    Future<ByteData> Function(String)? load,
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
      final parts = request.uri.pathSegments;
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
      final data = await _load(path);
      final extension = path.split('.').last.toLowerCase();
      request.response.headers.set('Content-Type', switch (extension) {
        'html' => 'text/html; charset=utf-8',
        'js' || 'mjs' => 'application/javascript; charset=utf-8',
        'css' => 'text/css; charset=utf-8',
        'json' => 'application/json',
        'wasm' => 'application/wasm',
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

  Future<void> close() => _server.close(force: true);
}
