import 'dart:math' as math;

import 'scenery_manifest.dart';
import 'scenery_tileset_options.dart';

/// Provider masks refer to the original geographic buildings, not the scan.
/// Keep those footprints for a bounded local registration correction only.
/// Compare against the original bundled anchor to prevent cumulative drift.
bool retainsBundledBuildingFootprints(
  Map? original,
  Map anchor,
  Map rotation,
  num scale,
) {
  if (original == null || anchor['reference'] != 'WGS84_ELLIPSOID') {
    return false;
  }
  if (![
        'latitude',
        'longitude',
        'ellipsoidHeightM',
        'rotationDeg',
        'scale',
      ].every(
        (key) => original[key] is num && (original[key] as num).isFinite,
      ) ||
      (original['scale'] as num) <= 0 ||
      !['pitchDeg', 'rollDeg'].every(
        (key) =>
            original[key] == null ||
            original[key] is num && (original[key] as num).isFinite,
      )) {
    return false;
  }
  final lat = original['latitude'] as num;
  final dLon =
      ((anchor['longitude'] as num) - (original['longitude'] as num) + 540) %
          360 -
      180;
  final dLat = (anchor['latitude'] as num) - lat;
  final east = dLon * math.pi / 180 * 6378137 * math.cos(lat * math.pi / 180);
  final north = dLat * math.pi / 180 * 6378137;
  num angle(num value, num base) => ((value - base + 540) % 360 - 180).abs();
  return east * east + north * north <= 100 &&
      ((anchor['heightM'] as num) - (original['ellipsoidHeightM'] as num))
              .abs() <=
          50 &&
      angle(rotation['headingDeg'] as num, original['rotationDeg'] as num) <=
          3 &&
      angle(rotation['pitchDeg'] as num, (original['pitchDeg'] as num?) ?? 0) <=
          3 &&
      angle(rotation['rollDeg'] as num, (original['rollDeg'] as num?) ?? 0) <=
          3 &&
      (scale / (original['scale'] as num) - 1).abs() <= .02;
}

/// Applies placement fields only; source, assets and collision policy stay owned
/// by the stored definition. The renderer never replaces arbitrary manifest data.
SceneryManifest applySceneryAlignment(
  SceneryManifest base,
  Map<String, dynamic> edit,
) {
  final doc = base.toJson(), a = edit['alignment'];
  if (a is! Map || edit['transformChanged'] is! bool) {
    throw const FormatException('Invalid scenery alignment edit');
  }
  num number(String key, num min, num max) {
    final value = a[key];
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw FormatException('Invalid alignment $key');
    }
    return value;
  }

  final longitude = number('longitude', -180, 180),
      latitude = number('latitude', -90, 90),
      height = number('ellipsoidHeightM', -10000, 20000),
      heading = number('rotationDeg', -360, 360),
      pitch = number('pitchDeg', -90, 90),
      roll = number('rollDeg', -180, 180),
      scale = number('scale', .01, 1000),
      opacity = number('opacity', .02, 1);
  final reference = edit['reference'], relativeHeight = edit['heightM'];
  if (!['WGS84_ELLIPSOID', 'TERRAIN_RELATIVE'].contains(reference) ||
      relativeHeight is! num ||
      !relativeHeight.isFinite ||
      relativeHeight < -10000 ||
      relativeHeight > 20000) {
    throw const FormatException('Invalid altitude reference or height');
  }
  final extension = (doc['extensions'] as Map<String, dynamic>?) ?? {};
  final cesium = (extension['cesium'] as Map<String, dynamic>?) ?? {};
  if (edit['transformChanged'] == true) {
    final remote = base.assets
        .where((a) => a.provider == remoteTilesetProvider)
        .toList();
    if (remote.isEmpty) {
      doc['anchor'] = {
        'longitude': longitude,
        'latitude': latitude,
        'heightM': reference == 'TERRAIN_RELATIVE' ? relativeHeight : height,
        'reference': reference,
      };
      doc['rotation'] = {
        'headingDeg': heading,
        'pitchDeg': pitch,
        'rollDeg': roll,
      };
      doc['scale'] = scale;
    } else {
      final corrections = edit['remoteCorrections'];
      if (reference != 'WGS84_ELLIPSOID' ||
          corrections is! List ||
          corrections.length != remote.length) {
        throw const FormatException('Invalid tileset alignment corrections');
      }
      final ids = <String>{};
      for (final correction in corrections) {
        if (correction is! Map ||
            correction['id'] is! String ||
            !ids.add(correction['id'] as String) ||
            !remote.any((a) => a.id == correction['id'])) {
          throw const FormatException('Invalid tileset asset reference');
        }
        final asset = (doc['assets'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['id'] == correction['id']);
        asset['tileset'] = validateTilesetOptions({
          ...asset['tileset'] as Map<String, dynamic>,
          'correction': correction['correction'],
        });
      }
    }
    if (doc['replacement'] is Map) {
      final replacement = doc['replacement'] as Map;
      (replacement['buildings'] as Map)['enabled'] = false;
      (replacement['terrain'] as Map)['enabled'] = false;
    }
    final keepBuildingFootprints =
        remote.isEmpty &&
        retainsBundledBuildingFootprints(
          extension['bundledAlignment'] as Map?,
          doc['anchor'] as Map,
          doc['rotation'] as Map,
          doc['scale'] as num,
        );
    // Terrain certificates belong to the exact original placement. Building
    // footprints are fixed to the provider buildings, not translated with the scan.
    for (final key in [
      'heightCalibration',
      'heightAlignmentMode',
      'requireGroundCalibration',
      'groundReferenceLocalUp',
      'heightOffsetM',
      'bkgHeightOffsetM',
      'terrainCertificate',
      'terrainCertificates',
      'terrainUnderlay',
      'terrainRegions',
    ]) {
      cesium.remove(key);
    }
    if (!keepBuildingFootprints) {
      cesium.remove('buildingRegions');
      cesium['replaceBuildings'] = false;
    }
    cesium['clipTerrain'] = false;
  }
  cesium['alignment'] = {
    ...?cesium['alignment'] as Map<String, dynamic>?,
    'opacity': opacity,
  };
  extension['cesium'] = cesium;
  doc['extensions'] = extension;
  return SceneryManifest.fromJson(doc);
}

/// Recover only the old editor's stripped legacy mask, not an explicit disabled
/// polygon configuration or custom replacement policy. Keep the edited pose.
SceneryManifest recoverStrippedBundledBuildingFootprints(
  SceneryManifest current,
  SceneryManifest? bundled,
) {
  if (bundled == null || current.id != bundled.id) return current;
  final doc = current.toJson(), source = bundled.toJson();
  final extensions = doc['extensions'] as Map?;
  final original = source['extensions'] as Map;
  final cesium = extensions?['cesium'];
  final base = original['cesium'] as Map;
  if (cesium is! Map ||
      doc['replacement'] != null ||
      cesium['replaceBuildings'] != false ||
      cesium['clipTerrain'] != false ||
      cesium.containsKey('buildingRegions') ||
      cesium.containsKey('terrainRegions') ||
      cesium.containsKey('heightCalibration') ||
      base['replaceBuildings'] != true ||
      base['buildingRegions'] is! List ||
      (base['buildingRegions'] as List).isEmpty ||
      (doc['collision'] as Map)['enabled'] != true ||
      !retainsBundledBuildingFootprints(
        original['bundledAlignment'] as Map?,
        doc['anchor'] as Map,
        doc['rotation'] as Map,
        doc['scale'] as num,
      )) {
    return current;
  }
  // The mask belongs to the original asset set; RF material edits are allowed.
  final assets = current.assets, defaults = bundled.assets;
  if (assets.length != defaults.length ||
      !assets.every(
        (a) => defaults.any(
          (b) =>
              a.id == b.id &&
              a.role == b.role &&
              a.provider == 'bundled' &&
              b.provider == 'bundled' &&
              a.format == b.format &&
              a.uri == b.uri,
        ),
      )) {
    return current;
  }
  cesium['buildingRegions'] = base['buildingRegions'];
  cesium['replaceBuildings'] = true;
  // Retain the original reference for the independent compile-time guard.
  extensions!['bundledAlignment'] = original['bundledAlignment'];
  return SceneryManifest.fromJson(doc);
}
