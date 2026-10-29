import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'offline_region_package.dart';
import 'swiss_offline_sources.dart';

class OfflinePackageFiles {
  const OfflinePackageFiles();
  Future<Uint8List?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'FPVManager offline region',
          extensions: ['fpvregion'],
          mimeTypes: ['application/octet-stream'],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0 || length > regionPackageMaxBytes) {
      throw const FormatException('Choose an offline package up to 64 MiB');
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (output.length + chunk.length > regionPackageMaxBytes) {
        throw const FormatException('Offline package exceeds 64 MiB');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }

  Future<bool> savePlan(SwissOfflineSourcePlan plan) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(plan.toJson())));
    const name = 'offline-region.fpvofflineplan';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveOfflinePlan', {
                'name': name,
                'mimeType': 'application/json',
                'bytes': bytes,
              }) ??
          false;
    }
    final file = XFile.fromData(
      bytes,
      name: name,
      mimeType: 'application/json',
    );
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    final target = await getSaveLocation(suggestedName: name);
    if (target == null) return false;
    await file.saveTo(target.path);
    return true;
  }
}
