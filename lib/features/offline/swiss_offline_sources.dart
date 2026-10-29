import 'dart:convert';

import 'package:http/http.dart' as http;

import '../mobility/road_routing.dart';
import 'offline_region.dart';

/// Official download assets, not WMTS/quantized-mesh rendering endpoints.
/// Discovery does not imply that source rasters are ready for the globe.
class SwissOfflineAsset {
  const SwissOfflineAsset({
    required this.collection,
    required this.itemId,
    required this.assetId,
    required this.url,
    required this.sha256,
    required this.sourceTime,
    required this.updatedAt,
    required this.resolution,
    required this.bounds,
    this.bytes,
  });
  final String collection, itemId, assetId, sha256;
  final Uri url;
  final DateTime sourceTime;
  final DateTime? updatedAt;
  final double resolution;
  final List<double> bounds;
  final int? bytes;
  bool get terrain => collection == SwissOfflineSources.terrainCollection;
  Map<String, dynamic> toJson() => {
    'collection': collection,
    'itemId': itemId,
    'assetId': assetId,
    'url': url.toString(),
    'sha256': sha256,
    'sourceTimeUtc': sourceTime.toIso8601String(),
    'updatedAtUtc': updatedAt?.toIso8601String(),
    'resolutionMeters': resolution,
    'horizontalReference': 'EPSG:2056',
    'verticalReference': terrain ? 'LN02' : 'notApplicable',
    'bounds': bounds,
    'bytes': bytes,
  };
}

class SwissOfflineSourcePlan {
  const SwissOfflineSourcePlan({
    required this.region,
    required this.retrievedAt,
    required this.assets,
    required this.notices,
  });
  final OfflineRegion region;
  final DateTime retrievedAt;
  final List<SwissOfflineAsset> assets;
  final List<String> notices;
  int? get totalBytes => assets.any((a) => a.bytes == null)
      ? null
      : assets.fold<int>(0, (n, a) => n + a.bytes!);
  Map<String, dynamic> toJson() => {
    'format': 'fpvmanager-official-sources',
    'version': 1,
    'region': {
      'id': region.id,
      'name': region.name,
      'west': region.west,
      'south': region.south,
      'east': region.east,
      'north': region.north,
      'style': region.style,
      'imageryLevel': region.imageryLevel,
      'terrainLevel': region.terrainLevel,
    },
    'retrievedAtUtc': retrievedAt.toIso8601String(),
    'attribution': '© swisstopo',
    'terms': SwissOfflineSources.terms,
    'readyForGlobe': false,
    'assets': assets.map((a) => a.toJson()).toList(),
    'notices': notices,
  };
}

class SwissOfflineSources {
  SwissOfflineSources({http.Client? client, DateTime Function()? now})
    : _http = MobilityHttp(client: client),
      _now = now ?? DateTime.now;
  static const terrainCollection = 'ch.swisstopo.swissalti3d';
  static const imageryCollection = 'ch.swisstopo.pixelkarte-farbe-pk25.noscale';
  static const terms =
      'https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices';
  static const _root = 'https://data.geo.admin.ch/api/stac/v1/collections/';
  final MobilityHttp _http;
  final DateTime Function() _now;
  bool _disposed = false;
  Future<SwissOfflineSourcePlan>? _pending;
  String? _pendingRegion;

  /// A plan is bounded, explicit, and contains the source date separately from
  /// retrieval time. The newest supported edition per spatial sheet is selected.
  Future<SwissOfflineSourcePlan> discover(OfflineRegion region) {
    if (_disposed) return Future.error(StateError('Source discovery closed'));
    final key = jsonEncode(region.toJson());
    if (_pending != null) {
      if (_pendingRegion == key) return _pending!;
      return Future.error(StateError('Another source discovery is running'));
    }
    _pendingRegion = key;
    return _pending = _discover(region).whenComplete(() {
      _pending = null;
      _pendingRegion = null;
    });
  }

  Future<SwissOfflineSourcePlan> _discover(OfflineRegion region) async {
    if (region.style != 'topographic') {
      throw const FormatException(
        'Official source packages currently support topographic maps only',
      );
    }
    final assets = <SwissOfflineAsset>[], notices = <String>[];
    for (final collection in [terrainCollection, imageryCollection]) {
      final selected = <String, SwissOfflineAsset>{};
      final first = Uri.parse('$_root$collection/items').replace(
        queryParameters: {
          'bbox':
              '${region.west},${region.south},${region.east},${region.north}',
          'limit': '100',
        },
      );
      Uri? next = first;
      final seen = <String>{};
      var features = 0, pages = 0;
      while (next != null) {
        if (_disposed) throw StateError('Source discovery closed');
        if (++pages > 20 || !seen.add(next.toString())) {
          throw const FormatException(
            'STAC pagination is incomplete or excessive',
          );
        }
        final body = jsonDecode(
          await _http.text(next, maxBytes: 4 * 1024 * 1024),
        );
        if (body is! Map ||
            body['type'] != 'FeatureCollection' ||
            body['features'] is! List ||
            (features += (body['features'] as List).length) > 2000) {
          throw const FormatException('Invalid STAC source page');
        }
        for (final item in body['features']) {
          if (item is! Map ||
              item['collection'] != collection ||
              item['id'] is! String ||
              item['assets'] is! Map ||
              item['properties'] is! Map) {
            throw const FormatException('Invalid STAC source item');
          }
          final id = item['id'] as String;
          final match = RegExp(
            collection == terrainCollection
                ? r'^swissalti3d_\d{4}_(\d{4}-\d{4})$'
                : r'^swiss-map-raster25_\d{4}_(\d{4})$',
          ).firstMatch(id);
          if (match == null) {
            throw const FormatException('Unsupported source grid identifier');
          }
          final time = _date(item['properties']['datetime']);
          if (time.isAfter(_now().toUtc().add(const Duration(days: 1)))) {
            throw const FormatException('Source edition is in the future');
          }
          final bounds = item['bbox'];
          if (bounds is! List ||
              bounds.length != 4 ||
              bounds.any((v) => v is! num || !v.isFinite) ||
              bounds[0] >= bounds[2] ||
              bounds[1] >= bounds[3]) {
            throw const FormatException('Invalid source bounds');
          }
          if (bounds[0] > region.east ||
              bounds[2] < region.west ||
              bounds[1] > region.north ||
              bounds[3] < region.south) {
            continue;
          }
          final supported = <SwissOfflineAsset>[];
          for (final entry in (item['assets'] as Map).entries) {
            final a = entry.value;
            if (a is! Map) {
              throw const FormatException('Invalid STAC source asset');
            }
            final terrain = collection == terrainCollection;
            if (a['type'] is! String ||
                !(a['type'] as String).startsWith('image/tiff') ||
                a['proj:epsg'] != 2056 ||
                a['gsd'] != (terrain ? 2 : 1.25) ||
                (!terrain && a['geoadmin:variant'] != 'komb')) {
              continue;
            }
            if (terrain && !(entry.key as String).endsWith('_2056_5728.tif')) {
              notices.add('Unknown terrain height reference: $id');
              continue;
            }
            final url = Uri.tryParse(a['href'] is String ? a['href'] : '');
            if (url == null ||
                url.scheme != 'https' ||
                url.host != 'data.geo.admin.ch' ||
                url.hasPort ||
                url.userInfo.isNotEmpty ||
                url.hasQuery ||
                url.hasFragment ||
                url.pathSegments.length != 3 ||
                url.pathSegments[0] != collection ||
                url.pathSegments[1] != id ||
                url.pathSegments[2] != entry.key) {
              throw const FormatException('Untrusted STAC download URL');
            }
            final checksum = a['file:checksum'];
            if (checksum is! String ||
                !RegExp(r'^1220[0-9a-fA-F]{64}$').hasMatch(checksum)) {
              throw const FormatException(
                'Source asset lacks a supported SHA-256 checksum',
              );
            }
            final size = a['file:size'];
            if (size != null &&
                (size is! int || size <= 0 || size > 512 * 1024 * 1024)) {
              throw const FormatException(
                'Source asset exceeds download limit',
              );
            }
            supported.add(
              SwissOfflineAsset(
                collection: collection,
                itemId: id,
                assetId: entry.key,
                url: url,
                sha256: checksum.substring(4).toLowerCase(),
                sourceTime: time,
                updatedAt: a['updated'] == null ? null : _date(a['updated']),
                resolution: (a['gsd'] as num).toDouble(),
                bounds: bounds
                    .map<double>((v) => (v as num).toDouble())
                    .toList(),
                bytes: size,
              ),
            );
          }
          if (supported.length != 1) {
            throw const FormatException(
              'Source sheet has unavailable or ambiguous supported assets',
            );
          }
          final old = selected[match[1]!], asset = supported.single;
          if (old == null || asset.sourceTime.isAfter(old.sourceTime)) {
            selected[match[1]!] = asset;
          }
          if (old != null &&
              asset.sourceTime == old.sourceTime &&
              asset.sha256 != old.sha256) {
            throw const FormatException('Ambiguous source edition');
          }
          if (selected.length > 128) {
            throw const FormatException(
              'Choose a smaller source region (at most 128 sheets per product)',
            );
          }
        }
        final links = body['links'];
        if (links is! List) {
          throw const FormatException('STAC pagination links missing');
        }
        final more = links
            .where((l) => l is Map && l['rel'] == 'next')
            .toList();
        if (more.length > 1) {
          throw const FormatException('Ambiguous STAC pagination');
        }
        next = more.isEmpty
            ? null
            : Uri.tryParse(
                more.single['href'] is String ? more.single['href'] : '',
              );
        if (more.isNotEmpty &&
            (next == null ||
                next.scheme != 'https' ||
                next.host != first.host ||
                next.hasPort ||
                next.userInfo.isNotEmpty ||
                next.hasFragment ||
                next.path != first.path ||
                !next.queryParameters.keys.every(
                  {'bbox', 'limit', 'cursor'}.contains,
                ))) {
          throw const FormatException('Untrusted STAC pagination');
        }
      }
      if (selected.isEmpty) {
        throw const FormatException(
          'No supported official source coverage for this region',
        );
      }
      assets.addAll(selected.values);
    }
    if (_disposed) throw StateError('Source discovery closed');
    return SwissOfflineSourcePlan(
      region: region,
      retrievedAt: _now().toUtc(),
      assets: assets,
      notices: notices,
    );
  }

  static DateTime _date(Object? value) {
    if (value is! String ||
        !value.endsWith('Z') ||
        DateTime.tryParse(value) == null) {
      throw const FormatException('Invalid source timestamp');
    }
    return DateTime.parse(value).toUtc();
  }

  void dispose() {
    _disposed = true;
    _http.dispose();
  }
}
