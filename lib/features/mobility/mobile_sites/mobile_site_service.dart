import 'dart:async';

import 'package:flutter/foundation.dart';

import '../road_routing.dart';
import 'mobile_site_models.dart';
import 'mobile_site_stac.dart';
import 'mobile_site_store.dart';

Uri mobileSitesIdentifyUrl(MobileSiteArea area) {
  final bounds = area.lv95Envelope.map((n) => n.toStringAsFixed(2)).join(',');
  return Uri.https(
    'api3.geo.admin.ch',
    '/rest/services/ech/MapServer/identify',
    {
      'geometryType': 'esriGeometryEnvelope',
      'geometry': bounds,
      'mapExtent': bounds,
      'imageDisplay': '256,256,96',
      'layers': 'all:$mobileSiteCollectionId',
      'tolerance': '0',
      'geometryFormat': 'esrijson',
      'returnGeometry': 'true',
      'sr': '2056',
      'limit': '200',
      'lang': 'de',
    },
  );
}

final mobileSitesStacCollectionUrl = Uri.https(
  'data.geo.admin.ch',
  '/api/stac/v1/collections/$mobileSiteCollectionId',
);
final mobileSitesStacItemsUrl = Uri.https(
  'data.geo.admin.ch',
  '/api/stac/v1/collections/$mobileSiteCollectionId/items',
  {'limit': '20'},
);
final mobileSitesStacAssetsUrl = Uri.https(
  'data.geo.admin.ch',
  '/api/stac/v1/collections/$mobileSiteCollectionId/assets',
);

class MobileSitesBudget {
  MobileSitesBudget({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  static final shared = MobileSitesBudget();
  final List<DateTime> history = [];
  void reserve() {
    final t = clock().toUtc();
    history.removeWhere((old) => t.difference(old) > const Duration(hours: 1));
    if (history.length >= 12 ||
        (history.isNotEmpty &&
            t.difference(history.last) < const Duration(seconds: 15))) {
      throw const FormatException(
        'BAKOM: wait 15 seconds, maximum 12 searches/hour.',
      );
    }
    history.add(t);
  }
}

/// No nationwide search/download, no invented mast heights, and no automatic
/// network request when the screen is opened. A STAC metadata failure does not
/// silently change the spatial dataset source (always official GeoAdmin).
class MobileSitesService {
  MobileSitesService({
    MobileSiteStore? store,
    MobilityHttp? transport,
    MobileSitesBudget? budget,
    DateTime Function()? clock,
    Uri Function(MobileSiteArea)? endpoint,
  }) : store = store ?? SqliteMobileSiteStore(),
       _ownsStore = store == null,
       _http = transport ?? MobilityHttp(),
       _ownsHttp = transport == null,
       _clock = clock ?? DateTime.now,
       _budget =
           budget ??
           (clock == null
               ? MobileSitesBudget.shared
               : MobileSitesBudget(clock: clock)),
       endpoint = endpoint ?? mobileSitesIdentifyUrl;
  final MobileSiteStore store;
  final bool _ownsStore;
  final MobilityHttp _http;
  final bool _ownsHttp;
  final DateTime Function() _clock;
  final MobileSitesBudget _budget;
  final Uri Function(MobileSiteArea) endpoint;
  final Map<String, Future<MobileSiteSnapshot>> _inFlight = {};
  MobileSiteCatalog? _catalog;
  DateTime? _catalogLoadedUtc;
  Future<MobileSiteCatalog>? _pendingCatalog;
  bool _disposed = false;

  Future<MobileSiteSnapshot?> offline(MobileSiteArea area) => store.read(area);

  Future<MobileSiteCatalog> discover() {
    if (_disposed) {
      throw StateError('BAKOM service closed');
    }
    if (_catalog != null &&
        _catalogLoadedUtc != null &&
        _clock().toUtc().difference(_catalogLoadedUtc!) <
            const Duration(hours: 6)) {
      return Future.value(_catalog!);
    }
    if (_pendingCatalog != null) {
      return _pendingCatalog!;
    }
    final future = _discover();
    _pendingCatalog = future;
    unawaited(
      future.then<void>(
        (_) {
          _pendingCatalog = null;
        },
        onError: (Object error, StackTrace stack) {
          _pendingCatalog = null;
        },
      ),
    );
    return future;
  }

  Future<MobileSiteCatalog> _discover() async {
    final collection = await _http.text(
      mobileSitesStacCollectionUrl,
      maxBytes: 500000,
    );
    // Collection-wide assets and item assets are separate STAC locations.
    // One missing endpoint does not imply that the collection has no assets.
    String? assets;
    String? items;
    try {
      assets = await _http.text(mobileSitesStacAssetsUrl, maxBytes: 1000000);
    } catch (_) {
      /* Unsupported endpoint; item assets may still exist. */
    }
    try {
      items = await _http.text(mobileSitesStacItemsUrl, maxBytes: 1000000);
    } catch (_) {
      /* Collection assets remain discoverable. */
    }
    if (assets == null && items == null) {
      throw const FormatException('BAKOM STAC asset listings unavailable');
    }
    final result = parseMobileSiteStac(
      collection,
      items ?? '{"features":[]}',
      collectionAssetsJson: assets,
    );
    if (_disposed) {
      throw StateError('BAKOM service closed');
    }
    _catalog = result;
    _catalogLoadedUtc = _clock().toUtc();
    return result;
  }

  Future<MobileSiteSnapshot> search(
    MobileSiteArea area, {
    bool refresh = false,
  }) {
    if (_disposed) {
      throw StateError('BAKOM service closed');
    }
    final ongoing = _inFlight[area.key];
    if (ongoing != null) {
      return ongoing;
    }
    final future = _search(area, refresh: refresh);
    _inFlight[area.key] = future;
    // Don't return the failed original Future from a whenComplete callback.
    unawaited(
      future.then<void>(
        (_) {
          _inFlight.remove(area.key);
        },
        onError: (Object error, StackTrace stack) {
          _inFlight.remove(area.key);
        },
      ),
    );
    return future;
  }

  Future<MobileSiteSnapshot> _search(
    MobileSiteArea area, {
    required bool refresh,
  }) async {
    final old = await store.read(area);
    if (!refresh && old != null && !old.isOld(_clock())) {
      return old;
    }
    try {
      _budget.reserve();
      final response = await _http.text(
        endpoint(area),
        maxBytes: 1800000,
        headers: const {'Accept': 'application/json'},
      );
      final stations = await compute<String, List<MobileSite>>(
        parseMobileSites,
        response,
      );
      final result = MobileSiteSnapshot(
        area: area,
        stations: stations,
        fetchedUtc: _clock().toUtc(),
        sourceUpdatedUtc: _catalog?.updatedUtc,
        truncated: stations.length >= 200,
      );
      if (_disposed) {
        throw StateError('BAKOM service closed');
      }
      await store.replace(result);
      return result;
    } catch (_) {
      if (old != null) {
        return old.cached(failed: true);
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_ownsHttp) {
      _http.dispose();
    }
    if (_ownsStore && store is SqliteMobileSiteStore) {
      await (store as SqliteMobileSiteStore).dispose();
    }
  }
}
