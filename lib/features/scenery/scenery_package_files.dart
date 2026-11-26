import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'scenery_package.dart';

class SceneryPackageFiles {
  const SceneryPackageFiles();

  Future<Uint8List?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'FPVManager scenery',
          extensions: ['fpvscenery'],
          mimeTypes: ['application/octet-stream', 'application/zip'],
        ),
      ],
    );
    if (file == null) return null;
    final size = await file.length();
    if (size < 1 || size > sceneryPackageMaxBytes) {
      throw const FormatException('Choose a scenery package up to 64 MiB');
    }
    return _collect(file.openRead(0, size), expected: size);
  }

  static Uri validateRemoteUrl(String value) {
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        value.length > 2048 ||
        RegExp(r'[\x00-\x20\\]').hasMatch(value)) {
      throw const FormatException('Use a complete HTTPS package URL');
    }
    return url;
  }

  /// Call only after explicit consent. Never forward credentials or follow
  /// redirects. The URL is not persisted in the scenery catalog.
  Future<Uint8List> download(Uri url, {http.Client? client}) async {
    validateRemoteUrl(url.toString());
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .send(http.Request('GET', url)..followRedirects = false)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > sceneryPackageMaxBytes) {
        throw FormatException(
          'Package download rejected (HTTP ${response.statusCode})',
        );
      }
      return await _collect(
        response.stream.timeout(const Duration(seconds: 20)),
        expected: response.contentLength,
      ).timeout(const Duration(minutes: 3));
    } finally {
      if (client == null) transport.close();
    }
  }

  Future<Uint8List> _collect(Stream<List<int>> source, {int? expected}) async {
    final output = BytesBuilder(copy: false);
    await for (final chunk in source) {
      if (output.length + chunk.length > sceneryPackageMaxBytes) {
        throw const FormatException('Scenery package exceeds 64 MiB');
      }
      output.add(chunk);
    }
    if (output.length == 0 || (expected != null && output.length != expected)) {
      throw const FormatException('Empty or incomplete scenery package');
    }
    return output.takeBytes();
  }

  Future<bool> save(String id, Uint8List bytes) async {
    if (!RegExp(r'^[a-z0-9_-]{1,80}$').hasMatch(id) ||
        bytes.isEmpty ||
        bytes.length > sceneryPackageMaxBytes) {
      throw const FormatException('Invalid scenery export');
    }
    final name = '$id.fpvscenery';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveSceneryPackage', {
                'name': name,
                'mimeType': 'application/octet-stream',
                'bytes': bytes,
              }) ??
          false;
    }
    final file = XFile.fromData(
      bytes,
      name: name,
      mimeType: 'application/octet-stream',
    );
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }
}
