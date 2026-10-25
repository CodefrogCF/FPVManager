import 'dart:math' as math;

const offlineMapBudget = 256 * 1024 * 1024;

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
        !['topographic', 'relief'].contains(style) ||
        imageryLevel < 10 ||
        imageryLevel > 17 ||
        terrainLevel < 8 ||
        terrainLevel > 13 ||
        expectedTiles > 5000) {
      throw const FormatException(
        'Choose a smaller Swiss region (up to 5,000 tiles)',
      );
    }
  }
  final String id, name, style;
  final double west, south, east, north;
  final int imageryLevel, terrainLevel;
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
  };
  ({int left, int right, int bottom, int top}) range(
    int z, {
    required bool terrain,
  }) {
    final n = 1 << z;
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
  bool includesKey(String key) {
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
    if (!terrain && (parts.length != 5 || parts[1] != style)) return false;
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
