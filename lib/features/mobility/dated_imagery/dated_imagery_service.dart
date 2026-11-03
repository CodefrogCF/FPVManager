import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../road_routing.dart';
import 'dated_imagery_models.dart';

abstract interface class DatedImageryCache {
  Future<DatedImagerySnapshot?> read(DatedImageryProduct product);
  Future<void> write(DatedImagerySnapshot snapshot);
}

/// The two latest *metadata* snapshots are kept separate from user backups;
/// no satellite raster tiles are retained by this service.
class SqliteDatedImageryCache implements DatedImageryCache {
  SqliteDatedImageryCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;

  String _key(DatedImageryProduct product) =>
      'dated-imagery-stac-v1-${product.name}';

  @override
  Future<DatedImagerySnapshot?> read(DatedImageryProduct product) async {
    try {
      final row = await database.readSnapshot(_key(product), 100000);
      if (row == null ||
          sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final result = DatedImagerySnapshot.decode(row.$1);
      if (result.product != product) {
        return null;
      }
      if (DateTime.now().toUtc().difference(result.fetchedUtc) >
          const Duration(days: 7)) {
        await database.removeSnapshot(_key(product));
        return null;
      }
      return result.saved();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(DatedImagerySnapshot snapshot) async {
    final data = snapshot.encode();
    if (utf8.encode(data).length > 100000) {
      throw const FormatException('Imagery metadata is too large to save');
    }
    await database.writeSnapshot(
      _key(snapshot.product),
      data,
      sha256.convert(utf8.encode(data)).toString(),
      snapshot.fetchedUtc.add(const Duration(days: 7)),
    );
  }

  Future<void> close() async {
    if (ownsDatabase) {
      await database.close();
    }
  }
}

class DatedImageryRequestBudget {
  DatedImageryRequestBudget({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  static final DatedImageryRequestBudget shared = DatedImageryRequestBudget();
  final List<DateTime> _calls = [];

  void reserve() {
    final now = _clock().toUtc();
    _calls.removeWhere(
      (call) => now.difference(call) >= const Duration(hours: 1),
    );
    if (_calls.length >= 12 ||
        _calls.isNotEmpty &&
            now.difference(_calls.last) < const Duration(seconds: 15)) {
      throw const FormatException(
        'Wait at least 15 seconds; maximum 12 imagery catalog checks per hour.',
      );
    }
    _calls.add(now);
  }
}

/// Location-limited STAC discovery. On failure the previous snapshot is
/// returned *with a failure flag*; old data is never presented as fresh.
class DatedImageryService {
  DatedImageryService({
    DatedImageryCache? cache,
    MobilityHttp? transport,
    DatedImageryRequestBudget? budget,
    DateTime Function()? clock,
    Uri? stacRoot,
  }) : cache = cache ?? SqliteDatedImageryCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _clock = clock ?? DateTime.now,
       _budget =
           budget ??
           (clock == null
               ? DatedImageryRequestBudget.shared
               : DatedImageryRequestBudget(clock: clock)),
       stacRoot =
           stacRoot ??
           Uri.https('data.geo.admin.ch', '/api/stac/v1/collections');

  final DatedImageryCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final DateTime Function() _clock;
  final DatedImageryRequestBudget _budget;
  final Uri stacRoot;
  final Map<String, Future<DatedImagerySnapshot>> _inFlight = {};
  bool _disposed = false;

  static List<double> bounds(double lat, double lon, int radiusMetres) {
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        radiusMetres < 500 ||
        radiusMetres > 5000) {
      throw const FormatException('Imagery search radius must be 500–5000 m');
    }
    final latDelta = radiusMetres / 111320.0;
    final lonDelta =
        radiusMetres /
        (111320.0 * math.max(0.2, math.cos(lat * math.pi / 180)));
    return [
      double.parse((lon - lonDelta).clamp(-180.0, 180.0).toStringAsFixed(5)),
      double.parse((lat - latDelta).clamp(-90.0, 90.0).toStringAsFixed(5)),
      double.parse((lon + lonDelta).clamp(-180.0, 180.0).toStringAsFixed(5)),
      double.parse((lat + latDelta).clamp(-90.0, 90.0).toStringAsFixed(5)),
    ];
  }

  Future<DatedImagerySnapshot?> offline(DatedImageryProduct product) =>
      cache.read(product);

  Future<DatedImagerySnapshot> search({
    required DatedImageryProduct product,
    required double latitude,
    required double longitude,
    required int radiusMetres,
    bool refresh = false,
  }) {
    if (_disposed) {
      throw StateError('Imagery service disposed');
    }
    final area = bounds(latitude, longitude, radiusMetres);
    final key = '${product.name}:${area.join(',')}:${refresh ? 1 : 0}';
    final pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }
    final result = _search(product, area, refresh: refresh);
    _inFlight[key] = result;
    unawaited(
      result.then<void>(
        (_) {
          _inFlight.remove(key);
        },
        onError: (Object error, StackTrace trace) {
          _inFlight.remove(key);
        },
      ),
    );
    return result;
  }

  Future<DatedImagerySnapshot> _search(
    DatedImageryProduct product,
    List<double> area, {
    required bool refresh,
  }) async {
    final saved = await cache.read(product);
    final matching = saved != null && _sameArea(saved.area, area)
        ? saved
        : null;
    if (!refresh &&
        matching != null &&
        !matching.isOld(_clock()) &&
        _clock().toUtc().difference(matching.fetchedUtc) <
            const Duration(hours: 6)) {
      return matching;
    }
    try {
      _budget.reserve();
      final base = stacRoot.replace(
        path: '${stacRoot.path}/${product.collection}',
      );
      final params = <String, String>{
        'bbox': area.join(','),
        'limit': '16',
        'sortby': '-datetime',
      };
      // Do not omit older event missions by imposing the swissEO rolling window.
      if (product == DatedImageryProduct.swissEo) {
        params['datetime'] =
            '${_clock().toUtc().subtract(const Duration(days: 100)).toIso8601String()}/..';
      }
      final collection = await _transport.text(
        base,
        maxBytes: 100000,
        headers: const {'Accept': 'application/json'},
      );
      final items = await _transport.text(
        base.replace(path: '${base.path}/items', queryParameters: params),
        maxBytes: 650000,
        headers: const {'Accept': 'application/geo+json, application/json'},
      );
      if (_disposed) {
        throw StateError('Imagery service disposed');
      }
      final snapshot = parseDatedImageryStac(
        collection,
        items,
        product: product,
        fetchedUtc: _clock().toUtc(),
        requestedBounds: area,
      );
      await cache.write(snapshot);
      return snapshot;
    } catch (_) {
      if (matching != null) {
        return matching.saved(failed: true);
      }
      rethrow;
    }
  }

  bool _sameArea(List<double> x, List<double> y) =>
      x.length == 4 &&
      y.length == 4 &&
      List.generate(4, (index) => x[index] == y[index]).every((b) => b);

  Future<void> dispose() async {
    _disposed = true;
    if (_ownsTransport) {
      _transport.dispose();
    }
    if (cache is SqliteDatedImageryCache) {
      await (cache as SqliteDatedImageryCache).close();
    }
  }
}
