import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../../../core/osint/osint_provider_state.dart';
import '../road_routing.dart';
import 'drought_metadata.dart';

final droughtVhiCollectionUrl = Uri.https(
  'data.geo.admin.ch',
  '/api/stac/v1/collections/$swissEoVhiCollection',
);
final droughtVhiItemsUrl = Uri.https(
  'data.geo.admin.ch',
  '/api/stac/v1/collections/$swissEoVhiCollection/items',
  {'limit': '12', 'sortby': '-datetime'},
);

abstract interface class DroughtMetadataCache {
  Future<DroughtVhiMetadata?> read();
  Future<void> write(DroughtVhiMetadata metadata);
}

/// Only small metadata records are persisted, never remote WMS/WMTS raster
/// tiles. OSINT cache is not part of user/profile backup exports.
class SqliteDroughtMetadataCache implements DroughtMetadataCache {
  SqliteDroughtMetadataCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;
  static const _key = 'drought-swiss-eo-vhi-metadata-v1';

  @override
  Future<DroughtVhiMetadata?> read() async {
    try {
      final row = await database.readSnapshot(_key, 12000);
      if (row == null ||
          sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final metadata = DroughtVhiMetadata.decode(row.$1);
      if (DateTime.now().toUtc().difference(metadata.fetchedUtc) >
          const Duration(days: 30)) {
        await database.removeSnapshot(_key);
        return null;
      }
      return metadata.asCached();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(DroughtVhiMetadata metadata) async {
    final payload = metadata.encode();
    if (utf8.encode(payload).length > 12000) {
      throw const FormatException('Metadata cache exceeds limit');
    }
    await database.writeSnapshot(
      _key,
      payload,
      sha256.convert(utf8.encode(payload)).toString(),
      metadata.fetchedUtc.add(const Duration(days: 30)),
    );
  }

  Future<void> dispose() async {
    if (ownsDatabase) {
      await database.close();
    }
  }
}

class DroughtRequestBudget {
  DroughtRequestBudget({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  static final DroughtRequestBudget shared = DroughtRequestBudget();
  final List<DateTime> _calls = [];
  void reserve() {
    final time = _clock().toUtc();
    _calls.removeWhere(
      (call) => time.difference(call) >= const Duration(hours: 1),
    );
    if (_calls.length >= 8 ||
        _calls.isNotEmpty &&
            time.difference(_calls.last) < const Duration(seconds: 30)) {
      throw const FormatException(
        'Wait 30 seconds; maximum 8 STAC metadata checks per hour.',
      );
    }
    _calls.add(time);
  }
}

class DroughtMetadataService {
  DroughtMetadataService({
    DroughtMetadataCache? cache,
    MobilityHttp? transport,
    DroughtRequestBudget? budget,
    DateTime Function()? clock,
    Uri? collectionUrl,
    Uri? itemsUrl,
  }) : cache = cache ?? SqliteDroughtMetadataCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _clock = clock ?? DateTime.now,
       _budget =
           budget ??
           (clock == null
               ? DroughtRequestBudget.shared
               : DroughtRequestBudget(clock: clock)),
       collectionUrl = collectionUrl ?? droughtVhiCollectionUrl,
       itemsUrl = itemsUrl ?? droughtVhiItemsUrl;

  final DroughtMetadataCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final DateTime Function() _clock;
  final DroughtRequestBudget _budget;
  final Uri collectionUrl, itemsUrl;
  Future<DroughtVhiMetadata>? _pending;
  bool _disposed = false;

  Future<DroughtVhiMetadata?> offline() => cache.read();

  Future<DroughtVhiMetadata> check({bool refresh = false}) {
    if (_disposed) {
      throw StateError('Metadata service disposed');
    }
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    final result = _check(refresh: refresh);
    _pending = result;
    unawaited(
      result.then<void>(
        (_) {
          _pending = null;
        },
        onError: (Object error, StackTrace trace) {
          _pending = null;
        },
      ),
    );
    return result;
  }

  Future<DroughtVhiMetadata> _check({required bool refresh}) async {
    final cached = await cache.read();
    if (!refresh &&
        cached != null &&
        cached.state(_clock()) == OsintDataState.fresh &&
        _clock().toUtc().difference(cached.fetchedUtc) <
            const Duration(hours: 6)) {
      return cached;
    }
    try {
      _budget.reserve();
      final collection = await _transport.text(
        collectionUrl,
        maxBytes: 100000,
        headers: const {'Accept': 'application/json'},
      );
      final items = await _transport.text(
        itemsUrl,
        maxBytes: 600000,
        headers: const {'Accept': 'application/geo+json, application/json'},
      );
      if (_disposed) {
        throw StateError('Metadata service disposed');
      }
      final parsed = parseDroughtVhiStac(
        collection,
        items,
        fetchedUtc: _clock().toUtc(),
      );
      await cache.write(parsed);
      return parsed;
    } catch (_) {
      if (cached != null) {
        return cached.asCached(failed: true);
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_ownsTransport) {
      _transport.dispose();
    }
    if (cache is SqliteDroughtMetadataCache) {
      await (cache as SqliteDroughtMetadataCache).dispose();
    }
  }
}
