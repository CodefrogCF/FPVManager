import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/osint_cache_database.dart';
import 'offline_region.dart';
import 'offline_region_package.dart';

OfflineMapStorage openOfflineMapStore() => NativeOfflineMapStore();

/// Fixed-source loopback tile transport. No arbitrary URL proxy or credentials.
class NativeOfflineMapStore implements OfflineMapStorage, PreparedMapStorage {
  @override
  bool get rendererReady => true;
  NativeOfflineMapStore({OsintCacheDatabase? database, http.Client? client})
    : database = database ?? OsintCacheDatabase.open(),
      client = client ?? http.Client(),
      _ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final http.Client client;
  final bool _ownsDatabase;
  final Map<
    String,
    Future<({Uint8List bytes, String mime, DateTime fetchedAt})>
  >
  _pending = {};
  bool _closed = false;
  int _activeDownloads = 0;
  final _downloadQueue = Queue<Completer<void>>();

  Future<void> _acquireDownload() async {
    if (_closed) throw StateError('Map cache closed');
    if (_activeDownloads < 8) {
      _activeDownloads++;
      return;
    }
    final waiting = Completer<void>();
    _downloadQueue.add(waiting);
    await waiting.future;
  }

  void _releaseDownload() {
    if (_downloadQueue.isNotEmpty) {
      _downloadQueue.removeFirst().complete();
    } else {
      _activeDownloads--;
    }
  }

  @override
  Future<List<OfflineRegion>> regions() async {
    final rows = await database
        .customSelect('SELECT payload FROM offline_regions ORDER BY id')
        .get();
    return [
      for (final row in rows)
        OfflineRegion.fromJson(
          jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
        ),
    ];
  }

  @override
  Future<void> setRegions(List<OfflineRegion> regions) async {
    activePreparedRegion(regions);
    if (regions.length > 12) {
      throw const FormatException('Keep at most 12 offline regions');
    }
    await database.transaction(() async {
      await database.customStatement('DELETE FROM offline_regions');
      for (final region in regions) {
        await database.customStatement(
          'INSERT INTO offline_regions VALUES(?,?)',
          [region.id, jsonEncode(region.toJson())],
        );
      }
      for (final tile in await tiles()) {
        if (!regions.any((r) => r.includesKey(tile.key))) {
          await database.customStatement(
            'DELETE FROM offline_tiles WHERE key=?',
            [tile.key],
          );
        }
      }
    });
  }

  @override
  Future<List<OfflineTileInfo>> tiles() async => [
    for (final row
        in await database
            .customSelect('SELECT key,byte_size,fetched_at FROM offline_tiles')
            .get())
      OfflineTileInfo(
        row.read<String>('key'),
        row.read<int>('byte_size'),
        DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('fetched_at'),
          isUtc: true,
        ),
      ),
  ];
  @override
  Future<void> clear() async {
    await setRegions([]);
  }

  @override
  Future<void> close() async {
    _closed = true;
    client.close();
    while (_downloadQueue.isNotEmpty) {
      _downloadQueue.removeFirst().completeError(
        StateError('Map cache closed'),
      );
    }
    await Future.wait(
      _pending.values.map(
        (f) => f.then<void>((_) {}).catchError((Object _) {}),
      ),
    );
    if (_ownsDatabase) await database.close();
  }

  Future<({Uint8List bytes, String mime, DateTime fetchedAt})> load(
    String key, {
    bool cacheOnly = false,
  }) {
    if (key == 'prepared.json') {
      return regions().then(
        (r) => (
          bytes: Uint8List.fromList(
            utf8.encode(jsonEncode(activePreparedRegion(r))),
          ),
          mime: 'application/json',
          fetchedAt: DateTime.now().toUtc(),
        ),
      );
    }
    if (preparedKey(key)) {
      return database
          .customSelect(
            'SELECT body,content_type,fetched_at FROM offline_tiles WHERE key=?',
            variables: [Variable(key)],
          )
          .getSingleOrNull()
          .then((row) {
            if (row == null || _closed) {
              throw StateError('Prepared resource missing');
            }
            return (
              bytes: row.read<Uint8List>('body'),
              mime: row.read<String>('content_type'),
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('fetched_at'),
                isUtc: true,
              ),
            );
          });
    }
    final uri = offlineSourceUri(key);
    if (uri == null || _closed) {
      return Future.error(
        const FormatException('Unsupported offline resource'),
      );
    }
    final requestKey = '$cacheOnly:$key';
    if (_pending.containsKey(requestKey)) return _pending[requestKey]!;
    if (_pending.length >= 256) {
      return Future.error(StateError('Tile request queue is full'));
    }
    late final Future<({Uint8List bytes, String mime, DateTime fetchedAt})>
    future;
    future = _load(key, uri, cacheOnly).whenComplete(() {
      _pending.remove(requestKey);
    });
    _pending[requestKey] = future;
    return future;
  }

  @override
  Future<void> importPackage(OfflineRegionPackage package) async {
    if (_closed) throw StateError('Map cache closed');
    await database.transaction(() async {
      final retained = (await regions())
          .where((r) => r.id != package.region.id)
          .map((r) => r.withPackageActive(false))
          .toList();
      if (retained.length >= 12) {
        throw const FormatException('Keep at most 12 offline regions');
      }
      final next = [...retained, package.region];
      // Pruning and replacement commit together; any failed write rolls back.
      await setRegions(next);
      final prefix = 'prepared/${package.region.packageId}/';
      final old = await tiles();
      final size =
          old
              .where((t) => !t.key.startsWith(prefix))
              .fold<int>(0, (n, t) => n + t.bytes) +
          package.files.values.fold<int>(0, (n, b) => n + b.length);
      if (size > offlineMapBudget) {
        throw const FormatException('Offline map storage limit reached');
      }
      for (final entry in package.files.entries) {
        await database.customStatement(
          'INSERT OR REPLACE INTO offline_tiles VALUES(?,?,?,?,?)',
          [
            '$prefix${entry.key}',
            entry.value,
            preparedMime(entry.key),
            package.region.preparedAt!.millisecondsSinceEpoch,
            entry.value.length,
          ],
        );
      }
    });
  }

  Future<({Uint8List bytes, String mime, DateTime fetchedAt})> _load(
    String key,
    Uri uri,
    bool cacheOnly,
  ) async {
    final old = await database
        .customSelect(
          'SELECT body,content_type,fetched_at FROM offline_tiles WHERE key=?',
          variables: [Variable(key)],
        )
        .getSingleOrNull();
    if (old != null) {
      return (
        bytes: cacheOnly && key == 'terrain/layer.json'
            ? cachedTerrainMetadata(
                old.read<Uint8List>('body'),
                (await tiles()).map((t) => t.key),
              )
            : cacheOnly && key.endsWith('.terrain')
            ? withoutTerrainMetadata(old.read<Uint8List>('body'))
            : old.read<Uint8List>('body'),
        mime: old.read<String>('content_type'),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          old.read<int>('fetched_at'),
          isUtc: true,
        ),
      );
    }
    if (cacheOnly) throw StateError('Offline resource missing');
    var cacheAllowed = true;
    await _acquireDownload();
    final abort = Completer<void>();
    final result =
        await (() async {
          if (_closed) throw StateError('Map cache closed');
          final request = http.AbortableRequest(
            'GET',
            uri,
            abortTrigger: abort.future,
          );
          request.followRedirects = false;
          if (key.startsWith('terrain/') && !key.endsWith('.json')) {
            request.headers['Accept'] = 'application/vnd.quantized-mesh;extensions=metadata,application/octet-stream;q=0.9';
          }
          final response = await client.send(request);
          cacheAllowed = !RegExp(
            'no-store|private',
            caseSensitive: false,
          ).hasMatch(response.headers['cache-control'] ?? '');
          if (response.statusCode != 200) throw StateError('Tile unavailable');
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in response.stream) {
            if (bytes.length + chunk.length > 4 * 1024 * 1024) {
              throw const FormatException('Tile exceeds size limit');
            }
            bytes.add(chunk);
          }
          return sanitizeOfflineTile(key, bytes.takeBytes());
        })().timeout(const Duration(seconds: 12)).whenComplete(() {
          if (!abort.isCompleted) abort.complete();
          _releaseDownload();
        });
    final time = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    );
    if (!_closed &&
        cacheAllowed &&
        (await regions()).any((r) => r.includesKey(key))) {
      await database.transaction(() async {
        if (!(await regions()).any((r) => r.includesKey(key))) return;
        final used =
            (await database
                    .customSelect(
                      'SELECT COALESCE(SUM(byte_size),0) AS n FROM offline_tiles',
                    )
                    .getSingle())
                .read<int>('n');
        final previous = await database
            .customSelect(
              'SELECT byte_size FROM offline_tiles WHERE key=?',
              variables: [Variable(key)],
            )
            .getSingleOrNull();
        if (used -
                (previous?.read<int>('byte_size') ?? 0) +
                result.bytes.length <=
            offlineMapBudget) {
          await database.customStatement(
            'INSERT OR REPLACE INTO offline_tiles VALUES(?,?,?,?,?)',
            [
              key,
              result.bytes,
              result.mime,
              time.millisecondsSinceEpoch,
              result.bytes.length,
            ],
          );
        }
      });
    }
    return (bytes: result.bytes, mime: result.mime, fetchedAt: time);
  }
}

Uint8List cachedTerrainMetadata(Uint8List bytes, Iterable<String> keys) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final template = (json['tiles'] as List).single as String;
  final date = RegExp(r'^(20[0-9]{6})/').firstMatch(template)?[1];
  final levels = <int, List<Map<String, int>>>{};
  for (final key in keys) {
    final m = RegExp(
      r'^terrain/(?:(20[0-9]{6})/)?(\d{1,2})/(\d{1,7})/(\d{1,7})\.terrain$',
    ).firstMatch(key);
    if (m == null || m[1] != date) continue;
    final z = int.parse(m[2]!), x = int.parse(m[3]!), y = int.parse(m[4]!);
    if (z > 18) continue;
    (levels[z] ??= []).add({'startX': x, 'endX': x, 'startY': y, 'endY': y});
  }
  final max = levels.keys.fold<int>(0, (a, b) => a > b ? a : b);
  json.remove('metadataAvailability');
  json['available'] = [for (var z = 0; z <= max; z++) levels[z] ?? []];
  json['maxzoom'] = max;
  json['extensions'] = [
    for (final e in json['extensions'] as List? ?? [])
      if (e != 'metadata') e,
  ];
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

/// Remove only live availability extension 4 from a cached quantized mesh.
Uint8List withoutTerrainMetadata(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  var offset = 88;
  int read32() {
    if (offset + 4 > bytes.length) {
      throw const FormatException('Truncated quantized mesh');
    }
    final value = view.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  final vertices = read32(), width = vertices > 65536 ? 4 : 2;
  offset += vertices * 6;
  offset = ((offset + width - 1) ~/ width) * width;
  final triangles = read32();
  offset += triangles * 3 * width;
  for (var i = 0; i < 4; i++) {
    final count = read32();
    offset += count * width;
  }
  if (offset > bytes.length) {
    throw const FormatException('Truncated quantized mesh');
  }
  final parts = <Uint8List>[Uint8List.sublistView(bytes, 0, offset)];
  var removed = false;
  while (offset < bytes.length) {
    final start = offset, id = bytes[offset++], length = read32();
    offset += length;
    if (offset > bytes.length) {
      throw const FormatException('Invalid quantized mesh extension');
    }
    if (id == 4) {
      removed = true;
    } else {
      parts.add(Uint8List.sublistView(bytes, start, offset));
    }
  }
  if (!removed) return bytes;
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.takeBytes();
}

Uri? offlineSourceUri(String key) {
  if (key == 'terrain/layer.json') {
    return Uri.parse(
      'https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/layer.json',
    );
  }
  final terrain = RegExp(
    r'^terrain/(?:(20[0-9]{6})/)?(\d{1,2})/(\d{1,7})/(\d{1,7})\.terrain$',
  ).firstMatch(key);
  if (terrain != null) {
    final z = int.parse(terrain[2]!),
        x = int.parse(terrain[3]!),
        y = int.parse(terrain[4]!);
    if (z > 18 || x >= 2 * (1 << z) || y >= (1 << z)) return null;
    return Uri.parse(
      'https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/${terrain[1] == null ? '' : '${terrain[1]}/'}$z/$x/$y.terrain',
    );
  }
  final image = RegExp(
    r'^imagery/(topographic|relief)/(\d{1,2})/(\d{1,7})/(\d{1,7})\.(jpeg|png)$',
  ).firstMatch(key);
  if (image == null) return null;
  final z = int.parse(image[2]!),
      x = int.parse(image[3]!),
      y = int.parse(image[4]!),
      relief = image[1] == 'relief';
  if (z > 19 ||
      x >= (1 << z) ||
      y >= (1 << z) ||
      image[5] != (relief ? 'png' : 'jpeg')) {
    return null;
  }
  return Uri.parse(
    'https://wmts.geo.admin.ch/1.0.0/${relief ? 'ch.swisstopo.swissalti3d-reliefschattierung' : 'ch.swisstopo.pixelkarte-farbe'}/default/current/3857/$z/$x/$y.${image[5]}',
  );
}

({Uint8List bytes, String mime}) sanitizeOfflineTile(
  String key,
  Uint8List bytes,
) {
  if (key.endsWith('.json')) {
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Terrain metadata exceeds limit');
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic> ||
        json['format'] != 'quantized-mesh-1.0' ||
        json['projection'] != 'EPSG:4326') {
      throw const FormatException('Unsupported terrain metadata');
    }
    final templates = json['tiles'];
    if (templates is! List ||
        templates.length != 1 ||
        templates.first is! String ||
        !RegExp(r'^(20[0-9]{6}/)?\{z\}/\{x\}/\{y\}\.terrain(\?v=\{version\})?$')
            .hasMatch(templates.first as String)) {
      throw const FormatException('Unsupported terrain tile template');
    }
    json.remove('parentUrl');
    json['tiles'] = [(templates.first as String).split('?').first];
    return (
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      mime: 'application/json',
    );
  }
  final png = key.endsWith('.png'), jpeg = key.endsWith('.jpeg');
  if (png &&
          (bytes.length < 8 ||
              bytes[0] != 137 ||
              bytes[1] != 80 ||
              bytes[2] != 78 ||
              bytes[3] != 71) ||
      jpeg && (bytes.length < 4 || bytes[0] != 255 || bytes[1] != 216) ||
      !png && !jpeg && bytes.length < 88) {
    throw const FormatException('Invalid cached tile');
  }
  return (
    bytes: bytes,
    mime: png
        ? 'image/png'
        : jpeg
        ? 'image/jpeg'
        : 'application/octet-stream',
  );
}
