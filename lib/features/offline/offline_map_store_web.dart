import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'offline_region.dart';
import 'offline_region_package.dart';

OfflineMapStorage openOfflineMapStore() => WebOfflineMapStore();

class WebOfflineMapStore implements OfflineMapStorage, PreparedMapStorage {
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
    activePreparedRegion(regions);
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

  @override
  Future<void> importPackage(OfflineRegionPackage package) async {
    final previous = await regions(), cache = await _cache;
    final retained = previous
        .where((r) => r.id != package.region.id)
        .map((r) => r.withPackageActive(false))
        .toList();
    if (retained.length >= 12) {
      throw const FormatException('Keep at most 12 offline regions');
    }
    final next = [...retained, package.region],
        prefix = 'prepared/${package.region.packageId}/';
    final used = (await tiles())
        .where(
          (t) =>
              !t.key.startsWith(prefix) &&
              retained.any((r) => r.includesKey(t.key)),
        )
        .fold<int>(0, (n, t) => n + t.bytes);
    if (used + package.files.values.fold<int>(0, (n, b) => n + b.length) >
        offlineMapBudget) {
      throw const FormatException('Offline map storage limit reached');
    }
    final alreadyValid = previous.any(
      (r) => r.packageId == package.region.packageId,
    );
    try {
      // New namespace is invisible until the regions pointer is published.
      for (final entry in package.files.entries) {
        final headers = web.Headers();
        headers.set('content-type', preparedMime(entry.key));
        headers.set('x-fpv-size', entry.value.length.toString());
        headers.set(
          'x-fpv-fetched-at',
          package.region.preparedAt!.toIso8601String(),
        );
        await cache
            .put(
              '$root$prefix${entry.key}'.toJS,
              web.Response(
                entry.value.toJS,
                web.ResponseInit(headers: headers),
              ),
            )
            .toDart;
      }
      await cache
          .put(
            '${root}regions.json'.toJS,
            web.Response(
              jsonEncode({
                'revision': DateTime.now().microsecondsSinceEpoch,
                'regions': next.map((r) => r.toJson()).toList(),
              }).toJS,
            ),
          )
          .toDart;
    } catch (_) {
      if (!alreadyValid) {
        for (final entry in package.files.keys) {
          await cache.delete('$root$prefix$entry'.toJS).toDart;
        }
      }
      rethrow;
    }
    // Cleanup after publication is best effort, never a failed replacement.
    try {
      await setRegions(next);
    } catch (_) {
      /* Unreferenced data can be removed later. */
    }
  }
}
