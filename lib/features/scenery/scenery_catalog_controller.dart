import 'dart:async';
import 'dart:convert';

import 'scenery_asset_provider.dart';
import 'scenery_manifest.dart';
import 'scenery_repository.dart';

typedef SceneryCommand = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> command,
);

/// Serializes persistence and bridge updates. The database is authoritative;
/// reconnects replay its current definitions, including intentional removals.
final class SceneryCatalogController {
  SceneryCatalogController({
    required this.repository,
    required this.send,
    required this.loadBundled,
    required this.canSend,
    SceneryAssetProviders? providers,
  }) : providers = providers ?? SceneryAssetProviders();
  final SceneryRepository repository;
  final SceneryCommand send;
  final Future<String> Function() loadBundled;
  final bool Function() canSend;
  final SceneryAssetProviders providers;
  Future<void>? _initializing;
  Future<void>? _pending;
  Future<void>? _databaseWork;
  bool _disposed = false;
  Map<String, SceneryManifest> _defaults = {};

  Future<void> get settled async {
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
  }

  Future<void> get storageSettled async {
    final work = _databaseWork;
    if (work != null) await work;
  }

  void dispose() {
    _disposed = true;
  }

  void _checkOpen() {
    if (_disposed) throw StateError('Scenery controller disposed');
  }

  Future<T> _database<T>(Future<T> Function() action) async {
    _checkOpen();
    final work = action();
    final tracked = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _databaseWork = tracked;
    try {
      return await work;
    } finally {
      if (identical(_databaseWork, tracked)) _databaseWork = null;
    }
  }

  Future<void> _initialize() => _initializing ??= () async {
    try {
      final raw = jsonDecode(await loadBundled()) as Map<String, dynamic>;
      if (raw['schemaVersion'] != 1 || raw['sceneries'] is! List) {
        throw const FormatException('Invalid bundled scenery catalog');
      }
      final manifests = [
        for (final value in raw['sceneries'] as List)
          SceneryManifest.fromBundled(value as Map<String, dynamic>),
      ];
      _defaults = {for (final manifest in manifests) manifest.id: manifest};
      if (_defaults.length != manifests.length) {
        throw const FormatException('Duplicate bundled scenery');
      }
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = Completer<T>();
    Future<void> run() async {
      try {
        _checkOpen();
        await _initialize();
        _checkOpen();
        // A backup can replace the database while this controller stays alive.
        // Recheck the marker so an older backup can seed its legacy scenes.
        await _database(
          () => repository.initializeBundled(_defaults.values.toList()),
        );
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }

    final previous = _pending;
    _pending = previous == null ? run() : previous.then((_) => run());
    return result.future;
  }

  Future<List<SceneryManifest>> definitions() =>
      _serial(() => _database(repository.list));
  Future<List<SceneryManifest>> templates() =>
      _serial(() async => List.unmodifiable(_defaults.values));
  Future<Map<String, dynamic>> synchronize({bool Function()? isCurrent}) =>
      _serial(() => _synchronize(isCurrent: isCurrent));
  Future<Map<String, dynamic>> _synchronize({
    bool Function()? isCurrent,
  }) async {
    final manifests = await _database(repository.list);
    if (isCurrent != null && !isCurrent()) {
      return {};
    }
    if (!canSend()) throw StateError('Scenery is saved; renderer unavailable');
    return send({
      'type': 'replace-scenery-catalog',
      'catalog': providers.compile(manifests),
    });
  }

  Future<Map<String, dynamic>> save(
    SceneryManifest manifest, {
    required bool create,
  }) => _serial(() async {
    if (create) {
      await _database(() => repository.create(manifest));
    } else {
      await _database(() => repository.update(manifest));
    }
    return _synchronize();
  });
  Future<Map<String, dynamic>> remove(String id) => _serial(() async {
    await _database(() => repository.remove(id));
    return _synchronize();
  });

  Future<Map<String, dynamic>> setEnabled(String id, bool enabled) =>
      _serial(() async {
        final manifest = (await _database(repository.list))
            .firstWhere((m) => m.id == id);
        await _database(() => repository.update(manifest.withEnabled(enabled)));
        return _synchronize();
      });

  Future<Map<String, dynamic>> setEdit(String id, Map<String, dynamic>? edit) =>
      _serial(() async {
        final manifest = (await _database(repository.list))
            .firstWhere((m) => m.id == id);
        if (!canSend()) throw StateError('Renderer unavailable');
        final reset = _defaults[id]?.toJson()['extensions'] as Map?;
        final base = reset?['cesium'] as Map?;
        final result = await send({
          'type': 'set-scenery-edit',
          'id': id,
          'edit':
              edit ??
              (base == null
                  ? null
                  : {
                      for (final key in [
                        'alignment',
                        'heightOffsetM',
                        'bkgHeightOffsetM',
                        'buildingRegions',
                        'terrainRegions',
                        'replaceBuildings',
                        'clipTerrain',
                      ])
                        key: base[key],
                    }),
        });
        final items = result['sceneries'] as List;
        final item = items.cast<Map<String, dynamic>>().firstWhere(
          (m) => m['id'] == id,
        );
        final canonical = {
          for (final key in [
            'alignment',
            'heightOffsetM',
            'bkgHeightOffsetM',
            'buildingRegions',
            'terrainRegions',
            'replaceBuildings',
            'clipTerrain',
          ])
            key: item[key],
        };
        await _database(
          () => repository.update(manifest.withLegacyEdit(canonical)),
        );
        return result;
      });
}
