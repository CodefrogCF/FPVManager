import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'backup_codec.dart';

class BackupFileService {
  const BackupFileService();
  Future<Uint8List?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'FPVManager backup',
          extensions: ['fpvbackup'],
          mimeTypes: ['application/octet-stream'],
        ),
      ],
    );
    if (file == null) return null;
    final size = await file.length();
    if (size <= 0 || size > backupMaxBytes) {
      throw const FormatException('Choose a backup up to 64 MiB');
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, size)) {
      if (output.length + chunk.length > backupMaxBytes) {
        throw const FormatException('Backup exceeds 64 MiB');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }

  Future<bool> save(Uint8List bytes) async {
    final date = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9T]'),
      '',
    );
    final name = 'fpvmanager-$date.fpvbackup';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveBackup', {
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
