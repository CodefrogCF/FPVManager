import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'scenery_asset_provider.dart';
import 'scenery_manifest.dart';
import 'scenery_repository.dart';
import 'scenery_storage.dart';
import 'scenery_storage_platform.dart';
import 'scenery_model_import.dart';
import 'scenery_alignment_edit.dart';
import 'scenery_collision_import.dart';

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
    SceneryStorage? storage,
  }) : storage = storage ?? createSceneryStorage(),
       _customProviders = providers;
  final SceneryRepository repository;
  final SceneryCommand send;
  final Future<String> Function() loadBundled;
  final bool Function() canSend;
  final SceneryStorage storage;
  final SceneryAssetProviders? _customProviders;
  late final SceneryAssetProviders providers =
      _customProviders ??
      SceneryAssetProviders(managedOptions: storage.rendererOptions);
  Future<void>? _initializing;
  Future<void>? _pending;
  final _storageWork = <Future<void>>{};
  bool _disposed = false;
  Map<String, SceneryManifest> _defaults = {};

  Future<void> get settled async {
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
  }

  Future<void> get storageSettled async {
    while (_storageWork.isNotEmpty) {
      await Future.wait(_storageWork.toList());
    }
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
    _storageWork.add(tracked);
    try {
      return await work;
    } finally {
      _storageWork.remove(tracked);
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
  Future<List<SceneryManifest>> templates() => _serial(
    () async => List.unmodifiable(
      {
        ..._defaults,
        for (final m in await _database(repository.list))
          if (m.assets.any((a) => a.provider == 'managed')) m.id: m,
      }.values,
    ),
  );
  Future<Map<String, dynamic>> synchronize({bool Function()? isCurrent}) =>
      _serial(() => _synchronize(isCurrent: isCurrent));
  Future<Map<String, dynamic>> _synchronize({
    bool Function()? isCurrent,
    String? alignmentToken,
  }) async {
    final manifests = await _database(repository.list);
    if (isCurrent != null && !isCurrent()) {
      return {};
    }
    if (!canSend()) throw StateError('Scenery is saved; renderer unavailable');
    return send({
      'type': 'replace-scenery-catalog',
      'alignmentToken': ?alignmentToken,
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
  Future<Map<String, dynamic>> saveAlignment(
    SceneryManifest expected,
    Map<String, dynamic> edit, {
    bool Function()? isCurrent,
    String? token,
  }) => _serial(() async {
    final current = (await _database(repository.list))
        .where((m) => m.id == expected.id)
        .firstOrNull;
    if (current == null ||
        jsonEncode(current.toJson()) != jsonEncode(expected.toJson())) {
      throw StateError(
        'Scenery changed during editing. Reopen the alignment editor.',
      );
    }
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Obsolete alignment session');
    }
    final updated = applySceneryAlignment(current, edit);
    await _database(() => repository.update(updated));
    try {
      return await _synchronize(alignmentToken: token);
    } catch (error) {
      throw StateError(
        'Alignment was saved; renderer synchronization failed: $error',
      );
    }
  });

  Future<Map<String, dynamic>> saveCollision(
    SceneryManifest expected,
    SceneryManifest draft,
    List<PreparedSceneryCollision> pending,
  ) => _serial(() async {
    final definitions = await _database(repository.list);
    final current = definitions.where((m) => m.id == expected.id).firstOrNull;
    if (current == null ||
        jsonEncode(current.toJson()) != jsonEncode(expected.toJson())) {
      throw StateError('Scenery changed. Reopen collision settings.');
    }
    final config = draft.toJson()['collision'] as Map;
    final next = configureSceneryCollision(
      current,
      (draft.toJson()['assets'] as List)
          .where((a) => a['role'] == 'collision')
          .cast<Map<String, dynamic>>()
          .toList(),
      enabled: config['enabled'] as bool,
      sidedness: config['sidedness'] as String,
    );
    final referenced = definitions
            .expand((m) => m.assets)
            .map((a) => a.uri)
            .toSet(),
        created = <String>[];
    await _database(() async {
      try {
        for (final mesh in pending) {
          final asset = next.assets
              .where(
                (a) =>
                    a.role == 'collision' &&
                    a.provider == 'managed' &&
                    a.uri == mesh.key,
              )
              .firstOrNull;
          if (asset == null) continue;
          if (jsonEncode(asset.model) != jsonEncode(mesh.metadata)) {
            throw const FormatException('Collision metadata mismatch');
          }
          if (await storage.put(mesh.key, mesh.bytes)) created.add(mesh.key);
          _checkOpen();
        }
        if (!canSend()) {
          throw StateError(
            'Stop navigation before committing collision geometry',
          );
        }
        await repository.update(next);
      } catch (_) {
        for (final key in created) {
          if (!referenced.contains(key)) await storage.remove(key);
        }
        rethrow;
      }
    });
    final retained = (await _database(repository.list))
        .expand((m) => m.assets)
        .map((a) => a.uri)
        .toSet();
    for (final asset in current.assets.where(
      (a) => a.role == 'collision' && a.provider == 'managed',
    )) {
      if (!retained.contains(asset.uri)) {
        try {
          await _database(() => storage.remove(asset.uri));
        } catch (_) {
          /* Shared definitions remain authoritative. */
        }
      }
    }
    final result = await _synchronize();
    if (pending.isNotEmpty &&
        jsonEncode(current.toJson()) == jsonEncode(next.toJson()) &&
        canSend()) {
      return send({'type': 'retry-scenery', 'id': current.id});
    }
    return result;
  });

  Future<Map<String, dynamic>> remove(String id) => _serial(() async {
    final before = await _database(repository.list);
    await _database(() => repository.remove(id));
    final retained = (await _database(repository.list))
        .expand((m) => m.assets)
        .map((a) => a.uri)
        .toSet();
    for (final asset
        in before.where((m) => m.id == id).expand((m) => m.assets)) {
      if (asset.provider == 'managed' && !retained.contains(asset.uri)) {
        try {
          await _database(() => storage.remove(asset.uri));
        } catch (_) {
          /* Retry by reimport/removal; the definition is already removed. */
        }
      }
    }
    return _synchronize();
  });

  Future<Map<String, dynamic>> importModel(
    SceneryManifest manifest,
    PreparedSceneryModel model,
  ) => _serial(() async {
    if (!manifest.assets.any(
      (a) => a.provider == 'managed' && a.uri == model.key,
    )) {
      throw const FormatException(
        'Imported model does not match the scenery definition',
      );
    }
    final referenced = (await _database(repository.list)).any(
      (m) => m.assets.any((a) => a.provider == 'managed' && a.uri == model.key),
    );
    // Track the entire owned transaction, including rollback, through disposal.
    // No new database operation may start once the controller is disposed.
    await _database(() async {
      final created = await storage.put(model.key, model.bytes);
      try {
        _checkOpen();
        await repository.create(manifest);
      } catch (_) {
        if (created && !referenced) await storage.remove(model.key);
        rethrow;
      }
    });
    // A bridge failure must retain both the definition and its committed bytes.
    return _synchronize();
  });

  Future<Uint8List?> readManagedModel(String key) async {
    if (_disposed || !isManagedSceneryKey(key)) return null;
    final definitions = await _database(repository.list);
    if (!definitions.any(
      (m) => m.assets.any((a) => a.provider == 'managed' && a.uri == key),
    )) {
      return null;
    }
    return _database(() => storage.read(key));
  }

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
