import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'scenery_model_import.dart';
import 'scenery_storage.dart';

SceneryStorage createSceneryStorage() => NativeSceneryStorage();

/// Content-addressed private files, independent of personal-data backups.
final class NativeSceneryStorage implements SceneryStorage {
  NativeSceneryStorage({Future<Directory> Function()? directory})
    : _directory =
          directory ??
          (() async => Directory(
            '${(await getApplicationSupportDirectory()).path}/scenery/v1',
          ));
  final Future<Directory> Function() _directory;
  @override
  Map<String, String> get rendererOptions => const {'backend': 'server'};
  Future<File> _file(String key) async {
    if (!isManagedSceneryKey(key)) {
      throw const FormatException('Invalid scenery key');
    }
    final root = await _directory();
    await root.create(recursive: true);
    final canonical = await root.resolveSymbolicLinks();
    if (FileSystemEntity.typeSync('$canonical/$key', followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked scenery files are not supported');
    }
    return File('$canonical/$key');
  }

  @override
  Future<Uint8List?> read(String key) async {
    final path = (await _file(key)).path;
    return Isolate.run(() async {
      final f = File(path);
      if (!await f.exists()) return null;
      if (await f.length() > SceneryImportLimits.bytes) {
        throw const FormatException('Scenery file exceeds 64 MiB');
      }
      final bytes = await _readBounded(f);
      await verifyManagedScenery(key, bytes);
      return bytes;
    });
  }

  @override
  Future<bool> put(String key, Uint8List bytes) async {
    if (bytes.length > SceneryImportLimits.bytes) {
      throw const FormatException('Scenery file exceeds 64 MiB');
    }
    await Isolate.run(() => verifyManagedScenery(key, bytes));
    final file = await _file(key);
    if (await file.exists()) {
      try {
        if (await read(key) != null) return false;
      } on FormatException {
        /* Repair corrupt local bytes. */
      }
    }
    var used = 0;
    await for (final entity in file.parent.list(followLinks: false)) {
      if (entity is File && entity.path != file.path) {
        final name = entity.uri.pathSegments.last;
        final staging = RegExp(r'^[a-f0-9]{64}\.glb\.\d+\.tmp$').hasMatch(name);
        if (staging &&
            DateTime.now().difference(await entity.lastModified()) >
                const Duration(days: 1)) {
          await entity.delete();
        } else if (isManagedSceneryKey(name) || staging) {
          used += await entity.length();
        }
      }
    }
    if (used + bytes.length > SceneryImportLimits.storageBytes) {
      throw const FormatException(
        'Local scenery storage limit (512 MiB) reached',
      );
    }
    final stage = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await stage.writeAsBytes(bytes, flush: true);
      await stage.rename(file.path);
    } finally {
      if (await stage.exists()) await stage.delete();
    }
    return true;
  }

  @override
  Future<void> remove(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }
}

/// Resolve only inside the selected model's directory, including symlink checks.
Future<Uint8List?> readAdjacentSceneryResource(
  String modelPath,
  String relative,
) async {
  final safe = sceneryResourcePath(relative);
  if (!await File(modelPath).exists()) return null;
  final parent = await File(modelPath).parent.resolveSymbolicLinks();
  final file = File('$parent/$safe');
  if (!await file.exists()) return null;
  final resolved = await file.resolveSymbolicLinks();
  final prefix = '$parent${Platform.pathSeparator}';
  if (!(Platform.isWindows
      ? resolved.toLowerCase().startsWith(prefix.toLowerCase())
      : resolved.startsWith(prefix))) {
    throw const FormatException(
      'Resource resolves outside the selected model directory',
    );
  }
  if (await file.length() > SceneryImportLimits.bytes) {
    throw const FormatException('Resource exceeds 64 MiB');
  }
  return _readBounded(file);
}

Future<Uint8List> _readBounded(File file) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (builder.length + chunk.length > SceneryImportLimits.bytes) {
      throw const FormatException('Resource exceeds 64 MiB');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
