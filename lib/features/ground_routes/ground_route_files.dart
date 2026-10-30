import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ground_gpx.dart';
import 'ground_route.dart';

class GroundRouteFiles {
  const GroundRouteFiles();
  Future<GroundGpxPreview?> pick(GroundTravelMode fallback) async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Bodenroute · GPX',
          extensions: ['gpx'],
          mimeTypes: ['application/gpx+xml', 'application/xml', 'text/xml'],
          uniformTypeIdentifiers: ['public.xml'],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length < 1 || length > groundGpxMaxBytes) {
      throw const FormatException('GPX unterstützt maximal 4 MiB');
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (data.length + chunk.length > groundGpxMaxBytes) {
        throw const FormatException('GPX ist zu groß');
      }
      data.add(chunk);
    }
    return compute(decodeGroundGpx, (data.takeBytes(), fallback));
  }

  Future<bool> save(GroundRoutePlan route) async {
    final data = await compute(encodeGroundGpx, route);
    const name = 'ground-route.gpx', mime = 'application/gpx+xml';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveRoute', {
                'name': name,
                'mimeType': mime,
                'bytes': data,
              }) ??
          false;
    }
    final file = XFile.fromData(data, name: name, mimeType: mime);
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
