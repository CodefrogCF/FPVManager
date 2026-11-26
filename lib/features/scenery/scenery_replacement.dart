import 'dart:math' as math;

import 'scenery_manifest.dart';

/// Geographic replacement is explicit and independent of model bounding boxes.
Map<String, dynamic> validateSceneryReplacement(Object? value, Map anchor) {
  Map object(Object? v) {
    if (v is! Map) {
      throw const FormatException('Invalid replacement configuration');
    }
    return v;
  }

  double number(Object? v, double low, double high) {
    if (v is! num || !v.isFinite || v < low || v > high) {
      throw const FormatException('Invalid replacement number');
    }
    return v.toDouble();
  }

  List<List<List<double>>> regions(Object? v) {
    if (v is! List || v.length > 24) {
      throw const FormatException('Use at most 24 replacement regions');
    }
    return v.map((raw) {
      if (raw is! List || raw.length < 3 || raw.length > 64) {
        throw const FormatException('Use 3–64 vertices per region');
      }
      final polygon = raw.map((p) {
        if (p is! List || p.length != 2) {
          throw const FormatException('Expected [longitude, latitude]');
        }
        return [number(p[0], -180, 180), number(p[1], -90, 90)];
      }).toList();
      final lat = (anchor['latitude'] as num).toDouble(),
          rad = lat * math.pi / 180,
          w = math.sqrt(1 - .00669437999014 * math.sin(rad) * math.sin(rad)),
          east = 6378137 / w * math.cos(rad) * math.pi / 180,
          north =
              6378137 * (1 - .00669437999014) / math.pow(w, 3) * math.pi / 180;
      if (east.abs() < 100) {
        throw const FormatException('Replacement too close to pole');
      }
      final points = polygon.map((p) {
        final x =
                ((p[0] - (anchor['longitude'] as num) + 540) % 360 - 180) *
                east,
            y = (p[1] - lat) * north;
        if (math.sqrt(x * x + y * y) > 1000) {
          throw const FormatException(
            'Replacement region exceeds 1 km from anchor',
          );
        }
        return [x, y];
      }).toList();
      double cross(List<double> a, List<double> b, List<double> c) =>
          (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
      var area = 0.0;
      for (var i = 0; i < points.length; i++) {
        final a = points[i], b = points[(i + 1) % points.length];
        area += a[0] * b[1] - a[1] * b[0];
        if (math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2)) <
            .1) {
          throw const FormatException('Replacement vertices are too close');
        }
        for (var j = i + 2; j < points.length; j++) {
          if (i == 0 && j == points.length - 1) continue;
          final c = points[j], d = points[(j + 1) % points.length];
          final overlap =
              math.max(math.min(a[0], b[0]), math.min(c[0], d[0])) <=
                  math.min(math.max(a[0], b[0]), math.max(c[0], d[0])) &&
              math.max(math.min(a[1], b[1]), math.min(c[1], d[1])) <=
                  math.min(math.max(a[1], b[1]), math.max(c[1], d[1]));
          if (overlap &&
              cross(a, b, c) * cross(a, b, d) <= 0 &&
              cross(c, d, a) * cross(c, d, b) <= 0) {
            throw const FormatException('Self-intersecting replacement region');
          }
        }
      }
      if (area.abs() < 2 || area.abs() > 500000) {
        throw const FormatException('Invalid replacement region area');
      }
      return area < 0 ? polygon.reversed.toList() : polygon;
    }).toList();
  }

  final doc = object(value),
      buildings = object(doc['buildings']),
      terrain = object(doc['terrain']);
  if (doc['schemaVersion'] != 1 ||
      buildings['enabled'] is! bool ||
      terrain['enabled'] is! bool) {
    throw const FormatException('Unsupported replacement configuration');
  }
  final buildingRegions = regions(buildings['regions']);
  final rawFeatures = buildings['features'];
  if (rawFeatures is! List || rawFeatures.length > 128) {
    throw const FormatException('Use at most 128 building identifiers');
  }
  final seen = <String>{};
  final features = rawFeatures.map((v) {
    final f = object(v);
    if (!{'swisstopo', 'bkg'}.contains(f['provider']) ||
        f['property'] is! String ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_:.-]{0,127}$')
            .hasMatch(f['property'] as String) ||
        f['id'] is! String ||
        (f['id'] as String).trim().isEmpty ||
        (f['id'] as String).length > 256 ||
        !seen.add('${f['provider']}\n${f['property']}\n${f['id']}')) {
      throw const FormatException('Invalid or duplicate building identifier');
    }
    return {
      'provider': f['provider'],
      'property': f['property'],
      'id': f['id'],
    };
  }).toList();
  final rawTerrain = terrain['regions'];
  if (rawTerrain is! List || rawTerrain.length > 24) {
    throw const FormatException('Use at most 24 terrain regions');
  }
  final terrainRegions = rawTerrain.map((v) {
    final f = object(v),
        low = number(f['minimumUpM'], -100000, 100000),
        high = number(f['maximumUpM'], -100000, 100000);
    if (high <= low) {
      throw const FormatException('Invalid physical ground height range');
    }
    return {
      'polygon': regions([f['polygon']]).single,
      'minimumUpM': low,
      'maximumUpM': high,
      'seamToleranceM': number(f['seamToleranceM'], .05, .5),
    };
  }).toList();
  if (buildings['enabled'] == true &&
          buildingRegions.isEmpty &&
          features.isEmpty ||
      terrain['enabled'] == true && terrainRegions.isEmpty) {
    throw const FormatException(
      'Enabled replacement requires a region or building identifier',
    );
  }
  return {
    'schemaVersion': 1,
    'buildings': {
      'enabled': buildings['enabled'],
      'regions': buildingRegions,
      'features': features,
    },
    'terrain': {'enabled': terrain['enabled'], 'regions': terrainRegions},
  };
}

Map<String, dynamic> emptySceneryReplacement() => {
  'schemaVersion': 1,
  'buildings': {
    'enabled': false,
    'regions': <Object>[],
    'features': <Object>[],
  },
  'terrain': {'enabled': false, 'regions': <Object>[]},
};

SceneryManifest configureSceneryReplacement(
  SceneryManifest base,
  Object? replacement,
) {
  final doc = base.toJson();
  doc['replacement'] = validateSceneryReplacement(
    replacement,
    doc['anchor'] as Map,
  );
  return SceneryManifest.fromJson(doc);
}
