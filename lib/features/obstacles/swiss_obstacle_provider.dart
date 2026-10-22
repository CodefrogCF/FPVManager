import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/osint_cache_database.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_provider.dart';
import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'kmz_obstacle_importer.dart';
import 'obstacle_models.dart';

class SwissObstacleProvider extends ChangeNotifier
    implements OsintProvider<ObstacleSnapshot> {
  SwissObstacleProvider({
    http.Client? client,
    OsintCacheDatabase? cache,
    OsintCacheDatabase Function()? cacheFactory,
    this.importer = const KmzObstacleImporter(),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _cache = cache,
       _cacheFactory = cacheFactory,
       _ownsCache = cache == null && cacheFactory == null,
       _clock = clock ?? DateTime.now;
  static final stacUri = Uri.parse(
    'https://data.geo.admin.ch/api/stac/v1/collections/ch.bazl.luftfahrthindernis/items?limit=10',
  );
  static final obstacleSource = OsintSource(
    id: 'swiss-obstacles',
    name: 'Swiss published aviation obstacles',
    publisher: 'BAZL / FOCA · Skyguide',
    dataUri: stacUri,
    metadataUri: Uri.parse(
      'https://www.bazl.admin.ch/de/luftfahrthindernisdaten-schweiz',
    ),
    attribution: 'BAZL / FOCA · Skyguide · geo.admin.ch',
    coordinateReference:
        'WGS84 longitude/latitude; absolute elevations: LN02 (EPSG:5728)',
  );
  final http.Client _client;
  final bool _ownsClient, _ownsCache;
  OsintCacheDatabase? _cache;
  final OsintCacheDatabase Function()? _cacheFactory;
  final KmzObstacleImporter importer;
  final DateTime Function() _clock;
  Future<void>? _loadingCache;
  Future<OsintDataset<ObstacleSnapshot>>? _refresh;
  Completer<void>? _abort;
  OsintDataset<ObstacleSnapshot>? _dataset;
  OsintProviderException? _error;
  bool _disposed = false, _loaded = false;
  OsintUpdateState _update = OsintUpdateState.idle;
  DateTime? _attempt;
  String _progress = 'Not downloaded';
  String get progress => _progress;
  OsintCacheDatabase get cache =>
      _cache ??= _cacheFactory?.call() ?? OsintCacheDatabase.open();
  Future<void> get settled async {
    try {
      await _refresh;
    } catch (_) {
      /* Last valid snapshot remains available. */
    }
    try {
      await _loadingCache;
    } catch (_) {
      /* Disposal still closes owned storage. */
    }
  }

  @override
  OsintSource get source => obstacleSource;
  @override
  String get id => source.id;
  @override
  Uri get sourceUri => stacUri;
  @override
  OsintProviderState<ObstacleSnapshot> get status => OsintProviderState(
    update: _update,
    freshness: _dataset?.freshnessAt(_clock()) ?? OsintFreshness.notLoaded,
    checkedAtUtc: _clock().toUtc(),
    dataset: _dataset,
    error: _error,
    lastAttemptAtUtc: _attempt,
    servedFromCache: _dataset != null && _update != OsintUpdateState.loading,
  );

  void _notify(String message) {
    if (_disposed) return;
    _progress = message;
    notifyListeners();
  }

  Future<void> loadCached() {
    if (_disposed) {
      return Future.error(StateError('Obstacle provider disposed'));
    }
    return _loadingCache ??= _readCache().catchError((
      Object error,
      StackTrace stack,
    ) {
      _loadingCache = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _readCache() async {
    final snapshot = await cache.obstacleSnapshot();
    await cache.cleanObstacleStaging();
    if (_disposed) return;
    if (snapshot != null) _dataset = _wrap(snapshot);
    _loaded = true;
    _notify(
      snapshot == null ? 'No local vector data' : 'Local vector data available',
    );
  }

  static DateTime? sourceDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final text = raw.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(
      RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text) ? text : '${text}Z',
    )?.toUtc();
  }

  OsintDataset<ObstacleSnapshot> _wrap(ObstacleSnapshot s) {
    final from = sourceDate(s.metadata['datasetValidFrom']);
    final until = sourceDate(
      s.metadata['datasetValidTo'] ?? s.metadata['dadasetValidTo'],
    );
    return OsintDataset(
      source: source,
      data: s,
      fetchedAtUtc: s.fetchedAt,
      cacheExpiresAtUtc: s.checkedAt.add(const Duration(days: 1)),
      lastCheckedAtUtc: s.checkedAt,
      publishedAtUtc: sourceDate(s.metadata['datasetPublishedAt']),
      validity: from == null && until == null
          ? null
          : OsintValidityPeriod(from: from, until: until),
    );
  }

  @override
  Future<OsintDataset<ObstacleSnapshot>> fetch({bool forceRefresh = false}) {
    if (_disposed) {
      return Future.error(StateError('Obstacle provider disposed'));
    }
    if (_refresh != null) return _refresh!;
    return _refresh = _fetch(forceRefresh).whenComplete(() => _refresh = null);
  }

  Future<OsintDataset<ObstacleSnapshot>> _fetch(bool force) async {
    String? staging;
    try {
      if (!_loaded) await loadCached();
      if (_disposed) throw StateError('Obstacle provider disposed');
      if (!force && _dataset?.freshnessAt(_clock()) == OsintFreshness.fresh) {
        return _dataset!;
      }
      _attempt = _clock().toUtc();
      _update = OsintUpdateState.loading;
      _error = null;
      _abort = Completer<void>();
      _notify('Checking official STAC metadata…');
      final asset = await _discover();
      final old = _dataset?.data;
      if (old != null &&
          old.assetUrl == asset.url.toString() &&
          (asset.checksum.isNotEmpty
              ? old.checksum == asset.checksum
              : asset.updated != null && old.sourceUpdated == asset.updated)) {
        final checked = ObstacleSnapshot(
          key: old.key,
          assetUrl: old.assetUrl,
          checksum: old.checksum,
          sourceUpdated: asset.updated,
          fetchedAt: old.fetchedAt,
          checkedAt: _clock().toUtc(),
          count: old.count,
          skipped: old.skipped,
          metadata: old.metadata,
        );
        final wrapped = _wrap(checked);
        if (_disposed) throw StateError('Obstacle provider disposed');
        await cache.publishObstacles(checked);
        _dataset = wrapped;
      } else {
        _notify('Downloading full KMZ (up to 32 MB)…');
        final bytes = await _download(
          asset.url,
          importer.maxArchiveBytes,
        ).timeout(const Duration(minutes: 3));
        if (asset.checksum.isNotEmpty &&
            '1220${sha256.convert(bytes)}' != asset.checksum) {
          throw const FormatException('KMZ SHA-256 checksum mismatch');
        }
        staging =
            '${_clock().microsecondsSinceEpoch}-${identityHashCode(bytes)}';
        var lastPercent = -1;
        final result = await importer.import(
          bytes,
          cancelled: () => _disposed,
          onProgress: (fraction) {
            final percent = (fraction * 100).floor();
            if (percent != lastPercent) {
              lastPercent = percent;
              _notify('Importing obstacles… $percent%');
            }
          },
          onBatch: (batch) => cache.stageObstacles(staging!, batch),
        );
        if (_disposed) throw StateError('Obstacle provider disposed');
        final snapshot = ObstacleSnapshot(
          key: staging,
          assetUrl: asset.url.toString(),
          checksum: asset.checksum,
          sourceUpdated: asset.updated,
          fetchedAt: _clock().toUtc(),
          checkedAt: _clock().toUtc(),
          count: result.count,
          skipped: result.skipped,
          metadata: result.metadata,
        );
        final wrapped = _wrap(
          snapshot,
        ); // Validate metadata before publication.
        await cache.publishObstacles(snapshot);
        _dataset = wrapped;
        staging = null;
      }
      _update = OsintUpdateState.ready;
      _notify('Official metadata checked; local snapshot ready');
      return _dataset!;
    } catch (e) {
      if (staging != null) {
        try {
          await cache.discardObstacles(staging);
        } catch (_) {
          /* Cleaned on next open. */
        }
      }
      final failure = OsintProviderException(
        providerId: id,
        kind: _disposed
            ? OsintFailureKind.disposed
            : e is TimeoutException
            ? OsintFailureKind.timeout
            : e is FormatException
            ? OsintFailureKind.invalidData
            : OsintFailureKind.network,
        message: 'Obstacle update failed: $e',
      );
      if (!_disposed) {
        _error = failure;
        _update = OsintUpdateState.failed;
        _notify(
          _dataset == null
              ? 'No vector dataset available'
              : 'Update failed; previous local snapshot retained',
        );
      }
      throw failure;
    } finally {
      if (_abort?.isCompleted == false) _abort!.complete();
      _abort = null;
    }
  }

  Future<Uint8List> _download(Uri uri, int limit) async {
    if (!_official(uri)) {
      throw const FormatException('Unsupported STAC asset host');
    }
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: _abort?.future,
    )..followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
      await response.stream.listen((_) {}).cancel();
      throw FormatException(
        'Source returned HTTP ${response.statusCode} or exceeded size limit',
      );
    }
    final result = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 25),
    )) {
      if (_disposed || result.length + chunk.length > limit) {
        throw const FormatException(
          'Source size limit exceeded or request cancelled',
        );
      }
      result.add(chunk);
    }
    return result.takeBytes();
  }

  static bool _official(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'data.geo.admin.ch' &&
      !uri.hasPort &&
      uri.userInfo.isEmpty;
  Future<_Asset> _discover() async {
    Uri? next = stacUri;
    final assets = <_Asset>[];
    for (var page = 0; next != null && page < 4; page++) {
      final raw = jsonDecode(
        utf8.decode(await _download(next, 2 * 1024 * 1024)),
      );
      if (raw is! Map ||
          raw['features'] is! List ||
          (raw['features'] as List).length > 100) {
        throw const FormatException('Unsupported STAC response');
      }
      for (final item in raw['features'] as List) {
        if (item is! Map || item['assets'] is! Map) continue;
        final props = item['properties'] is Map
            ? item['properties'] as Map
            : const {};
        for (final entry in (item['assets'] as Map).entries) {
          final a = entry.value;
          if (a is! Map ||
              a['type'] != 'application/vnd.google-earth.kmz' ||
              entry.key.toString().toLowerCase().contains('simpl')) {
            continue;
          }
          final url = Uri.tryParse(a['href']?.toString() ?? '');
          if (url == null ||
              !_official(url) ||
              !url.path.toLowerCase().endsWith('.kmz')) {
            continue;
          }
          if (a['proj:epsg'] != null && a['proj:epsg'] != 4326) continue;
          final checksum = a['file:checksum']?.toString().toLowerCase() ?? '';
          if (checksum.isNotEmpty &&
              !RegExp(r'^1220[0-9a-f]{64}$').hasMatch(checksum)) {
            throw const FormatException('Unsupported STAC asset checksum');
          }
          assets.add(
            _Asset(
              url,
              checksum,
              sourceDate(
                (a['updated'] ?? props['updated'] ?? props['datetime'])
                    ?.toString(),
              ),
            ),
          );
        }
      }
      next = null;
      if (raw['links'] is List) {
        final link = (raw['links'] as List)
            .whereType<Map>()
            .where((l) => l['rel'] == 'next')
            .firstOrNull;
        if (link != null) {
          final uri = stacUri.resolve(link['href']?.toString() ?? '');
          if (!_official(uri) || uri.path != stacUri.path) {
            throw const FormatException('Unsupported STAC pagination');
          }
          next = uri;
        }
      }
    }
    if (next != null) {
      throw const FormatException('STAC pagination limit exceeded');
    }
    if (assets.isEmpty) {
      throw const FormatException(
        'No supported full WGS84 KMZ asset available; other formats are not imported',
      );
    }
    assets.sort(
      (a, b) =>
          (b.updated ?? DateTime(1970)).compareTo(a.updated ?? DateTime(1970)),
    );
    return assets.first;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _update = OsintUpdateState.disposed;
    if (_abort?.isCompleted == false) _abort!.complete();
    if (_ownsClient) _client.close();
    if (_ownsCache && _cache != null) {
      unawaited(() async {
        try {
          await _loadingCache;
          await _refresh;
        } catch (_) {
          /* Close after failed/cancelled imports. */
        }
        await _cache!.close();
      }());
    }
    super.dispose();
  }
}

class _Asset {
  const _Asset(this.url, this.checksum, this.updated);
  final Uri url;
  final String checksum;
  final DateTime? updated;
}
