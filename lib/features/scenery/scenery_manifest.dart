import 'dart:convert';
import 'dart:math' as math;

import '../../core/geo/geo_coordinate_service.dart';
import 'scenery_model_bounds.dart';
import 'scenery_storage.dart';
import 'scenery_replacement.dart';
import 'scenery_tileset_options.dart';

/// Application-independent scenery definition. Provider-specific calibration
/// stays in extensions; asset bytes and runtime readiness never enter the DB.
final class SceneryManifest {
  SceneryManifest._(this._json);
  static const schemaVersion = 1;
  static const maxBytes = 128 * 1024;
  final Map<String, dynamic> _json;

  String get id => _json['id'] as String;
  String get name => _json['name'] as String;
  bool get enabled => (_json['visibility'] as Map)['enabled'] as bool;
  List<SceneryAsset> get assets => List.unmodifiable(
    (_json['assets'] as List).map((v) => SceneryAsset.fromJson(v)),
  );
  VerticalReference get verticalReference =>
      (_json['anchor'] as Map)['reference'] == 'WGS84_ELLIPSOID'
      ? VerticalReference.wgs84Ellipsoid
      : VerticalReference.unverified;
  FlightAltitudeMode get altitudeMode =>
      (_json['anchor'] as Map)['reference'] == 'TERRAIN_RELATIVE'
      ? FlightAltitudeMode.aboveGroundLevel
      : FlightAltitudeMode.absolute;
  Map<String, dynamic> toJson() => _clone(_json);

  factory SceneryManifest.fromJson(Object? value) {
    final doc = _clone(_map(value));
    if (utf8.encode(jsonEncode(doc)).length > maxBytes) {
      throw const FormatException('Scenery manifest exceeds size limit');
    }
    if (doc['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported scenery manifest version');
    }
    _identifier(doc['id']);
    _text(doc['name'], 120);
    _text(doc['description'], 4096, empty: true);
    final source = _map(doc['source']);
    for (final key in ['author', 'license', 'attribution']) {
      _text(source[key], 2048);
    }
    if (source['url'] != null) _https(source['url']);
    final anchor = _map(doc['anchor']);
    _number(anchor['longitude'], -180, 180);
    _number(anchor['latitude'], -90, 90);
    _number(anchor['heightM'], -10000, 20000);
    if (!{
      'WGS84_ELLIPSOID',
      'TERRAIN_RELATIVE',
    }.contains(anchor['reference'])) {
      throw const FormatException('Unsupported scenery altitude reference');
    }
    final bounds = _map(doc['bounds']);
    for (final key in ['west', 'east']) {
      _number(bounds[key], -180, 180);
    }
    for (final key in ['south', 'north']) {
      _number(bounds[key], -90, 90);
    }
    if ((bounds['south'] as num) > (bounds['north'] as num)) {
      throw const FormatException('Invalid scenery bounds');
    }
    final rotation = _map(doc['rotation']);
    _number(rotation['headingDeg'], -360, 360);
    _number(rotation['pitchDeg'], -90, 90);
    _number(rotation['rollDeg'], -180, 180);
    _number(doc['scale'], .01, 1000);
    final rawAssets = doc['assets'];
    if (rawAssets is! List || rawAssets.isEmpty || rawAssets.length > 32) {
      throw const FormatException('Invalid scenery assets');
    }
    final assets = rawAssets.map(SceneryAsset.fromJson).toList();
    if (assets.any((a) => a.provider == remoteTilesetProvider) &&
        anchor['reference'] != 'WGS84_ELLIPSOID') {
      throw const FormatException(
        'Georeferenced tilesets require an absolute correction pivot',
      );
    }
    final ids = assets.map((a) => a.id).toSet();
    if (ids.length != assets.length ||
        !assets.any((a) => a.role == 'visual') ||
        assets.where((a) => a.role == 'visual').length > 16 ||
        assets.where((a) => a.role == 'collision').length > 16) {
      throw const FormatException('Missing visual asset or duplicate asset ID');
    }
    final collision = _map(doc['collision']);
    final collisionIds = collision['assetIds'];
    if (collision['enabled'] is! bool ||
        collisionIds is! List ||
        collisionIds.toSet().length != collisionIds.length ||
        collisionIds.any(
          (id) => !assets.any((a) => a.id == id && a.role == 'collision'),
        ) ||
        collision['enabled'] == true && collisionIds.isEmpty ||
        !{'double', 'front', 'back'}.contains(collision['sidedness'])) {
      throw const FormatException('Invalid scenery collision configuration');
    }
    final visibility = _map(doc['visibility']);
    if (visibility['enabled'] is! bool) {
      throw const FormatException('Invalid scenery visibility');
    }
    _number(visibility['loadRadiusM'], 100, 29999);
    _number(visibility['unloadRadiusM'], 101, 30000);
    if ((visibility['unloadRadiusM'] as num) <=
        (visibility['loadRadiusM'] as num)) {
      throw const FormatException(
        'Scenery unloading distance needs hysteresis',
      );
    }
    parseSceneryVersion(doc['minimumAppVersion']);
    if (doc['extensions'] != null) _map(doc['extensions']);
    final extensions = doc['extensions'] as Map?;
    final lods = extensions?['lods'];
    if (lods != null) {
      if (lods is! Map || lods.length > 16) {
        throw const FormatException('Invalid scenery LOD map');
      }
      final variants = <String>{}, baseUris = <String>{};
      for (final entry in lods.entries) {
        final base = assets.where((a) => a.id == entry.key).firstOrNull;
        final levels = entry.value;
        if (base == null ||
            base.role != 'visual' ||
            base.provider != 'managed' ||
            !baseUris.add(base.uri) ||
            levels is! Map ||
            levels.isEmpty ||
            levels.length > 3) {
          throw const FormatException('Invalid managed LOD base');
        }
        for (final level in levels.entries) {
          final variant = assets.where((a) => a.id == level.value).firstOrNull;
          if (!['low', 'balanced', 'high'].contains(level.key) ||
              variant == null ||
              variant.role != 'visual' ||
              variant.provider != 'managed' ||
              variant.id == base.id ||
              lods.containsKey(variant.id)) {
            throw const FormatException('Invalid managed LOD variant');
          }
          variants.add(variant.id);
        }
      }
      if (variants.length >= assets.where((a) => a.role == 'visual').length) {
        throw const FormatException('Scenery needs a base visual asset');
      }
    }
    final package = extensions?['package'];
    if (package != null &&
        (package is! Map ||
            package['revision'] is! int ||
            (package['revision'] as int) < 1 ||
            (package['revision'] as int) > 2147483647 ||
            package['metadataOnly'] is! bool ||
            package['redistributionAllowed'] is! bool ||
            (package['previewPng'] != null &&
                (package['previewPng'] is! String ||
                    (package['previewPng'] as String).length > 43700)))) {
      throw const FormatException('Invalid scenery package metadata');
    }
    if (doc['replacement'] != null) {
      doc['replacement'] = validateSceneryReplacement(
        doc['replacement'],
        anchor,
      );
    }
    if (assets.any((a) => a.model != null)) {
      final modelBounds = transformedSceneryBounds(doc);
      (doc['extensions'] ??= <String, dynamic>{})['modelBounds'] = modelBounds;
      final radius = (modelBounds['sphere']?['radiusM'] as num?)?.toDouble();
      // The footprint includes the transformed model. Streaming distances are
      // configured separately; a terrain-relative footprint is height-independent.
      final localRadius =
          radius ??
          assets.where((a) => a.model != null).fold<double>(0, (value, a) {
            final b = a.model!['localBounds'] as List;
            final r = math.sqrt(
              List.generate(
                3,
                (i) => math.pow(
                  math.max((b[i] as num).abs(), (b[i + 3] as num).abs()),
                  2,
                ),
              ).reduce((a, b) => a + b),
            );
            return math.max(value, r * (doc['scale'] as num));
          });
      doc['bounds'] = sceneryCoverageBounds(
        (anchor['longitude'] as num).toDouble(),
        (anchor['latitude'] as num).toDouble(),
        localRadius,
      );
    }
    if (assets.any((a) => a.tileset != null)) {
      final pivotBounds = transformedSceneryBounds({
        ...doc,
        'assets': [
          {
            'model': {
              'localBounds': [0, 0, 0, 0, 0, 0],
            },
          },
        ],
      });
      final pivot = (pivotBounds['sphere'] as Map)['center'] as List;
      var radius = assets.any((a) => a.model != null)
          ? (((doc['extensions'] as Map)['modelBounds'] as Map)['sphere']
                    as Map)['radiusM']
                as double
          : 0.0;
      for (final asset in assets.where((a) => a.tileset != null)) {
        final sphere = asset.tileset!['boundingSphere'] as Map,
            c = asset.tileset!['correction'] as Map;
        final center = sphere['center'] as List;
        final distance = math.sqrt(
          List.generate(
            3,
            (i) => math.pow((center[i] as num) - (pivot[i] as num), 2),
          ).reduce((a, b) => a + b),
        );
        final translation = math.sqrt(
          [
            'eastM',
            'northM',
            'upM',
          ].map((k) => math.pow(c[k] as num, 2)).reduce((a, b) => a + b),
        );
        radius = math.max(
          radius,
          (distance + (sphere['radiusM'] as num)) * (c['scale'] as num) +
              translation,
        );
      }
      // Conservative coverage around the correction pivot encloses rotations,
      // translation and scale. Cesium retains the exact runtime bounding sphere.
      doc['bounds'] = sceneryCoverageBounds(
        (anchor['longitude'] as num).toDouble(),
        (anchor['latitude'] as num).toDouble(),
        radius,
      );
    }
    if (utf8.encode(jsonEncode(doc)).length > maxBytes) {
      throw const FormatException('Scenery manifest exceeds size limit');
    }
    return SceneryManifest._(doc);
  }

  SceneryManifest withEnabled(bool value) {
    final doc = toJson();
    (doc['visibility'] as Map)['enabled'] = value;
    return SceneryManifest.fromJson(doc);
  }

  /// Compatibility adapter for bundled catalogs and existing saved alignment.
  /// Keeps certificates/height calibration intact rather than guessing a datum.
  factory SceneryManifest.fromBundled(Map<String, dynamic> item) {
    final a = _map(item['alignment']);
    final lon = (a['longitude'] as num).toDouble();
    final lat = (a['latitude'] as num).toDouble();
    final radius = (item['unloadRadiusM'] as num? ?? 4000).toDouble();
    final assets = <Map<String, dynamic>>[
      for (final (i, raw) in (item['assets'] as List).indexed)
        {
          'id': 'visual-$i',
          'role': 'visual',
          'provider': 'bundled',
          'format': (raw as Map)['kind'],
          'uri': raw['path'],
        },
      if (item['collisionAsset'] != null)
        {
          'id': 'collision',
          'role': 'collision',
          'provider': 'bundled',
          'format': 'fpc',
          'uri': item['collisionAsset'],
          if ((item['rfMaterials'] as Map?)?[item['collisionAsset']] != null)
            'rf': (item['rfMaterials'] as Map)[item['collisionAsset']],
        },
    ];
    return SceneryManifest.fromJson({
      'schemaVersion': schemaVersion,
      'id': item['id'],
      'name': item['name'],
      'description': item['description'] ?? '',
      'source': {
        'author': item['author'],
        'url': item['sourceUrl'],
        'license': item['license'],
        'attribution':
            item['attribution'] ?? '${item['author']} · ${item['license']}',
      },
      'anchor': {
        'longitude': lon,
        'latitude': lat,
        'heightM': a['ellipsoidHeightM'],
        'reference': 'WGS84_ELLIPSOID',
      },
      'bounds': sceneryCoverageBounds(lon, lat, radius),
      'rotation': {
        'headingDeg': a['rotationDeg'],
        'pitchDeg': a['pitchDeg'] ?? 0,
        'rollDeg': a['rollDeg'] ?? 0,
      },
      'scale': a['scale'],
      'assets': assets,
      'collision': {
        'enabled': item['physicalCollisionsEnabled'] == true,
        'assetIds': item['collisionAsset'] == null ? <String>[] : ['collision'],
        'sidedness': 'double',
      },
      'visibility': {
        'enabled': item['enabled'] != false,
        'loadRadiusM': item['loadRadiusM'] ?? 2500,
        'unloadRadiusM': radius,
      },
      'minimumAppVersion': '0.20.0',
      'extensions': {'cesium': item, 'bundledAlignment': item['alignment']},
    });
  }

  SceneryManifest withLegacyEdit(
    Map<String, dynamic> edit, {
    bool migrateLegacyBase = false,
  }) {
    final doc = toJson();
    var a = _map(edit['alignment']);
    final base = ((doc['extensions'] as Map?)?['cesium'] as Map?);
    final original = base?['alignment'] as Map?;
    if (migrateLegacyBase &&
        original != null &&
        a['ellipsoidHeightM'] != original['ellipsoidHeightM'] &&
        (base?['legacyAlignmentHeightsM'] as List?)?.contains(
              a['ellipsoidHeightM'],
            ) ==
            true &&
        [
          'longitude',
          'latitude',
          'scale',
          'rotationDeg',
        ].every((key) => a[key] == original[key])) {
      a = {...a, 'ellipsoidHeightM': original['ellipsoidHeightM']};
      edit = {...edit, 'alignment': a};
    }
    doc['anchor'] = {
      'longitude': a['longitude'],
      'latitude': a['latitude'],
      'heightM': a['ellipsoidHeightM'],
      'reference': 'WGS84_ELLIPSOID',
    };
    doc['rotation'] = {
      'headingDeg': a['rotationDeg'],
      'pitchDeg': a['pitchDeg'] ?? 0,
      'rollDeg': a['rollDeg'] ?? 0,
    };
    doc['scale'] = a['scale'];
    doc['bounds'] = sceneryCoverageBounds(
      (a['longitude'] as num).toDouble(),
      (a['latitude'] as num).toDouble(),
      ((doc['visibility'] as Map)['unloadRadiusM'] as num).toDouble(),
    );
    final extensions = (doc['extensions'] ??= <String, dynamic>{}) as Map;
    extensions['cesium'] = {...?_mapOrNull(extensions['cesium']), ...edit};
    return SceneryManifest.fromJson(doc);
  }
}

/// Conservative geographic coverage, not measured transformed mesh bounds.
Map<String, double> sceneryCoverageBounds(
  double longitude,
  double latitude,
  double radiusM,
) {
  // Lower than WGS84's minimum curvature radius, including allowed anchor
  // heights. A sphere enclosing the local model must not understate its footprint.
  const conservativeRadiusM = 6300000.0;
  if (radiusM >= conservativeRadiusM) {
    return {'west': -180, 'east': 180, 'south': -90, 'north': 90};
  }
  final angular = math.asin(radiusM / conservativeRadiusM);
  final dLat = angular * 180 / math.pi;
  final polar = latitude - dLat <= -90 || latitude + dLat >= 90;
  final dLon = polar
      ? 180.0
      : math.asin(
              math.min(
                1,
                math.sin(angular) / math.cos(latitude * math.pi / 180),
              ),
            ) *
            180 /
            math.pi;
  return {
    'west': polar ? -180 : (longitude - dLon + 540) % 360 - 180,
    'east': polar ? 180 : (longitude + dLon + 540) % 360 - 180,
    'south': math.max(-90, latitude - dLat),
    'north': math.min(90, latitude + dLat),
  };
}

/// Optional per-collider RF assumptions. These are not surveyed properties.
const sceneryRfMaterials = [
  'unknown',
  'concrete',
  'reinforcedConcrete',
  'brick',
  'metal',
  'glass',
  'wood',
];

Map<String, dynamic> validateSceneryRf(Object? value) {
  final rf = _map(value);
  if (rf.keys.any(
        (key) => !const {
          'material',
          'thicknessM',
          'surfaceLossDb',
          'lossDbPerM',
        }.contains(key),
      ) ||
      !sceneryRfMaterials.contains(rf['material'])) {
    throw const FormatException('Invalid scenery RF material');
  }
  if (rf.containsKey('thicknessM')) _number(rf['thicknessM'], .01, 20);
  for (final key in ['surfaceLossDb', 'lossDbPerM']) {
    if (rf.containsKey(key)) _number(rf[key], 0, 100);
  }
  return Map.unmodifiable(rf);
}

final class SceneryAsset {
  SceneryAsset._(
    this.id,
    this.role,
    this.provider,
    this.format,
    this.uri,
    this.model,
    this.tileset,
    this.rf,
  );
  final String id, role, provider, format, uri;
  final Map<String, dynamic>? model;
  final Map<String, dynamic>? tileset;
  final Map<String, dynamic>? rf;
  factory SceneryAsset.fromJson(Object? value) {
    final a = _map(value);
    _identifier(a['id']);
    _identifier(a['provider']);
    _identifier(a['format']);
    if (!{'visual', 'collision'}.contains(a['role'])) {
      throw const FormatException('Invalid scenery asset role');
    }
    _text(a['uri'], 2048);
    final uri = Uri.tryParse(a['uri'] as String);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasScheme && uri.scheme != 'https' ||
        uri.scheme == 'https' && uri.host.isEmpty ||
        !uri.hasScheme && !isSceneryRelativePath(a['uri'] as String)) {
      throw const FormatException('Unsafe scenery asset reference');
    }
    Map<String, dynamic>? model;
    if (a['model'] != null) {
      model = _clone(_map(a['model']));
      final b = model['localBounds'];
      if (b is! List ||
          b.length != 6 ||
          b.any((v) => v is! num || !v.isFinite || v.abs() > 2000000) ||
          List.generate(
            3,
            (i) => (b[i] as num) > (b[i + 3] as num),
          ).any((v) => v)) {
        throw const FormatException('Invalid local model bounds');
      }
      for (final key in [
        'triangles',
        'vertices',
        'textures',
        'estimatedBytes',
        'byteLength',
      ]) {
        if (model[key] is! int ||
            (model[key] as int) < 0 ||
            (model[key] as int) > 128 * 1024 * 1024) {
          throw const FormatException('Invalid model resource estimate');
        }
      }
    }
    if (a['provider'] == 'managed' &&
        (!isManagedSceneryKey(a['uri'] as String) ||
            !(a['format'] == 'glb' &&
                    a['role'] == 'visual' &&
                    a['uri'].endsWith('.glb') ||
                a['format'] == 'fpc' &&
                    a['role'] == 'collision' &&
                    a['uri'].endsWith('.fpc')) ||
            model == null)) {
      throw const FormatException('Invalid managed model definition');
    }
    Map<String, dynamic>? tileset;
    if (a['provider'] == remoteTilesetProvider) {
      validateTilesetUrl(a['uri']);
      if (a['format'] != remoteTilesetFormat || a['role'] != 'visual') {
        throw const FormatException('Remote tilesets are visual assets');
      }
      tileset = validateTilesetOptions(a['tileset']);
    }
    if (a.containsKey('rf') && a['role'] != 'collision') {
      throw const FormatException('RF material requires collision geometry');
    }
    return SceneryAsset._(
      a['id'] as String,
      a['role'] as String,
      a['provider'] as String,
      a['format'] as String,
      a['uri'] as String,
      model == null ? null : Map.unmodifiable(model),
      tileset == null ? null : Map.unmodifiable(tileset),
      a.containsKey('rf') ? validateSceneryRf(a['rf']) : null,
    );
  }
}

bool isSceneryRelativePath(String value) =>
    RegExp(r'^([a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+$').hasMatch(value);

List<int> parseSceneryVersion(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$').hasMatch(value)) {
    throw const FormatException('Invalid minimum application version');
  }
  return value.split('.').map(int.parse).toList(growable: false);
}

Map<String, dynamic> _clone(Map<String, dynamic> value) {
  final pending = <(Object?, int)>[(value, 0)];
  var nodes = 0;
  while (pending.isNotEmpty) {
    final (node, depth) = pending.removeLast();
    if (depth > 24 || ++nodes > 32768) {
      throw const FormatException('Scenery object exceeds structural limits');
    }
    if (node is Map) {
      if (node.keys.any((key) => key is! String)) {
        throw const FormatException('Invalid scenery object key');
      }
      for (final child in node.values) {
        pending.add((child, depth + 1));
      }
    } else if (node is List) {
      for (final child in node) {
        pending.add((child, depth + 1));
      }
    } else if (node is num && !node.isFinite ||
        node != null && node is! num && node is! bool && node is! String) {
      throw const FormatException('Invalid scenery JSON value');
    }
  }
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected scenery object');
  }
  return value;
}

Map<String, dynamic>? _mapOrNull(Object? value) =>
    value == null ? null : _map(value);
void _identifier(Object? value) {
  if (value is! String || !RegExp(r'^[a-z0-9_-]{1,80}$').hasMatch(value)) {
    throw const FormatException('Invalid scenery identifier');
  }
}

void _text(Object? value, int limit, {bool empty = false}) {
  if (value is! String ||
      value.length > limit ||
      !empty && value.trim().isEmpty) {
    throw const FormatException('Invalid scenery text');
  }
}

void _number(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('Invalid scenery coordinate or setting');
  }
}

void _https(Object? value) {
  _text(value, 2048);
  final uri = Uri.tryParse(value as String);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid scenery source URL');
  }
}
