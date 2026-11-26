import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import 'scenery_collision_import.dart';
import 'scenery_digest.dart';
import 'scenery_manifest.dart';
import 'scenery_model_import.dart';
import 'scenery_package_zip.dart';
import 'scenery_storage.dart';
import 'scenery_tileset_options.dart';

export 'scenery_package_zip.dart' show sceneryPackageMaxBytes;

/// Untrusted archives are validated before constructing an installable package.
final class SceneryPackage {
  SceneryPackage._(this.manifest, Map<String, Uint8List> files)
    : files = Map.unmodifiable(
        files.map((k, v) => MapEntry(k, v.asUnmodifiableView())),
      );
  final SceneryManifest manifest;
  final Map<String, Uint8List> files;
  bool get metadataOnly => packageInfo(manifest)?['metadataOnly'] == true;
  int get revision => packageInfo(manifest)?['revision'] as int;
}

Map? packageInfo(SceneryManifest m) =>
    (m.toJson()['extensions'] as Map?)?['package'] as Map?;

Never _bad(String message) => throw FormatException(message);

/// Only portable fields enter the runtime. Never accept arbitrary Cesium
/// extension objects (which can carry extra resource paths or terrain overrides).
SceneryManifest _portable(SceneryManifest m, Map<String, dynamic> info) {
  final doc = m.toJson(), ext = doc['extensions'] as Map?;
  final source = doc['source'] as Map;
  if (source['url'] is String && Uri.parse(source['url'] as String).hasQuery) {
    _bad('Source URL must not contain query credentials');
  }
  final opacity = (ext?['cesium'] as Map?)?['alignment'] is Map
      ? ((ext?['cesium'] as Map)['alignment'] as Map)['opacity']
      : null;
  if (opacity != null &&
      (opacity is! num || !opacity.isFinite || opacity < .02 || opacity > 1)) {
    _bad('Invalid package opacity');
  }
  final lods = ext?['lods'];
  doc['extensions'] = <String, dynamic>{
    'package': info,
    'lods': ?lods,
    if (opacity != null)
      'cesium': {
        'alignment': {'opacity': opacity},
      },
  };
  // Never activate imported content implicitly; metadata references remain inert.
  (doc['visibility'] as Map)['enabled'] = false;
  return SceneryManifest.fromJson(doc);
}

void _preview(Uint8List data) {
  if (data.length > 32 * 1024) _bad('Preview exceeds 32 KiB');
  final decoder = image.PngDecoder(), info = decoder.startDecode(data);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width > 512 ||
      info.height > 512 ||
      info.numFrames != 1) {
    _bad('Invalid package preview PNG');
  }
}

Future<SceneryPackage> decodeSceneryPackage(Uint8List input) async {
  // Copy once: validated bytes must not be mutable by the caller afterwards.
  if (input.length > sceneryPackageMaxBytes) _bad('Package exceeds 64 MiB');
  final entries = await compute(readSceneryZip, Uint8List.fromList(input));
  final raw = jsonDecode(utf8.decode(entries.remove('manifest.json')!));
  if (raw is! Map<String, dynamic> ||
      raw['format'] != 'fpvmanager-scenery' ||
      raw['version'] != 1 ||
      raw['revision'] is! int ||
      (raw['revision'] as int) < 1 ||
      (raw['revision'] as int) > 2147483647 ||
      raw['metadataOnly'] is! bool ||
      raw['redistributionAllowed'] is! bool ||
      raw['files'] is! Map<String, dynamic>) {
    _bad('Unsupported scenery package manifest');
  }
  final metadata = raw['metadataOnly'] as bool;
  if (!metadata && raw['redistributionAllowed'] != true) {
    _bad('Asset redistribution permission required');
  }
  final manifest = SceneryManifest.fromJson(raw['scenery']);
  final expected = <String>{};
  for (final a in manifest.assets) {
    if (!['managed', 'bundled', remoteTilesetProvider].contains(a.provider)) {
      _bad('Unsupported package asset provider');
    }
    if (a.provider == remoteTilesetProvider && Uri.parse(a.uri).hasQuery) {
      _bad('Remote package references must not contain query credentials');
    }
    if (!metadata) {
      if (a.provider != 'managed') {
        _bad('Offline packages require managed GLB/FPC files');
      }
      expected.add('assets/${a.uri}');
    }
  }
  final preview = entries['preview.png'];
  if (preview != null) {
    if (metadata) _bad('Metadata-only packages cannot include preview bytes');
    _preview(preview);
    expected.add('preview.png');
  }
  final declared = raw['files'] as Map;
  if (entries.length != expected.length ||
      declared.length != expected.length ||
      !expected.every(entries.containsKey) ||
      !expected.every(declared.containsKey)) {
    _bad('Missing or unexpected package resources');
  }
  for (final e in entries.entries) {
    final info = declared[e.key];
    if (info is! Map ||
        info['bytes'] != e.value.length ||
        info['sha256'] != await sceneryDigest(e.value)) {
      _bad('Package checksum mismatch: ${e.key}');
    }
  }
  final files = <String, Uint8List>{};
  if (!metadata) {
    final verified = <String, Map<String, dynamic>>{};
    for (final a in manifest.assets) {
      final bytes = entries['assets/${a.uri}']!;
      if (!verified.containsKey(a.uri)) {
        await verifyManagedScenery(a.uri, bytes);
        if (a.role == 'visual') {
          final prepared = await const SceneryModelImporter().prepare(
            bytes: bytes,
            name: a.uri,
            readResource: (_) async => null,
          );
          if (prepared.key != a.uri) {
            _bad('Package model must be canonical self-contained GLB');
          }
          verified[a.uri] = prepared.metadata;
        } else {
          final prepared = await prepareSceneryCollision(bytes);
          verified[a.uri] = prepared.metadata;
        }
      }
      final actual = verified[a.uri]!;
      for (final k in [
        'triangles',
        'vertices',
        'textures',
        'estimatedBytes',
        'byteLength',
        'localBounds',
      ]) {
        if (k == 'localBounds') {
          final claimed = a.model![k] as List, observed = actual[k] as List;
          if (!listEquals<num>(claimed.cast<num>(), observed.cast<num>())) {
            _bad('Model bounds mismatch');
          }
        } else if (a.model![k] != actual[k]) {
          _bad('Model resource metadata mismatch: $k');
        }
      }
      files[a.uri] = bytes;
    }
  }
  final portable = _portable(manifest, {
    'revision': raw['revision'],
    'metadataOnly': metadata,
    'redistributionAllowed': raw['redistributionAllowed'],
    if (preview != null) 'previewPng': base64Encode(preview),
  });
  return SceneryPackage._(portable, files);
}

Future<Uint8List> encodeSceneryPackage(
  SceneryManifest manifest, {
  required Future<Uint8List?> Function(String) read,
  required bool metadataOnly,
  required bool redistributionAllowed,
  required int revision,
}) async {
  if (!metadataOnly && !redistributionAllowed) {
    _bad('Explicit redistribution permission required');
  }
  if (revision < 1 || revision > 2147483647) _bad('Invalid package revision');
  if (!metadataOnly &&
      (packageInfo(manifest)?['metadataOnly'] == true ||
          packageInfo(manifest)?['redistributionAllowed'] == false)) {
    _bad('Reference-only scenery cannot export assets');
  }
  for (final a in manifest.assets) {
    if (a.provider == remoteTilesetProvider && Uri.parse(a.uri).hasQuery) {
      _bad('Remote package references must not contain query credentials');
    }
  }
  final files = <String, Uint8List>{};
  var total = 0;
  if (!metadataOnly) {
    for (final a in manifest.assets) {
      if (a.provider != 'managed') {
        _bad('Provider assets cannot be redistributed by this exporter');
      }
      final path = 'assets/${a.uri}';
      if (files.containsKey(path)) continue;
      final bytes = await read(a.uri);
      if (bytes == null) _bad('Missing scenery asset: ${a.uri}');
      await verifyManagedScenery(a.uri, bytes);
      total += bytes.length;
      if (total > sceneryPackageMaxBytes) _bad('Package exceeds 64 MiB');
      files[path] = bytes;
    }
    final preview = packageInfo(manifest)?['previewPng'];
    if (preview is String) {
      final png = base64Decode(preview);
      _preview(png);
      files['preview.png'] = png;
    }
  }
  final portable = _portable(manifest, {
    'revision': revision,
    'metadataOnly': metadataOnly,
    'redistributionAllowed': redistributionAllowed,
  });
  final doc = portable.toJson();
  (doc['extensions'] as Map).remove('package');
  final checksums = <String, dynamic>{};
  for (final e in files.entries) {
    checksums[e.key] = {
      'bytes': e.value.length,
      'sha256': await sceneryDigest(e.value),
    };
  }
  files['manifest.json'] = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'fpvmanager-scenery',
        'version': 1,
        'revision': revision,
        'metadataOnly': metadataOnly,
        'redistributionAllowed': redistributionAllowed,
        'scenery': doc,
        'files': checksums,
      }),
    ),
  );
  return compute(writeSceneryZip, files);
}
