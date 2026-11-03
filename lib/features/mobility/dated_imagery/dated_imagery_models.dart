import 'dart:convert';

/// All sources here are historical/delayed acquisitions, never live imagery.
enum DatedImageryProduct {
  swissEo('ch.swisstopo.swisseo_s2-sr_v200', 'swissEO Sentinel-2 (v200)'),
  rapidMapping('ch.swisstopo.spezialbefliegungen', 'Rapid Mapping (events)');

  const DatedImageryProduct(this.collection, this.label);
  final String collection, label;
}

enum DatedImageryRenderKind { swissEoWms, rapidCog, externalOnly }

class ImageryAsset {
  const ImageryAsset({
    required this.key,
    required this.href,
    required this.type,
    required this.renderKind,
    this.projection,
  });
  final String key, href, type;
  final DatedImageryRenderKind renderKind;
  final int? projection;

  Map<String, Object?> toJson() => {
    'key': key,
    'href': href,
    'type': type,
    'kind': renderKind.name,
    'projection': projection,
  };

  factory ImageryAsset.fromJson(Map<String, dynamic> json) => ImageryAsset(
    key: json['key'] as String,
    href: json['href'] as String,
    type: json['type'] as String,
    renderKind: DatedImageryRenderKind.values.byName(json['kind'] as String),
    projection: json['projection'] as int?,
  );
}

class DatedImageryItem {
  const DatedImageryItem({
    required this.product,
    required this.id,
    required this.acquiredUtc,
    required this.bbox,
    required this.title,
    required this.assets,
    this.publishedUtc,
    this.missionContext,
    this.cloudCoverPercent,
    this.viewerUrl,
    this.qualityAssetAvailable = false,
  });
  final DatedImageryProduct product;
  final String id, title;
  final String? missionContext, viewerUrl;
  final DateTime acquiredUtc;
  final DateTime? publishedUtc;

  /// Longitude/latitude WGS84 [west, south, east, north]; never LV95.
  final List<double> bbox;
  final double? cloudCoverPercent;
  final bool qualityAssetAvailable;
  final List<ImageryAsset> assets;

  ImageryAsset? get displayAsset {
    for (final asset in assets) {
      if (asset.renderKind != DatedImageryRenderKind.externalOnly) {
        return asset;
      }
    }
    return null;
  }

  bool covers(double latitude, double longitude) =>
      longitude >= bbox[0] &&
      longitude <= bbox[2] &&
      latitude >= bbox[1] &&
      latitude <= bbox[3];

  Map<String, Object?> toJson() => {
    'product': product.name,
    'id': id,
    'acquiredUtc': acquiredUtc.toIso8601String(),
    'publishedUtc': publishedUtc?.toIso8601String(),
    'bbox': bbox,
    'title': title,
    'missionContext': missionContext,
    'cloudCoverPercent': cloudCoverPercent,
    'viewerUrl': viewerUrl,
    'qualityAssetAvailable': qualityAssetAvailable,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  factory DatedImageryItem.fromJson(
    Map<String, dynamic> json,
  ) => DatedImageryItem(
    product: DatedImageryProduct.values.byName(json['product'] as String),
    id: json['id'] as String,
    title: json['title'] as String,
    acquiredUtc: DateTime.parse(json['acquiredUtc'] as String).toUtc(),
    publishedUtc: _optionalDate(json['publishedUtc']),
    bbox: (json['bbox'] as List).cast<num>().map((n) => n.toDouble()).toList(),
    missionContext: json['missionContext'] as String?,
    cloudCoverPercent: (json['cloudCoverPercent'] as num?)?.toDouble(),
    viewerUrl: json['viewerUrl'] as String?,
    qualityAssetAvailable: json['qualityAssetAvailable'] == true,
    assets: (json['assets'] as List)
        .map((a) => ImageryAsset.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList(),
  );
}

DateTime? _optionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

class DatedImagerySnapshot {
  const DatedImagerySnapshot({
    required this.product,
    required this.fetchedUtc,
    required this.area,
    required this.items,
    required this.incomplete,
    this.fromCache = false,
    this.refreshFailed = false,
  });
  final DatedImageryProduct product;
  final DateTime fetchedUtc;
  final List<double> area;
  final List<DatedImageryItem> items;
  final bool incomplete, fromCache, refreshFailed;

  bool get isEmpty => items.isEmpty;
  bool isOld(DateTime now) =>
      now.toUtc().difference(fetchedUtc) > const Duration(hours: 24) ||
      now.toUtc().isBefore(fetchedUtc);

  DatedImagerySnapshot saved({bool failed = false}) => DatedImagerySnapshot(
    product: product,
    fetchedUtc: fetchedUtc,
    area: area,
    items: items,
    incomplete: incomplete,
    fromCache: true,
    refreshFailed: failed,
  );

  String encode() => jsonEncode({
    'product': product.name,
    'fetchedUtc': fetchedUtc.toIso8601String(),
    'area': area,
    'items': items.map((item) => item.toJson()).toList(),
    'incomplete': incomplete,
  });

  factory DatedImagerySnapshot.decode(String json) {
    if (utf8.encode(json).length > 100000) {
      throw const FormatException('Saved imagery metadata is too large');
    }
    final obj = jsonDecode(json);
    if (obj is! Map<String, dynamic>) {
      throw const FormatException('Invalid imagery metadata');
    }
    final product = DatedImageryProduct.values.byName(obj['product'] as String);
    final area = (obj['area'] as List)
        .cast<num>()
        .map((n) => n.toDouble())
        .toList();
    if (!_validBounds(area)) {
      throw const FormatException('Invalid cached bounds');
    }
    final raw = obj['items'] as List;
    if (raw.length > 16) {
      throw const FormatException('Too many cached images');
    }
    final items = raw
        .map(
          (e) => DatedImageryItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    if (items.any((i) => i.product != product || !_validBounds(i.bbox))) {
      throw const FormatException('Inconsistent cached images');
    }
    return DatedImagerySnapshot(
      product: product,
      fetchedUtc: DateTime.parse(obj['fetchedUtc'] as String).toUtc(),
      area: area,
      items: items,
      incomplete: obj['incomplete'] == true,
    );
  }
}

bool _validBounds(List<double> b) =>
    b.length == 4 &&
    b.every((n) => n.isFinite) &&
    b[0] >= -180 &&
    b[2] <= 180 &&
    b[1] >= -90 &&
    b[3] <= 90 &&
    b[0] < b[2] &&
    b[1] < b[3];

/// Strictly bounded STAC parser; the server may paginate and an empty page
/// cannot prove the surrounding region has no imagery.
DatedImagerySnapshot parseDatedImageryStac(
  String collectionBody,
  String itemsBody, {
  required DatedImageryProduct product,
  required DateTime fetchedUtc,
  required List<double> requestedBounds,
}) {
  if (utf8.encode(collectionBody).length > 100000 ||
      utf8.encode(itemsBody).length > 650000 ||
      !_validBounds(requestedBounds)) {
    throw const FormatException('Unbounded or invalid STAC metadata');
  }
  final collection = jsonDecode(collectionBody);
  final page = jsonDecode(itemsBody);
  if (collection is! Map ||
      collection['id'] != product.collection ||
      page is! Map ||
      page['features'] is! List) {
    throw const FormatException('Wrong STAC collection or item document');
  }
  final features = page['features'] as List;
  if (features.length > 16) {
    throw const FormatException('Too many STAC items');
  }
  final output = <DatedImageryItem>[];
  final ids = <String>{};
  for (final raw in features) {
    if (raw is! Map ||
        raw['collection'] != product.collection ||
        raw['id'] is! String ||
        raw['properties'] is! Map) {
      continue;
    }
    final id = (raw['id'] as String).trim();
    if (id.isEmpty || id.length > 160 || !ids.add(id)) {
      continue;
    }
    if (product == DatedImageryProduct.rapidMapping && !id.startsWith('ram-')) {
      continue; // Other special-flight imagery is NOT a Rapid Mapping mission.
    }
    final b = raw['bbox'];
    if (b is! List ||
        !(b.length == 4 || b.length == 6) ||
        b.any((n) => n is! num)) {
      continue;
    }
    final values = b.cast<num>();
    final bounds =
        (b.length == 4
                ? [values[0], values[1], values[2], values[3]]
                : [values[0], values[1], values[3], values[4]])
            .map((n) => n.toDouble())
            .toList();
    if (!_validBounds(bounds) || !boxesOverlap(bounds, requestedBounds)) {
      continue;
    }
    final props = raw['properties'] as Map;
    final acquired =
        _optionalDate(props['datetime']) ??
        _optionalDate(props['start_datetime']);
    if (acquired == null) {
      continue; // Never invent acquisition from a fetch date.
    }
    final published =
        _optionalDate(props['published']) ??
        _optionalDate(props['created']) ??
        _optionalDate(props['updated']);
    final title = _safeLabel(props['title'], fallback: id);
    final context = product == DatedImageryProduct.rapidMapping
        ? _safeLabel(
            props['description'] ?? props['event'] ?? props['mission'],
            fallback: 'Ereignis nicht angegeben',
          )
        : null;
    final assets = _parseAssets(
      raw['assets'],
      product,
      fallbackProjection: props['proj:epsg'] is int
          ? props['proj:epsg'] as int
          : null,
    );
    if (product == DatedImageryProduct.swissEo) {
      // WMS is documented for every v200 acquisition; the selected date is
      // derived from the STAC acquisition timestamp, never from a guessed id.
      assets.insert(
        0,
        ImageryAsset(
          key: 'official-true-colour-wms',
          href: 'https://wms.geo.admin.ch/',
          type: 'image/png',
          renderKind: DatedImageryRenderKind.swissEoWms,
        ),
      );
    }
    final cloud = props['eo:cloud_cover'];
    final links = raw['links'];
    String? viewer;
    if (links is List) {
      for (final link in links) {
        if (link is Map && {'alternate', 'preview'}.contains(link['rel'])) {
          final url = Uri.tryParse('${link['href']}');
          if (url != null &&
              url.scheme == 'https' &&
              (url.host == 'map.geo.admin.ch' ||
                  url.host == 'www.swisstopo.admin.ch')) {
            viewer = url.toString();
            break;
          }
        }
      }
    }
    output.add(
      DatedImageryItem(
        product: product,
        id: id,
        title: title,
        acquiredUtc: acquired,
        publishedUtc: published,
        bbox: bounds,
        missionContext: context,
        cloudCoverPercent:
            cloud is num && cloud.isFinite && cloud >= 0 && cloud <= 100
            ? cloud.toDouble()
            : null,
        qualityAssetAvailable: assets.any(
          (a) => RegExp(
            'cloudmask|scl|quality',
            caseSensitive: false,
          ).hasMatch(a.key),
        ),
        viewerUrl: viewer,
        assets: assets,
      ),
    );
  }
  output.sort((a, b) => b.acquiredUtc.compareTo(a.acquiredUtc));
  return DatedImagerySnapshot(
    product: product,
    fetchedUtc: fetchedUtc.toUtc(),
    area: requestedBounds,
    items: output,
    incomplete:
        features.length == 16 ||
        page['links'] is List &&
            (page['links'] as List).any((l) => l is Map && l['rel'] == 'next'),
  );
}

bool boxesOverlap(List<double> a, List<double> b) =>
    a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];

String _safeLabel(Object? value, {required String fallback}) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty
      ? fallback
      : text.length <= 240
      ? text
      : '${text.substring(0, 240)}…';
}

List<ImageryAsset> _parseAssets(
  Object? raw,
  DatedImageryProduct product, {
  int? fallbackProjection,
}) {
  if (raw is! Map) {
    return [];
  }
  final results = <ImageryAsset>[];
  for (final entry in raw.entries.take(32)) {
    if (entry.key is! String || entry.value is! Map) {
      continue;
    }
    final key = entry.key as String;
    if (key.length > 64) {
      continue;
    }
    final asset = entry.value as Map;
    final value = asset['href'];
    if (value is! String || value.length > 650) {
      continue;
    }
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        !(url.host == 'data.geo.admin.ch' ||
            url.host == 'download.geo.admin.ch')) {
      continue; // No untrusted STAC endpoint may be sent to the browser.
    }
    final type = '${asset['type'] ?? ''}'.toLowerCase();
    final projection = asset['proj:epsg'] is int
        ? asset['proj:epsg'] as int
        : fallbackProjection;
    final isTiff =
        type.contains('tiff') ||
        url.path.toLowerCase().endsWith('.tif') ||
        url.path.toLowerCase().endsWith('.tiff');
    // No elevation models, oblique photos, raw bands or ungeoreferenced images.
    final optical = RegExp(
      'ortho|qdop|dop|rgb|tci',
      caseSensitive: false,
    ).hasMatch(key);
    final render =
        product == DatedImageryProduct.rapidMapping &&
            isTiff &&
            optical &&
            {2056, 4326}.contains(projection)
        ? DatedImageryRenderKind.rapidCog
        : DatedImageryRenderKind.externalOnly;
    // Limit the stored catalogue record even for STAC items with hundreds
    // of source files. Retain the first compatible optical asset and a few
    // source/quality references, not a complete download manifest.
    if (results.length >= 6 && render == DatedImageryRenderKind.externalOnly) {
      continue;
    }
    if (render != DatedImageryRenderKind.externalOnly) {
      results.insert(
        0,
        ImageryAsset(
          key: key,
          href: value,
          type: type.length > 120 ? type.substring(0, 120) : type,
          projection: projection,
          renderKind: render,
        ),
      );
      if (results.length > 6) {
        results.removeLast();
      }
    } else {
      results.add(
        ImageryAsset(
          key: key,
          href: value,
          type: type.length > 120 ? type.substring(0, 120) : type,
          projection: projection,
          renderKind: render,
        ),
      );
    }
  }
  return results;
}

/// Official documented time identifier for the swissEO WMS item parameter.
String swissEoWmsTime(DateTime acquisition) {
  final utc = acquisition.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
      't${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}
