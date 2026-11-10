import 'dart:convert';

/// The six deliberately small, documented OSM categories supported by the app.
enum OsmPoiCategory {
  drinkingWater('Drinking water', 'amenity', 'drinking_water'),
  toilets('Toilets', 'amenity', 'toilets'),
  benches('Benches', 'amenity', 'bench'),
  playgrounds('Playgrounds', 'leisure', 'playground'),
  viewpoints('Viewpoints', 'tourism', 'viewpoint'),
  campsites('Campsites', 'tourism', 'camp_site');

  const OsmPoiCategory(this.label, this.tagKey, this.tagValue);
  final String label, tagKey, tagValue;

  bool matches(Map<String, String> tags) => tags[tagKey] == tagValue;
}

class OsmPoiSearch {
  OsmPoiSearch({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required Set<OsmPoiCategory> categories,
  }) : categories = Set.unmodifiable(categories) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        radiusMeters < 100 ||
        radiusMeters > 2000 ||
        categories.isEmpty ||
        categories.length > OsmPoiCategory.values.length) {
      throw const FormatException(
        'Select 1–6 categories and a radius of 100–2000 m around valid coordinates.',
      );
    }
  }

  final double latitude, longitude;
  final int radiusMeters;
  final Set<OsmPoiCategory> categories;

  String get identity =>
      '${latitude.toStringAsFixed(5)}|${longitude.toStringAsFixed(5)}|$radiusMeters|'
      '${(categories.map((c) => c.name).toList()..sort()).join(',')}';

  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radius': radiusMeters,
    'categories': categories.map((e) => e.name).toList(),
  };

  factory OsmPoiSearch.fromJson(Map<String, dynamic> data) => OsmPoiSearch(
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    radiusMeters: data['radius'] as int,
    categories: (data['categories'] as List)
        .map((e) => OsmPoiCategory.values.byName(e as String))
        .toSet(),
  );
}

class OsmPoi {
  OsmPoi({
    required this.type,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required Map<String, String> tags,
  }) : tags = Map.unmodifiable(tags) {
    if (!{'node', 'way', 'relation'}.contains(type) ||
        id <= 0 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        tags.length > 64) {
      throw const FormatException('Invalid OpenStreetMap element.');
    }
  }

  final String type;
  final int id;
  final double latitude, longitude;
  final OsmPoiCategory category;
  final Map<String, String> tags;

  String get reference => '$type/$id';
  Uri get sourceUrl => Uri.https('www.openstreetmap.org', '/$type/$id');
  String get name {
    final named = tags['name']?.trim();
    return named == null || named.isEmpty
        ? '${category.label} ($reference)'
        : named;
  }

  Map<String, Object> toJson() => {
    'type': type,
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'category': category.name,
    'tags': tags,
  };

  factory OsmPoi.fromJson(Map<String, dynamic> data) => OsmPoi(
    type: data['type'] as String,
    id: data['id'] as int,
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    category: OsmPoiCategory.values.byName(data['category'] as String),
    tags: Map<String, String>.from(data['tags'] as Map),
  );

  /// Only display provider-supplied attributes, never infer that a facility is open.
  Map<String, String> get suppliedDetails => {
    for (final key in [
      'access',
      'opening_hours',
      'wheelchair',
      'availability',
      'operational_status',
      'seasonal',
      'fee',
      'drinking_water',
    ])
      if (tags[key]?.trim().isNotEmpty ?? false) key: tags[key]!,
  };
}

class OsmPoiSnapshot {
  const OsmPoiSnapshot({
    required this.search,
    required this.fetchedAtUtc,
    required this.pois,
    required this.truncated,
    this.fromCache = false,
    this.fallbackToCache = false,
  });

  final OsmPoiSearch search;
  final DateTime fetchedAtUtc;
  final List<OsmPoi> pois;
  final bool truncated;
  final bool fromCache;
  final bool fallbackToCache;

  bool isOutdated(DateTime now) =>
      now.toUtc().difference(fetchedAtUtc.toUtc()) >= const Duration(hours: 24);

  OsmPoiSnapshot cached({bool fallback = false}) => OsmPoiSnapshot(
    search: search,
    fetchedAtUtc: fetchedAtUtc,
    pois: pois,
    truncated: truncated,
    fromCache: true,
    fallbackToCache: fallback,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'search': search.toJson(),
    'fetchedAtUtc': fetchedAtUtc.toUtc().toIso8601String(),
    'truncated': truncated,
    'pois': pois.map((p) => p.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  factory OsmPoiSnapshot.decode(String raw) {
    if (raw.length > 550000) {
      throw const FormatException('POI cache exceeds size limit.');
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported POI cache version.');
    }
    final values = data['pois'] as List;
    if (values.length > 300) {
      throw const FormatException('Too many cached POIs.');
    }
    return OsmPoiSnapshot(
      search: OsmPoiSearch.fromJson(
        Map<String, dynamic>.from(data['search'] as Map),
      ),
      fetchedAtUtc: DateTime.parse(data['fetchedAtUtc'] as String).toUtc(),
      pois: List.unmodifiable(
        values.map((e) => OsmPoi.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      truncated: data['truncated'] == true,
    );
  }
}

class OsmPoiParseResult {
  const OsmPoiParseResult(this.pois, {required this.truncated});
  final List<OsmPoi> pois;
  final bool truncated;
}

/// Overpass may return overlapping results from several selected tag filters.
/// Deduplicate by OSM type/id (not coordinates); relation/way centers are estimates.
OsmPoiParseResult parseOverpassPois(String raw, OsmPoiSearch search) {
  if (raw.length > 450000) {
    throw const FormatException('Overpass response too large.');
  }
  Object? document;
  try {
    document = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('Overpass returned invalid JSON.');
  }
  if (document is! Map || document['elements'] is! List) {
    throw const FormatException('Unexpected Overpass JSON response.');
  }
  if (document['remark'] is String &&
      (document['remark'] as String).trim().isNotEmpty) {
    throw const FormatException(
      'Overpass reported an incomplete or failed query; try a smaller area.',
    );
  }
  final elements = document['elements'] as List;
  if (elements.length > 301) {
    throw const FormatException('Overpass result cap exceeded.');
  }
  final found = <String, OsmPoi>{};
  for (final rawElement in elements) {
    if (rawElement is! Map) {
      continue;
    }
    final type = rawElement['type'];
    final id = rawElement['id'];
    if (type is! String ||
        !{'node', 'way', 'relation'}.contains(type) ||
        id is! int ||
        id <= 0) {
      continue;
    }
    final rawTags = rawElement['tags'];
    if (rawTags is! Map) {
      continue;
    }
    final tags = <String, String>{};
    for (final entry in rawTags.entries) {
      if (entry.key is String &&
          entry.value is String &&
          (entry.key as String).length <= 96 &&
          (entry.value as String).length <= 512 &&
          tags.length < 64) {
        tags[entry.key as String] = entry.value as String;
      }
    }
    OsmPoiCategory? category;
    for (final option in OsmPoiCategory.values) {
      if (search.categories.contains(option) && option.matches(tags)) {
        category = option;
        break;
      }
    }
    if (category == null) {
      continue;
    }
    final point = type == 'node' ? rawElement : rawElement['center'];
    if (point is! Map || point['lat'] is! num || point['lon'] is! num) {
      continue;
    }
    try {
      final poi = OsmPoi(
        type: type,
        id: id,
        latitude: (point['lat'] as num).toDouble(),
        longitude: (point['lon'] as num).toDouble(),
        category: category,
        tags: tags,
      );
      found.putIfAbsent(poi.reference, () => poi);
    } on FormatException {
      // Skip malformed elements, but retain other valid features.
    }
    if (found.length >= 300) {
      break;
    }
  }
  return OsmPoiParseResult(
    List.unmodifiable(found.values),
    truncated: elements.length >= 301 || found.length >= 300,
  );
}
