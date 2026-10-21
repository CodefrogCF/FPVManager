import 'dart:math' as math;

enum ObstacleCategory { powerLines, cableways, masts, other, unknown }

extension ObstacleCategoryLabel on ObstacleCategory {
  String get label => switch (this) {
    ObstacleCategory.powerLines => 'Power lines',
    ObstacleCategory.cableways => 'Cableways / ropes',
    ObstacleCategory.masts => 'Towers / masts',
    ObstacleCategory.other => 'Other obstacles',
    ObstacleCategory.unknown => 'Unknown classification',
  };
}

ObstacleCategory classifyObstacle(String type) => switch (type.toUpperCase()) {
  'TRANSMISSION_LINE' => ObstacleCategory.powerLines,
  'CABLE_CAR' || 'CATENARY' => ObstacleCategory.cableways,
  'POLE' || 'TOWER' || 'MAST' => ObstacleCategory.masts,
  'BRIDGE' ||
  'BUILDING' ||
  'CRANE' ||
  'STACK' ||
  'VEGETATION' ||
  'WINDMILL' ||
  'OTHER' => ObstacleCategory.other,
  _ => ObstacleCategory.unknown,
};

/// Source coordinates and modes are retained even when no elevated display is
/// possible. Only the official Swiss dataset maps `absolute` to LN02 (DPS 5).
class ObstaclePart {
  const ObstaclePart(this.kind, this.mode, this.coordinates);
  final String kind;
  final String mode;
  final List<List<double>> coordinates;
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'mode': mode,
    'coordinates': coordinates,
  };
  factory ObstaclePart.fromJson(Map<String, dynamic> j) => ObstaclePart(
    j['kind'] as String,
    j['mode'] as String,
    (j['coordinates'] as List)
        .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
        .toList(),
  );
}

class ObstacleFeature {
  ObstacleFeature({
    required this.id,
    required this.name,
    required this.attributes,
    required this.parts,
  }) {
    final points = parts.expand((part) => part.coordinates);
    west = points.map((p) => p[0]).reduce(math.min);
    east = points.map((p) => p[0]).reduce(math.max);
    south = points.map((p) => p[1]).reduce(math.min);
    north = points.map((p) => p[1]).reduce(math.max);
  }
  final String id, name;
  final Map<String, String> attributes;
  final List<ObstaclePart> parts;
  late final double west, east, south, north;
  String get sourceType => attributes['obstacleType'] ?? '';
  ObstacleCategory get category => classifyObstacle(sourceType);
  bool get approximate => parts.any((p) => p.kind != 'Point');
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attributes': attributes,
    'parts': parts.map((p) => p.toJson()).toList(),
  };
  factory ObstacleFeature.fromJson(Map<String, dynamic> j) => ObstacleFeature(
    id: j['id'] as String,
    name: j['name'] as String,
    attributes: Map<String, String>.from(j['attributes'] as Map),
    parts: (j['parts'] as List)
        .map((p) => ObstaclePart.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
  );
}

class ObstacleSnapshot {
  const ObstacleSnapshot({
    required this.key,
    required this.assetUrl,
    required this.checksum,
    required this.sourceUpdated,
    required this.fetchedAt,
    required this.checkedAt,
    required this.count,
    required this.skipped,
    required this.metadata,
  });
  final String key, assetUrl, checksum;
  final DateTime? sourceUpdated;
  final DateTime fetchedAt, checkedAt;
  final int count, skipped;
  final Map<String, String> metadata;
  Map<String, dynamic> toJson() => {
    'key': key,
    'assetUrl': assetUrl,
    'checksum': checksum,
    'sourceUpdated': sourceUpdated?.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'checkedAt': checkedAt.toIso8601String(),
    'count': count,
    'skipped': skipped,
    'metadata': metadata,
  };
  factory ObstacleSnapshot.fromJson(Map<String, dynamic> j) => ObstacleSnapshot(
    key: j['key'] as String,
    assetUrl: j['assetUrl'] as String,
    checksum: j['checksum'] as String,
    sourceUpdated: DateTime.tryParse(j['sourceUpdated'] as String? ?? ''),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    checkedAt: DateTime.parse(j['checkedAt'] as String),
    count: j['count'] as int,
    skipped: j['skipped'] as int,
    metadata: Map<String, String>.from(j['metadata'] as Map),
  );
}

class ObstacleViewport {
  const ObstacleViewport(this.west, this.south, this.east, this.north);
  final double west, south, east, north;
  bool get isLocal =>
      west <= east && east - west <= 0.6 && north - south <= 0.6;
}
