import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import 'offline_map_store_native.dart';
import 'offline_region.dart';
import 'offline_region_package.dart';

/// Staged writes never change the active region until publication succeeds.
class NativeOfflinePreparationStorage {
  NativeOfflinePreparationStorage(this.store);
  final NativeOfflineMapStore store;
  String? _id;
  Map<String, dynamic>? _job;
  int _used = 0, _count = 0;
  Future<int> remainingBytes(Map<String, dynamic> config) async {
    final estimate = config['estimatedBytes'] as int;
    final row = await store.database
        .customSelect(
          "SELECT body FROM offline_tiles WHERE key='preparation.json'",
        )
        .getSingleOrNull();
    if (row == null) return estimate;
    final job = jsonDecode(
      utf8.decode(row.read<Uint8List>('body')),
    ) as Map<String, dynamic>;
    if (job['signature'] != jsonEncode({...config}..remove('id')) ||
        job['id'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(job['id'] as String)) {
      return estimate;
    }
    final used = await store.database
        .customSelect(
          'SELECT COALESCE(SUM(byte_size),0) AS size FROM offline_tiles WHERE key LIKE ?',
          variables: [Variable('prepared/${job['id']}/%')],
        )
        .getSingle();
    return (estimate - used.read<int>('size')).clamp(0, estimate);
  }

  Future<Map<String, dynamic>> begin(Map<String, dynamic> config) async {
    final signature = jsonEncode({...config}..remove('id'));
    final row = await store.database
        .customSelect(
          "SELECT body FROM offline_tiles WHERE key='preparation.json'",
        )
        .getSingleOrNull();
    Map<String, dynamic>? job = row == null
        ? null
        : jsonDecode(utf8.decode(row.read<Uint8List>('body')))
              as Map<String, dynamic>;
    if (job == null || job['signature'] != signature) {
      final previous = job?['id'];
      if (previous is String &&
          !(await store.regions()).any((r) => r.packageId == previous)) {
        await store.database.customStatement(
          'DELETE FROM offline_tiles WHERE key LIKE ?',
          ['prepared/$previous/%'],
        );
      }
      final random = Random.secure();
      job = {
        'id': List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        'signature': signature,
        'regionId': config['id'],
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(job)));
      await store.database.customStatement(
        'INSERT OR REPLACE INTO offline_tiles VALUES(?,?,?,?,?)',
        [
          'preparation.json',
          bytes,
          'application/json',
          DateTime.now().millisecondsSinceEpoch,
          bytes.length,
        ],
      );
    }
    _id = job['id'] as String;
    _job = job;
    final size = await store.database
        .customSelect(
          'SELECT COALESCE(SUM(byte_size),0) AS size, COUNT(*) AS count FROM offline_tiles WHERE key LIKE ?',
          variables: [Variable('prepared/$_id/%')],
        )
        .getSingle();
    _used = size.read<int>('size');
    _count = size.read<int>('count');
    return job;
  }

  Future<void> bindSources(String id, String fingerprint) async {
    if (id != _id || !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid source fingerprint');
    }
    if (_job?['fingerprint'] != fingerprint && _count > 0) {
      await store.database.customStatement(
        'DELETE FROM offline_tiles WHERE key LIKE ?',
        ['prepared/$id/%'],
      );
      _used = 0;
      _count = 0;
    }
    _job!['fingerprint'] = fingerprint;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(_job)));
    await store.database.customStatement(
      'UPDATE offline_tiles SET body=?, byte_size=? WHERE key=?',
      [bytes, bytes.length, 'preparation.json'],
    );
  }

  String _key(String id, String key) {
    final full = 'prepared/$id/$key';
    if (id != _id || !preparedKey(full)) {
      throw const FormatException('Invalid prepared resource');
    }
    return full;
  }

  Future<bool> has(String id, String key) async =>
      (await store.database
          .customSelect(
            'SELECT key FROM offline_tiles WHERE key=?',
            variables: [Variable(_key(id, key))],
          )
          .getSingleOrNull()) !=
      null;
  Future<void> write(String id, String key, Uint8List bytes, int budget) async {
    final full = _key(id, key);
    if (bytes.length > 4 * 1024 * 1024 ||
        budget < 1048576 ||
        budget > 32 * 1024 * 1024 * 1024) {
      throw const FormatException('Invalid preparation size');
    }
    final old = await store.database
        .customSelect(
          'SELECT byte_size FROM offline_tiles WHERE key=?',
          variables: [Variable(full)],
        )
        .getSingleOrNull();
    final size = _used + bytes.length - (old?.read<int>('byte_size') ?? 0);
    if (size > budget) {
      throw const FormatException(
        'Speicherlimit erreicht. Vorhandene Region bleibt erhalten.',
      );
    }
    await store.database.customStatement(
      'INSERT OR REPLACE INTO offline_tiles VALUES(?,?,?,?,?)',
      [
        full,
        bytes,
        preparedMime(key),
        DateTime.now().millisecondsSinceEpoch,
        bytes.length,
      ],
    );
    _used = size;
    if (old == null) _count++;
  }

  Future<OfflineRegion> commit(Map<String, dynamic> json) async {
    if (json['packageId'] != _id || _count == 0) {
      throw const FormatException('Preparation incomplete');
    }
    final actual = await store.database
        .customSelect(
          'SELECT COUNT(*) AS count FROM offline_tiles WHERE key LIKE ?',
          variables: [Variable('prepared/$_id/%')],
        )
        .getSingle();
    if (json['packageTiles'] != actual.read<int>('count')) {
      throw const FormatException(
        'Vorbereitete Dateien wurden zwischenzeitlich verändert. Bitte erneut starten.',
      );
    }
    final region = OfflineRegion.fromJson({...json, 'packageTiles': _count});
    if (region.preparationVersion != 2) {
      throw const FormatException('Unknown preparation format');
    }
    if (region.includeTerrain && !await has(_id!, 'terrain/layer.json')) {
      throw const FormatException('Terrain metadata missing');
    }
    await store.database.transaction(() async {
      await store.setRegions([
        ...(await store.regions())
            .where((r) => r.id != region.id)
            .map((r) => r.withPackageActive(false)),
        region,
      ]);
    });
    return region;
  }
}
