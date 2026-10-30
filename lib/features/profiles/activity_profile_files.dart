import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models/activity_profile.dart';

class ActivityProfileFiles {
  const ActivityProfileFiles();
  Future<ActivityProfile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Aktivitätsprofil',
          extensions: ['fpvprofile', 'json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0 || length > activityProfileMaxBytes) {
      throw const FormatException(
        'Profildatei muss zwischen 1 Byte und 128 KiB groß sein',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (bytes.length + chunk.length > activityProfileMaxBytes) {
        throw const FormatException('Profildatei ist zu groß');
      }
      bytes.add(chunk);
    }
    return decodeActivityProfile(utf8.decode(bytes.takeBytes()));
  }

  Future<bool> save(ActivityProfile profile) async {
    final bytes = Uint8List.fromList(
      utf8.encode(encodeActivityProfile(profile)),
    );
    const name = 'activity.fpvprofile', mime = 'application/json';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveActivityProfile', {
                'name': name,
                'mimeType': mime,
                'bytes': bytes,
              }) ??
          false;
    }
    final file = XFile.fromData(bytes, name: name, mimeType: mime);
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
