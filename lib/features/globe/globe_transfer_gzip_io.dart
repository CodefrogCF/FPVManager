import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Compress off the Flutter UI isolate. Only used when the renderer has
/// explicitly advertised DecompressionStream('gzip') support.
Future<({String base64, int originalBytes})?> compress(String source) =>
    Isolate.run(() {
      final bytes = utf8.encode(source);
      return (
        base64: base64Encode(gzip.encode(bytes)),
        originalBytes: bytes.length,
      );
    });
