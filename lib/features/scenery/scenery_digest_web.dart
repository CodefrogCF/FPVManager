import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> sceneryDigest(Uint8List bytes) async {
  if (!web.window.isSecureContext) {
    throw StateError('Local scenery import requires HTTPS or localhost');
  }
  final result = await web.window.crypto.subtle
      .digest('SHA-256'.toJS, Uint8List.fromList(bytes).toJS)
      .toDart;
  if (result == null) {
    throw StateError('Browser checksum calculation failed');
  }
  final digest = (result as JSArrayBuffer).toDart.asUint8List();
  return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
