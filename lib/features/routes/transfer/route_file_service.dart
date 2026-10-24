import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/route_transfer.dart';
import 'route_file_codec.dart';

abstract interface class RouteFileService {
  const factory RouteFileService() = LocalRouteFileService;
  Future<RouteImportPreview?> pickRoutes();
  Future<bool> exportRoute(ImportedRoute route, RouteFileFormat format);
}

final class LocalRouteFileService implements RouteFileService {
  const LocalRouteFileService();
  @override
  Future<RouteImportPreview?> pickRoutes() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Flight routes',
          extensions: ['geojson', 'json', 'gpx'],
          mimeTypes: [
            'application/geo+json',
            'application/json',
            'application/gpx+xml',
            'application/xml',
            'text/xml',
          ],
          uniformTypeIdentifiers: ['public.json', 'public.xml'],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0 || length > routeFileMaxBytes) {
      throw const FormatException('Choose a route file up to 4 MiB');
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (data.length + chunk.length > routeFileMaxBytes) {
        throw const FormatException('Route file exceeds 4 MiB');
      }
      data.add(chunk);
    }
    return compute(decodeRouteFile, data.takeBytes());
  }

  @override
  Future<bool> exportRoute(ImportedRoute route, RouteFileFormat format) async {
    final bytes = encodeRouteFile(route, format),
        extension = format == RouteFileFormat.geoJson ? 'geojson' : 'gpx';
    final basename = route.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final name = '${basename.isEmpty ? "route" : basename}.$extension';
    final mime = format == RouteFileFormat.geoJson
        ? 'application/geo+json'
        : 'application/gpx+xml';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('saveRoute', {
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
