import 'scenery_manifest.dart';
import 'scenery_tileset_options.dart';

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
    // Verified terrain/building replacement belongs to its original placement.
    for (final key in [
      'heightCalibration',
      'heightAlignmentMode',
      'requireGroundCalibration',
      'groundReferenceLocalUp',
      'heightOffsetM',
      'bkgHeightOffsetM',
      'terrainCertificate',
      'terrainCertificates',
      'buildingRegions',
      'terrainRegions',
    ]) {
      cesium.remove(key);
    }
    cesium['replaceBuildings'] = false;
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
