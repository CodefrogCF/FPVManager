import 'scenery_manifest.dart';
import 'scenery_storage.dart';
import 'scenery_tileset_options.dart';

// Keep aligned with pubspec's application version; checked by regression test.
const sceneryApplicationVersion = '0.19.29';

/// Resolve references without storing bytes or duplicating Cesium loaders.
/// Future managed-file/3D-Tiles providers implement this same boundary.
abstract interface class SceneryAssetProvider {
  String get id;
  String? resolve(SceneryAsset asset);
}

final class BundledSceneryAssetProvider implements SceneryAssetProvider {
  const BundledSceneryAssetProvider();
  @override
  String get id => 'bundled';
  @override
  String? resolve(SceneryAsset asset) {
    if (!isSceneryRelativePath(asset.uri)) return null;
    if (asset.role == 'visual' &&
            asset.format == 'glb' &&
            asset.uri.endsWith('.glb') ||
        asset.role == 'collision' &&
            asset.format == 'fpc' &&
            asset.uri.endsWith('.fpc')) {
      return asset.uri;
    }
    return null;
  }
}

final class SceneryAssetProviders {
  SceneryAssetProviders({
    Iterable<SceneryAssetProvider> providers = const [
      BundledSceneryAssetProvider(),
      ManagedSceneryAssetProvider(),
      RemoteTilesetAssetProvider(),
    ],
    this.applicationVersion = sceneryApplicationVersion,
    this.managedOptions = const {'backend': 'server'},
  }) {
    for (final provider in providers) {
      if (_providers.containsKey(provider.id)) {
        throw ArgumentError('Duplicate scenery provider');
      }
      _providers[provider.id] = provider;
    }
  }
  final String applicationVersion;
  final Map<String, String> managedOptions;
  final Map<String, SceneryAssetProvider> _providers = {};

  /// Unsupported definitions remain persisted and explicitly unavailable.
  Map<String, dynamic> compile(List<SceneryManifest> manifests) {
    final ready = <Map<String, dynamic>>[],
        unavailable = <Map<String, dynamic>>[];
    for (final manifest in manifests) {
      final doc = manifest.toJson();
      String? reason;
      if (!_compatible(doc['minimumAppVersion'] as String)) {
        reason = 'A newer application version is required';
      }
      final resolved = <String, String>{};
      for (final asset in manifest.assets) {
        String? path;
        try {
          path = _providers[asset.provider]?.resolve(asset);
        } catch (_) {
          reason ??= 'Asset provider failed: ${asset.provider}';
        }
        if (path == null ||
            (asset.provider == remoteTilesetProvider
                ? !_remotePath(path)
                : !isSceneryRelativePath(path))) {
          reason ??=
              'Asset provider or format is unavailable: ${asset.provider}/${asset.format}';
        } else {
          resolved[asset.id] = path;
        }
      }
      final collision = doc['collision'] as Map;
      if (collision['sidedness'] != 'double') {
        reason ??= 'Collision sidedness is unavailable';
      }
      final pose = doc['rotation'] as Map;
      final options = ((doc['extensions'] as Map?)?['cesium'] as Map?) ?? {};
      if ((pose['pitchDeg'] != 0 || pose['rollDeg'] != 0) &&
          (options['heightCalibration'] != null ||
              options['terrainCertificate'] != null)) {
        reason ??= 'Tilted terrain-calibrated scenery requires new calibration';
      }
      if (reason != null) {
        unavailable.add({
          'id': manifest.id,
          'name': manifest.name,
          'enabled': manifest.enabled,
          'message': reason,
        });
        continue;
      }
      final anchor = doc['anchor'] as Map,
          rotation = doc['rotation'] as Map,
          visibility = doc['visibility'] as Map,
          source = doc['source'] as Map;
      final extension =
          ((doc['extensions'] as Map?)?['cesium'] as Map?)
              ?.cast<String, dynamic>() ??
          {};
      final collisionPaths = [
        for (final id in collision['assetIds'] as List) resolved[id]!,
      ];
      final alignment = {
        'schemaVersion': 1,
        'longitude': anchor['longitude'],
        'latitude': anchor['latitude'],
        'ellipsoidHeightM': anchor['reference'] == 'TERRAIN_RELATIVE'
            ? 0
            : anchor['heightM'],
        'rotationDeg': rotation['headingDeg'],
        'pitchDeg': rotation['pitchDeg'],
        'rollDeg': rotation['rollDeg'],
        'scale': doc['scale'],
        'opacity': (extension['alignment'] as Map?)?['opacity'] ?? 1,
      };
      ready.add(
        {
          ...extension,
          'id': manifest.id,
          'name': manifest.name,
          'author': source['author'],
          'sourceUrl': source['url'],
          'license': source['license'],
          'attribution': source['attribution'],
          'enabled': manifest.enabled,
          'heightDatum': 'WGS84 ellipsoid',
          'alignment': alignment,
          if (anchor['reference'] == 'TERRAIN_RELATIVE') ...{
            'heightAlignmentMode': 'terrain',
            'heightOffsetM': anchor['heightM'],
            'requireGroundCalibration': true,
            'groundReferenceLocalUp': 0,
          } else
            'heightAlignmentMode': extension['heightAlignmentMode'] ?? 'fixed',
          'physicalCollisionsEnabled': collision['enabled'],
          if (collision['enabled'] == true) ...{
            'collisionAsset': collisionPaths.first,
            'collisionAssets': collisionPaths,
          },
          'assets': [
            for (final a in manifest.assets.where((a) => a.role == 'visual'))
              {
                'kind': a.provider == remoteTilesetProvider
                    ? '3d-tiles'
                    : 'glb',
                if (a.provider == remoteTilesetProvider) ...{
                  'url': resolved[a.id],
                  'options': a.tileset,
                } else
                  'path': resolved[a.id],
                if (a.provider == 'managed') ...{
                  'managed': true,
                  ...managedOptions,
                  'estimatedBytes': a.model!['estimatedBytes'],
                },
              },
          ],
          'loadRadiusM': visibility['loadRadiusM'],
          'unloadRadiusM': visibility['unloadRadiusM'],
        }..removeWhere(
          (key, value) =>
              collision['enabled'] != true &&
              {'collisionAsset', 'collisionAssets'}.contains(key),
        ),
      );
      final baseAlignment =
          (doc['extensions'] as Map?)?['bundledAlignment'] as Map?;
      final changedPlacement =
          baseAlignment != null &&
          (baseAlignment['longitude'] != anchor['longitude'] ||
              baseAlignment['latitude'] != anchor['latitude'] ||
              baseAlignment['rotationDeg'] != rotation['headingDeg'] ||
              baseAlignment['scale'] != doc['scale']);
      final calibration = extension['heightCalibration'] as Map?;
      if (anchor['reference'] == 'WGS84_ELLIPSOID' &&
          calibration?['method'] == 'terrain-provider-rendered-ground') {
        // This legacy provider fits its root from live ground, independently of
        // the nominal anchor. Keep its reference equation valid after scaling.
        final root =
            (calibration!['referenceGroundHeightM'] as num) -
            (calibration['groundReferenceLocalUp'] as num) *
                (doc['scale'] as num);
        alignment['ellipsoidHeightM'] = root;
        ready.last['heightCalibration'] = {
          ...calibration,
          'referenceRootHeightM': root,
        };
      }
      if (anchor['reference'] == 'TERRAIN_RELATIVE' ||
          collision['enabled'] != true ||
          changedPlacement) {
        for (final key in [
          'terrainCertificate',
          'terrainCertificates',
          'terrainUnderlay',
        ]) {
          ready.last.remove(key);
        }
        ready.last['clipTerrain'] = false;
      }
      if (changedPlacement) {
        ready.last['buildingRegions'] = <Object>[];
        ready.last['terrainRegions'] = <Object>[];
        ready.last['replaceBuildings'] = false;
      }
      if (anchor['reference'] == 'TERRAIN_RELATIVE') {
        ready.last.remove('heightCalibration');
      }
    }
    return {'schemaVersion': 1, 'sceneries': ready, 'unavailable': unavailable};
  }

  bool _compatible(String minimum) {
    final a = parseSceneryVersion(applicationVersion),
        b = parseSceneryVersion(minimum);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return true;
  }
}

bool _remotePath(String value) {
  try {
    validateTilesetUrl(value);
    return true;
  } on FormatException {
    return false;
  }
}

final class RemoteTilesetAssetProvider implements SceneryAssetProvider {
  const RemoteTilesetAssetProvider();
  @override
  String get id => remoteTilesetProvider;
  @override
  String? resolve(SceneryAsset asset) =>
      asset.role == 'visual' &&
          asset.format == remoteTilesetFormat &&
          asset.tileset != null &&
          _remotePath(asset.uri)
      ? asset.uri
      : null;
}

final class ManagedSceneryAssetProvider implements SceneryAssetProvider {
  const ManagedSceneryAssetProvider();
  @override
  String get id => 'managed';
  @override
  String? resolve(SceneryAsset asset) =>
      asset.role == 'visual' &&
          asset.format == 'glb' &&
          isManagedSceneryKey(asset.uri)
      ? 'managed/${asset.uri}'
      : null;
}
