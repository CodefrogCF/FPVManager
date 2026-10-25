import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'offline_region.dart';

OfflineMapStorage openOfflineMapStore() => WebOfflineMapStore();

class WebOfflineMapStore implements OfflineMapStorage {
  @override
  bool get rendererReady =>
      web.window.isSecureContext &&
      web.window.navigator.has('serviceWorker') &&
      (web.window.navigator.serviceWorker.controller?.scriptURL
              .split('?')
              .first
              .endsWith('/offline_service_worker.js') ??
          false);
  static const cacheName = 'fpvmanager-offline-maps-v1';
  String get root => Uri.base.resolve('offline/maps/').toString();
  Future<web.Cache> get _cache =>
      web.window.caches.open('$cacheName:$root').toDart;
  @override
  Future<List<OfflineRegion>> regions() async {
    final response = await (await _cache)
        .match('${root}regions.json'.toJS)
        .toDart;
    if (response == null) return [];
    final json = jsonDecode((await response.text().toDart).toDart);
    return [
      for (final region in (json as Map)['regions'] as List)
        OfflineRegion.fromJson(region as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> setRegions(List<OfflineRegion> regions) async {
    if (regions.length > 12) {
      throw const FormatException('Keep at most 12 offline regions');
    }
    final cache = await _cache;
    await cache
        .put(
          '${root}regions.json'.toJS,
          web.Response(
            jsonEncode({
              'revision': DateTime.now().microsecondsSinceEpoch,
              'regions': regions.map((r) => r.toJson()).toList(),
            }).toJS,
          ),
        )
        .toDart;
    for (final tile in await tiles()) {
      if (!regions.any((r) => r.includesKey(tile.key))) {
        await cache.delete('$root${tile.key}'.toJS).toDart;
      }
    }
  }

  @override
  Future<List<OfflineTileInfo>> tiles() async {
    final cache = await _cache,
        requests = await cache.keys().toDart,
        output = <OfflineTileInfo>[];
    for (final request in requests.toDart) {
      if (!request.url.startsWith(root)) continue;
      final key = request.url.substring(root.length);
      if (key == 'regions.json') continue;
      final response = await cache.match(request).toDart;
      if (response == null) continue;
      output.add(
        OfflineTileInfo(
          key,
          int.tryParse(response.headers.get('x-fpv-size') ?? '') ?? 0,
          DateTime.tryParse(response.headers.get('x-fpv-fetched-at') ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }
    return output;
  }

  @override
  Future<void> clear() => setRegions([]);
  @override
  Future<void> close() async {}
}
