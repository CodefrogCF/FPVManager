import 'dart:math' as math;

/// WGS84 ECEF bounds after the same ENU / heading-pitch-roll transform as Cesium.
/// For terrain-relative anchors an absolute result needs a real ground sample.
Map<String, dynamic> transformedSceneryBounds(
  Map<String, dynamic> doc, {
  double? terrainHeightM,
}) {
  final a = doc['anchor'] as Map, r = doc['rotation'] as Map;
  if (a['reference'] == 'TERRAIN_RELATIVE' && terrainHeightM == null) {
    return {'reference': 'TERRAIN_RELATIVE', 'pendingTerrain': true};
  }
  final lon = (a['longitude'] as num) * math.pi / 180,
      lat = (a['latitude'] as num) * math.pi / 180;
  final height = (a['heightM'] as num).toDouble() + (terrainHeightM ?? 0);
  final sl = math.sin(lon),
      cl = math.cos(lon),
      sp = math.sin(lat),
      cp = math.cos(lat);
  const e2 = 6.6943799901413165e-3;
  final n = 6378137 / math.sqrt(1 - e2 * sp * sp);
  final origin = [
    (n + height) * cp * cl,
    (n + height) * cp * sl,
    (n * (1 - e2) + height) * sp,
  ];
  // Cesium builds ENU from the geodetic normal of the ECEF anchor, including
  // its height, rather than using the latitude's zero-height normal directly.
  final normal = [origin[0], origin[1], origin[2] / (1 - e2)];
  final normalLength = math.sqrt(
    normal.fold<double>(0, (sum, v) => sum + v * v),
  );
  for (var i = 0; i < 3; i++) {
    normal[i] /= normalLength;
  }
  final northFrame = [
    -normal[2] * cl,
    -normal[2] * sl,
    normal[0] * cl + normal[1] * sl,
  ];
  final h = -(r['headingDeg'] as num) * math.pi / 180,
      p = -(r['pitchDeg'] as num) * math.pi / 180,
      roll = (r['rollDeg'] as num) * math.pi / 180;
  final min = List<double>.filled(3, double.infinity),
      max = List<double>.filled(3, double.negativeInfinity);
  var radius = 0.0;
  for (final asset in doc['assets'] as List) {
    final bounds = (asset as Map)['model']?['localBounds'];
    if (bounds is! List) continue;
    for (var mask = 0; mask < 8; mask++) {
      final v = [
        for (var j = 0; j < 3; j++)
          (bounds[j + ((mask & (1 << j)) == 0 ? 0 : 3)] as num) *
              (doc['scale'] as num),
      ];
      final x = v[0],
          y = math.cos(roll) * v[1] - math.sin(roll) * v[2],
          z = math.sin(roll) * v[1] + math.cos(roll) * v[2];
      final xx = math.cos(p) * x + math.sin(p) * z,
          zz = -math.sin(p) * x + math.cos(p) * z;
      final east = math.cos(h) * xx - math.sin(h) * y,
          north = math.sin(h) * xx + math.cos(h) * y,
          up = zz;
      final ecef = [
        origin[0] - sl * east + northFrame[0] * north + normal[0] * up,
        origin[1] + cl * east + northFrame[1] * north + normal[1] * up,
        origin[2] + northFrame[2] * north + normal[2] * up,
      ];
      for (var j = 0; j < 3; j++) {
        min[j] = math.min(min[j], ecef[j]);
        max[j] = math.max(max[j], ecef[j]);
      }
      radius = math.max(
        radius,
        math.sqrt(east * east + north * north + up * up),
      );
    }
  }
  if (min.any((v) => !v.isFinite)) return {};
  return {
    'reference': 'WGS84_ECEF',
    'minimum': min,
    'maximum': max,
    'sphere': {'center': origin, 'radiusM': radius},
  };
}
