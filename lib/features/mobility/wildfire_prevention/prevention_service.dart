import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../road_routing.dart';
import 'prevention_models.dart';

/// Point Identify is intentionally used instead of a nationwide polygon query.
Uri preventionIdentifyUrl(double latitude, double longitude) {
  MobilityPoint(latitude, longitude);
  if (latitude < 45.5 ||
      latitude > 48.5 ||
      longitude < 5.5 ||
      longitude > 11.5) {
    throw const FormatException('Select a point in Switzerland.');
  }
  return Uri.https(
    'api3.geo.admin.ch',
    '/rest/services/ech/MapServer/identify',
    {
      'geometryType': 'esriGeometryPoint',
      'geometry':
          '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}',
      'layers': 'all:$preventionLayerId',
      'tolerance': '0',
      'returnGeometry': 'false',
      'sr': '4326',
      'lang': 'de',
      'limit': '50',
    },
  );
}

final Uri preventionLegendUrl = Uri.https(
  'api3.geo.admin.ch',
  '/rest/services/api/MapServer/$preventionLayerId/legend',
  {'lang': 'de'},
);

abstract interface class PreventionCache {
  Future<PreventionSnapshot?> read(String key);
  Future<void> write(String key, PreventionSnapshot snapshot);
}

class SqlitePreventionCache implements PreventionCache {
  SqlitePreventionCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;

  String _cacheKey(String key) =>
      'wildfire-prevention-${sha256.convert(utf8.encode(key))}';

  @override
  Future<PreventionSnapshot?> read(String key) async {
    try {
      final row = await database.readSnapshot(_cacheKey(key), 120000);
      if (row == null ||
          sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final snapshot = PreventionSnapshot.decode(row.$1);
      if (DateTime.now().toUtc().difference(snapshot.fetchedUtc) >
          const Duration(days: 14)) {
        await database.removeSnapshot(_cacheKey(key));
        return null;
      }
      return snapshot.cached();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, PreventionSnapshot snapshot) async {
    final payload = snapshot.encode();
    if (utf8.encode(payload).length > 120000) return;
    await database.writeSnapshot(
      _cacheKey(key),
      payload,
      sha256.convert(utf8.encode(payload)).toString(),
      snapshot.fetchedUtc.add(const Duration(days: 14)),
    );
    await database.customStatement('''
      DELETE FROM osint_snapshots WHERE provider LIKE 'wildfire-prevention-%'
      AND provider NOT IN (SELECT provider FROM osint_snapshots
        WHERE provider LIKE 'wildfire-prevention-%' ORDER BY rowid DESC LIMIT 16)
    ''');
  }

  Future<void> dispose() async {
    if (ownsDatabase) await database.close();
  }
}

class PreventionRequestBudget {
  PreventionRequestBudget({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  static final PreventionRequestBudget shared = PreventionRequestBudget();
  final List<DateTime> _history = [];
  void reserve() {
    final now = clock().toUtc();
    _history.removeWhere(
      (value) => now.difference(value) >= const Duration(hours: 1),
    );
    if (_history.length >= 12 ||
        (_history.isNotEmpty &&
            now.difference(_history.last) < const Duration(seconds: 10))) {
      throw const FormatException(
        'BAFU request budget: wait 10 seconds; maximum 12 manual lookups/hour.',
      );
    }
    _history.add(now);
  }
}

class PreventionService {
  PreventionService({
    PreventionCache? cache,
    MobilityHttp? transport,
    PreventionRequestBudget? budget,
    DateTime Function()? now,
    Uri Function(double, double)? identifyUrl,
    Uri? legendUrl,
  }) : cache = cache ?? SqlitePreventionCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _now = now ?? DateTime.now,
       _budget =
           budget ??
           (now == null
               ? PreventionRequestBudget.shared
               : PreventionRequestBudget(clock: now)),
       identifyUrl = identifyUrl ?? preventionIdentifyUrl,
       legendUrl = legendUrl ?? preventionLegendUrl;

  final PreventionCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final PreventionRequestBudget _budget;
  final DateTime Function() _now;
  final Uri Function(double, double) identifyUrl;
  final Uri legendUrl;
  final Map<String, Future<PreventionSnapshot>> _inFlight = {};

  String _key(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}';

  Future<PreventionSnapshot?> offline(double latitude, double longitude) {
    identifyUrl(latitude, longitude);
    return cache.read(_key(latitude, longitude));
  }

  Future<PreventionSnapshot> search(
    double latitude,
    double longitude, {
    bool refresh = false,
  }) {
    identifyUrl(latitude, longitude);
    final key = _key(latitude, longitude);
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _search(key, latitude, longitude, refresh: refresh);
    _inFlight[key] = future;
    unawaited(
      future.then<void>(
        (_) {
          _inFlight.remove(key);
        },
        onError: (Object error, StackTrace stack) {
          _inFlight.remove(key);
        },
      ),
    );
    return future;
  }

  Future<PreventionSnapshot> _search(
    String key,
    double latitude,
    double longitude, {
    required bool refresh,
  }) async {
    final cached = await cache.read(key);
    if (!refresh && cached != null && !cached.isOutdated(_now())) {
      return cached;
    }
    try {
      _budget.reserve();
      final body = await _transport.text(
        identifyUrl(latitude, longitude),
        maxBytes: 300000,
        headers: const {'Accept': 'application/json'},
      );
      String? publicationRaw;
      // Legend metadata is optional. Its failure MUST NOT erase identified
      // measures, and MUST NOT turn an undated record into an all-clear.
      try {
        final legend = await _transport.text(
          legendUrl,
          maxBytes: 200000,
          headers: const {'Accept': 'text/html'},
        );
        publicationRaw = parsePreventionLegendPublication(legend);
      } catch (_) {
        publicationRaw = null;
      }
      final result = parsePreventionIdentify(
        body,
        latitude: latitude,
        longitude: longitude,
        fetchedUtc: _now().toUtc(),
        publicationRaw: publicationRaw,
      );
      await cache.write(key, result);
      return result;
    } on FormatException {
      if (cached != null) return cached.cached(failed: true);
      rethrow;
    } on TimeoutException {
      if (cached != null) return cached.cached(failed: true);
      throw const FormatException(
        'BAFU request timed out. No current measures confirmed.',
      );
    } catch (_) {
      if (cached != null) return cached.cached(failed: true);
      throw const FormatException(
        'BAFU unavailable. No current measures confirmed.',
      );
    }
  }

  Future<void> dispose() async {
    if (_ownsTransport) _transport.dispose();
    if (cache is SqlitePreventionCache) {
      await (cache as SqlitePreventionCache).dispose();
    }
  }
}
