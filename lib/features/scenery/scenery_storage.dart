import 'dart:typed_data';

import 'scenery_digest.dart';

abstract interface class SceneryStorage {
  Map<String, String> get rendererOptions;
  Future<Uint8List?> read(String key);

  /// Returns true only if new bytes were created; callers can roll them back.
  Future<bool> put(String key, Uint8List bytes);
  Future<void> remove(String key);
}

bool isManagedSceneryKey(String key) =>
    RegExp(r'^[a-f0-9]{64}\.glb$').hasMatch(key);
Future<void> verifyManagedScenery(String key, Uint8List bytes) async {
  if (!isManagedSceneryKey(key) || '${await sceneryDigest(bytes)}.glb' != key) {
    throw const FormatException('Scenery file checksum mismatch');
  }
}
