import 'dart:math' as math;

const offlineMapBudget = 256 * 1024 * 1024;
// Version-one prepared meshes: 65 x 65 vertices, triangles and four edges.
const offlinePreparedMeshBytes = 75134;

class OfflineRegion {
  OfflineRegion({
    required this.id,
    required this.name,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    this.style = 'topographic',
    this.imageryLevel = 14,
    this.terrainLevel = 12,
    this.packageId,
    this.packageActive = false,
    this.preparedAt,
    this.packageTiles,
    this.sourceDates,
    this.provenance,
    this.preparationVersion,
    this.maps,
    this.includeTerrain = true,
    this.scope,
    this.radiusKm,
    this.centerLatitude,
    this.centerLongitude,
  }) {
    if (id.isEmpty ||
        id.length > 100 ||
        name.trim().isEmpty ||
        name.length > 80 ||
        ![west, south, east, north].every((v) => v.isFinite) ||
        west < 5.8 ||
        east > 10.7 ||
        south < 45.6 ||
        north > 48 ||
        west >= east ||
        south >= north ||
        !['topographic', 'relief', 'satellite'].contains(style) ||
        preparationVersion != null && preparationVersion != 2 ||
        preparationVersion == 2 &&
            (!['radius', 'switzerland'].contains(scope) ||
                maps == null ||
                maps!.isEmpty && !includeTerrain ||
                scope == 'radius' &&
                    (radiusKm == null ||
                        !radiusKm!.isFinite ||
                        radiusKm! <= 0 ||
                        radiusKm! > 25 ||
                        centerLatitude == null ||
                        !centerLatitude!.isFinite ||
                        centerLongitude == null ||
                        !centerLongitude!.isFinite)) ||
        maps != null &&
            (maps!.length > 3 ||
                maps!.toSet().length != maps!.length ||
                maps!.any(
                  (m) => !['topographic', 'relief', 'satellite'].contains(m),
                )) ||
        imageryLevel < 10 ||
        imageryLevel > 17 ||
        terrainLevel < 8 ||
        terrainLevel > 16 ||
        packageId != null &&
            (!RegExp(r'^[0-9a-f]{64}$').hasMatch(packageId!) ||
                preparedAt == null ||
                packageTiles == null ||
                packageTiles! < 1 ||
                packageTiles! > (preparationVersion == 2 ? 2000000 : 5000)) ||
        packageActive && packageId == null ||
        preparationVersion != 2 && expectedTiles > 5000) {
      throw const FormatException(
        'Choose a smaller Swiss region (up to 5,000 tiles)',
      );
    }
  }
  final String id, name, style;
  final double west, south, east, north;
  final int imageryLevel, terrainLevel;
  final String? packageId;
  final bool packageActive;
  final DateTime? preparedAt;
  final int? packageTiles;
  final String? sourceDates;
  final Map<String, dynamic>? provenance;
  final int? preparationVersion;
  final List<String>? maps;
  final bool includeTerrain;
  final String? scope;
  final double? radiusKm, centerLatitude, centerLongitude;
  factory OfflineRegion.fromJson(Map<String, dynamic> j) => OfflineRegion(
    id: j['id'] as String,
    name: j['name'] as String,
    west: (j['west'] as num).toDouble(),
    south: (j['south'] as num).toDouble(),
    east: (j['east'] as num).toDouble(),
    north: (j['north'] as num).toDouble(),
    style: j['style'] as String,
    imageryLevel: j['imageryLevel'] as int,
    terrainLevel: j['terrainLevel'] as int,
    packageId: j['packageId'] as String?,
    packageActive: j['packageActive'] == true,
    preparedAt: j['preparedAtUtc'] == null
        ? null
        : DateTime.parse(j['preparedAtUtc'] as String).toUtc(),
    packageTiles: j['packageTiles'] as int?,
    sourceDates: j['sourceDates'] as String?,
    provenance: j['provenance'] == null
        ? null
        : Map<String, dynamic>.from(j['provenance'] as Map),
    preparationVersion: j['preparationVersion'] as int?,
    maps: (j['maps'] as List?)?.cast<String>(),
    includeTerrain: j['includeTerrain'] != false,
    scope: j['scope'] as String?,
    radiusKm: (j['radiusKm'] as num?)?.toDouble(),
    centerLatitude: (j['centerLatitude'] as num?)?.toDouble(),
    centerLongitude: (j['centerLongitude'] as num?)?.toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'west': west,
    'south': south,
    'east': east,
    'north': north,
    'style': style,
    'imageryLevel': imageryLevel,
    'terrainLevel': terrainLevel,
    if (preparationVersion != null) ...{
      'preparationVersion': preparationVersion,
      'maps': maps,
      'includeTerrain': includeTerrain,
      'scope': scope,
      'radiusKm': radiusKm,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
    },
    if (packageId != null) ...{
      'packageId': packageId,
      'packageActive': packageActive,
      'preparedAtUtc': preparedAt!.toIso8601String(),
      'packageTiles': packageTiles,
      if (sourceDates != null) 'sourceDates': sourceDates,
      if (provenance != null) 'provenance': provenance,
    },
  };
  OfflineRegion withPackageActive(bool active) =>
      OfflineRegion.fromJson({...toJson(), 'packageActive': active});
  ({int left, int right, int bottom, int top}) range(
    int z, {
    required bool terrain,
  }) {
    final n = 1 << z;
    if (packageId != null) {
      double px(double lon) => (lon + 180) / 360 * (terrain ? 2 * n : n);
      double py(double lat) => terrain
          ? (lat + 90) / 180 * n
          : (1 -
                    math.log(
                          math.tan(lat * math.pi / 180) +
                              1 / math.cos(lat * math.pi / 180),
                        ) /
                        math.pi) /
                2 *
                n;
      return (
        left: px(west).floor(),
        right: px(east).ceil() - 1,
        bottom: math.min(py(south), py(north)).floor(),
        top: math.max(py(south), py(north)).ceil() - 1,
      );
    }
    int x(double lon) => (((lon + 180) / 360) * (terrain ? 2 * n : n)).floor();
    int y(double lat) => terrain
        ? ((lat + 90) / 180 * n).floor()
        : ((1 -
                      math.log(
                            math.tan(lat * math.pi / 180) +
                                1 / math.cos(lat * math.pi / 180),
                          ) /
                          math.pi) /
                  2 *
                  n)
              .floor();
    return (
      left: x(west),
      right: x(east),
      bottom: math.min(y(south), y(north)),
      top: math.max(y(south), y(north)),
    );
  }

  int get expectedTiles {
    var count = 2; // metadata and the western probe root outside Swiss bounds
    for (final terrain in [false, true]) {
      for (var z = 0; z <= (terrain ? terrainLevel : imageryLevel); z++) {
        final r = range(z, terrain: terrain);
        count += (r.right - r.left + 1) * (r.top - r.bottom + 1);
      }
    }
    return count;
  }

  int get estimatedBytes => expectedTiles * 45 * 1024;
  int get preparedTerrainBytes {
    var count = 0;
    for (var z = 0; z <= terrainLevel; z++) {
      final r = range(z, terrain: true);
      count += (r.right - r.left + 1) * (r.top - r.bottom + 1);
    }
    return count * offlinePreparedMeshBytes;
  }

  int get preparedEstimatedBytes =>
      preparedTerrainBytes +
      (expectedTiles - 2 - preparedTerrainBytes ~/ offlinePreparedMeshBytes) *
          45 *
          1024 +
      64 * 1024;
  bool includesKey(String key) {
    if (packageId != null) {
      final prefix = 'prepared/$packageId/';
      if (!key.startsWith(prefix)) return false;
      key = key.substring(prefix.length);
      if (preparationVersion == 2 &&
          RegExp(r'^sources/\d{1,4}\.json$').hasMatch(key)) {
        return true;
      }
    } else if (key.startsWith('prepared/')) {
      return false;
    }
    if (key == 'terrain/layer.json' || key == 'terrain/0/0/0.terrain') {
      return true;
    }
    final parts = key.split('/'), terrain = parts.first == 'terrain';
    if (terrain &&
        parts.length == 5 &&
        RegExp(r'^20[0-9]{6}$').hasMatch(parts[1])) {
      parts.removeAt(1);
    }
    if (terrain && parts.join('/') == 'terrain/0/0/0.terrain') return true;
    if (terrain && parts.length != 4) return false;
    if (!terrain &&
        (parts.length != 5 || !(maps ?? [style]).contains(parts[1]))) {
      return false;
    }
    final z = int.tryParse(parts[terrain ? 1 : 2]) ?? -1;
    if (z < 0 || z > (terrain ? terrainLevel : imageryLevel)) return false;
    final x = int.tryParse(parts[terrain ? 2 : 3]) ?? -1,
        y = int.tryParse(parts.last.split('.').first) ?? -1;
    final r = range(z, terrain: terrain);
    return x >= r.left && x <= r.right && y >= r.bottom && y <= r.top;
  }
}

class OfflineTileInfo {
  const OfflineTileInfo(this.key, this.bytes, this.fetchedAt);
  final String key;
  final int bytes;
  final DateTime fetchedAt;
}

abstract interface class OfflineMapStorage {
  bool get rendererReady;
  Future<List<OfflineRegion>> regions();
  Future<void> setRegions(List<OfflineRegion> regions);
  Future<List<OfflineTileInfo>> tiles();
  Future<void> clear();
  Future<void> close();
}
