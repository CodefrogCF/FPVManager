import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'scenery_model_import.dart';
import 'scenery_storage_platform.dart';

const _models = XTypeGroup(
  label: 'glTF 2.0 models',
  extensions: ['glb', 'gltf'],
  mimeTypes: [
    'model/gltf-binary',
    'model/gltf+json',
    'application/octet-stream',
    'application/json',
  ],
  uniformTypeIdentifiers: ['public.data'],
);
const _resources = XTypeGroup(
  label: 'glTF resources',
  extensions: ['bin', 'png', 'jpg', 'jpeg'],
  mimeTypes: ['application/octet-stream', 'image/png', 'image/jpeg'],
  uniformTypeIdentifiers: ['public.data'],
);

final class SceneryImportCancelled implements Exception {
  const SceneryImportCancelled();
}

Future<Uint8List> readScenerySelection(XFile file) async {
  if (await file.length() > SceneryImportLimits.bytes) {
    throw const FormatException('File exceeds 64 MiB');
  }
  final data = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (data.length + chunk.length > SceneryImportLimits.bytes) {
      throw const FormatException('File exceeds 64 MiB');
    }
    data.add(chunk);
  }
  return data.takeBytes();
}

/// Platforms without directory access select each requested URI explicitly.
/// That avoids ambiguity from two nested textures sharing the same basename.
Future<(String, PreparedSceneryModel)?> pickSceneryModel({
  required Future<bool> Function(String uri) requestResource,
  SceneryImportProgress? progress,
}) async {
  final model = await openFile(acceptedTypeGroups: [_models]);
  if (model == null) return null;
  final bytes = await readScenerySelection(model);
  final prepared = await const SceneryModelImporter().prepare(
    bytes: bytes,
    name: model.name,
    progress: progress,
    readResource: (uri) async {
      final adjacent = await readAdjacentSceneryResource(model.path, uri);
      if (adjacent != null) return adjacent;
      if (!await requestResource(uri)) throw const SceneryImportCancelled();
      final selected = await openFile(
        acceptedTypeGroups: [_resources],
        confirmButtonText: 'Select resource',
      );
      if (selected == null) throw const SceneryImportCancelled();
      return readScenerySelection(selected);
    },
  );
  return (model.name, prepared);
}
