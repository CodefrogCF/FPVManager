import 'dart:convert';

import 'mobile_site_models.dart';

/// STAC is metadata, NOT a station FeatureCollection. Only advertised vector
/// files can be considered for file import. GeoPackage is not parsed by this
/// feature; bounded GeoAdmin Identify is the normal station-data path.
class MobileSiteAsset {
  const MobileSiteAsset({
    required this.id,
    required this.uri,
    required this.mediaType,
    required this.supported,
  });
  final String id, mediaType;
  final Uri uri;
  final bool supported;
}

class MobileSiteCatalog {
  const MobileSiteCatalog({
    required this.updatedUtc,
    required this.assets,
    required this.licence,
    required this.termsUrl,
  });
  final DateTime? updatedUtc;
  final String licence;
  final Uri? termsUrl;
  final List<MobileSiteAsset> assets;
}

DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

Uri? _officialUrl(Object? v) {
  if (v is! String) {
    return null;
  }
  final uri = Uri.tryParse(v);
  if (uri == null ||
      uri.scheme != 'https' ||
      !{
        'data.geo.admin.ch',
        'www.geo.admin.ch',
        'opendata.swiss',
      }.contains(uri.host)) {
    return null;
  }
  return uri;
}

MobileSiteCatalog parseMobileSiteStac(
  String collectionJson,
  String itemsJson, {
  String? collectionAssetsJson,
}) {
  if (collectionJson.length > 500000 ||
      itemsJson.length > 1000000 ||
      (collectionAssetsJson?.length ?? 0) > 1000000) {
    throw const FormatException('STAC response too large');
  }
  final collection = jsonDecode(collectionJson);
  final page = jsonDecode(itemsJson);
  if (collection is! Map ||
      collection['id'] != mobileSiteCollectionId ||
      page is! Map ||
      page['features'] is! List) {
    throw const FormatException('Unexpected BAKOM STAC metadata');
  }
  final items = page['features'] as List;
  if (items.length > 30) {
    throw const FormatException('Too many STAC items');
  }
  final assets = <String, MobileSiteAsset>{};
  DateTime? updated = _time(collection['updated']);
  void collect(Map entries) {
    for (final pair in entries.entries) {
      if (assets.length >= 60) {
        break;
      }
      final value = pair.value;
      if (value is! Map) {
        continue;
      }
      final uri = _officialUrl(value['href']);
      if (uri == null) {
        continue;
      }
      final mediaType = (value['type'] ?? '').toString();
      final path = uri.path.toLowerCase();
      final supported =
          path.endsWith('.geojson') ||
          path.endsWith('.json') ||
          path.endsWith('.csv') ||
          mediaType.contains('geo+json') ||
          mediaType.contains('text/csv');
      assets[uri.toString()] = MobileSiteAsset(
        id: pair.key.toString(),
        uri: uri,
        mediaType: mediaType,
        supported: supported,
      );
    }
  }

  if (collection['assets'] is Map) {
    collect(collection['assets'] as Map);
  }
  if (collectionAssetsJson != null) {
    final allAssets = jsonDecode(collectionAssetsJson);
    if (allAssets is Map && allAssets['assets'] is List) {
      for (final entry in (allAssets['assets'] as List).take(60)) {
        if (entry is Map && entry['id'] != null) {
          collect({entry['id'].toString(): entry});
        }
      }
    }
  }
  for (final item in items) {
    if (item is! Map || item['collection'] != mobileSiteCollectionId) {
      continue;
    }
    final props = item['properties'];
    if (props is Map) {
      final t = _time(props['datetime'] ?? props['updated']);
      if (t != null && (updated == null || t.isAfter(updated))) {
        updated = t;
      }
    }
    if (item['assets'] is Map) {
      collect(item['assets'] as Map);
    }
  }
  Uri? licenceUrl;
  final links = collection['links'];
  if (links is List) {
    for (final link in links) {
      if (link is Map && link['rel'] == 'license') {
        licenceUrl = _officialUrl(link['href']);
        break;
      }
    }
  }
  return MobileSiteCatalog(
    updatedUtc: updated,
    assets: List.unmodifiable(assets.values),
    licence: (collection['license'] ?? 'unknown').toString(),
    termsUrl: licenceUrl,
  );
}
