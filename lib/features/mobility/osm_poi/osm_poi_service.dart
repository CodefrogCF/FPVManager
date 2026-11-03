import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../road_routing.dart';
import 'osm_poi_models.dart';

/// All Overpass queries are small, bounded and generated from an enum; no user QL.
String buildOverpassQuery(OsmPoiSearch search) {
  final lat = search.latitude.toStringAsFixed(5);
  final lon = search.longitude.toStringAsFixed(5);
  final categories = search.categories.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final clauses = categories.map(
    (category) =>
        'nwr(around:${search.radiusMeters},$lat,$lon)["${category.tagKey}"="${category.tagValue}"];',
  );
  return '[out:json][timeout:20][maxsize:33554432];\n(\n${clauses.join('\n')}\n);\nout center 301;';
}

abstract interface class OsmPoiCache {
  Future<OsmPoiSnapshot?> read(OsmPoiSearch search);
  Future<void> write(OsmPoiSnapshot snapshot);
}

/// Uses the pre-existing, separate OSINT cache DB, never personal backups.
/// Retains at most twelve bounded search snapshots, not a nationwide database.
class PersistentOsmPoiCache implements OsmPoiCache {
  PersistentOsmPoiCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;

  final OsintCacheDatabase database;
  final bool ownsDatabase;

  String _key(OsmPoiSearch search) =>
      'osm-nearby-${sha256.convert(utf8.encode(search.identity))}';

  @override
  Future<OsmPoiSnapshot?> read(OsmPoiSearch search) async {
    try {
      final row = await database.readSnapshot(_key(search), 550000);
      if (row == null) {
        return null;
      }
      if (sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final cached = OsmPoiSnapshot.decode(row.$1);
      if (DateTime.now().toUtc().difference(cached.fetchedAtUtc) >=
          const Duration(days: 14)) {
        await database.removeSnapshot(_key(search));
        return null;
      }
      return cached.search.identity == search.identity ? cached.cached() : null;
    } catch (_) {
      // A corrupt/old cached record must not prevent an intentional refresh.
      return null;
    }
  }

  @override
  Future<void> write(OsmPoiSnapshot snapshot) async {
    final payload = snapshot.encode();
    if (utf8.encode(payload).length > 550000) {
      return;
    }
    await database.writeSnapshot(
      _key(snapshot.search),
      payload,
      sha256.convert(utf8.encode(payload)).toString(),
      snapshot.fetchedAtUtc.add(const Duration(days: 14)),
    );
    await database.customStatement('''
      DELETE FROM osint_snapshots WHERE provider LIKE 'osm-nearby-%'
      AND provider NOT IN (
        SELECT provider FROM osint_snapshots WHERE provider LIKE 'osm-nearby-%'
        ORDER BY rowid DESC LIMIT 12
      )
    ''');
  }

  Future<void> dispose() async {
    if (ownsDatabase) {
      await database.close();
    }
  }
}

/// A conservative client-side policy; also respect HTTP 429/503 server limits.
class OsmPoiRequestBudget {
  OsmPoiRequestBudget({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  final List<DateTime> _requests = [];
  static final OsmPoiRequestBudget shared = OsmPoiRequestBudget();
  static const minInterval = Duration(seconds: 15);
  static const maxRequestsPerHour = 12;

  void reserve() {
    final time = now().toUtc();
    _requests.removeWhere(
      (date) => time.difference(date) >= const Duration(hours: 1),
    );
    if (_requests.isNotEmpty && time.difference(_requests.last) < minInterval) {
      throw const FormatException(
        'Please wait at least 15 seconds before another Overpass query.',
      );
    }
    if (_requests.length >= maxRequestsPerHour) {
      throw const FormatException(
        'Local Overpass budget exhausted (12 requests/hour).',
      );
    }
    _requests.add(time);
  }
}

/// Duplicate in-flight requests share one POST; fresh snapshots are served from cache.
/// Network failures may show *explicitly outdated* cached results, never faux live POIs.
class OsmPoiService {
  OsmPoiService({
    OsmPoiCache? cache,
    MobilityHttp? transport,
    OsmPoiRequestBudget? budget,
    DateTime Function()? now,
    Uri? endpoint,
  }) : cache = cache ?? PersistentOsmPoiCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _budget =
           budget ??
           (now == null
               ? OsmPoiRequestBudget.shared
               : OsmPoiRequestBudget(now: now)),
       _now = now ?? DateTime.now,
       endpoint =
           endpoint ?? Uri.parse('https://overpass-api.de/api/interpreter');

  final OsmPoiCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final OsmPoiRequestBudget _budget;
  final DateTime Function() _now;
  final Uri endpoint;
  final Map<String, Future<OsmPoiSnapshot>> _inFlight = {};

  Future<OsmPoiSnapshot?> readCached(OsmPoiSearch search) => cache.read(search);

  Future<OsmPoiSnapshot> search(
    OsmPoiSearch search, {
    bool forceRefresh = false,
  }) {
    final identity = search.identity;
    final existing = _inFlight[identity];
    if (existing != null) {
      return existing;
    }
    final current = _search(search, forceRefresh: forceRefresh);
    _inFlight[identity] = current;
    unawaited(
      current
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .whenComplete(() {
            _inFlight.remove(identity);
          }),
    );
    return current;
  }

  Future<OsmPoiSnapshot> _search(
    OsmPoiSearch search, {
    required bool forceRefresh,
  }) async {
    final cached = await cache.read(search);
    if (!forceRefresh && cached != null && !cached.isOutdated(_now())) {
      return cached;
    }
    try {
      _budget.reserve();
      final response = await _transport.text(
        endpoint,
        body: 'data=${Uri.encodeQueryComponent(buildOverpassQuery(search))}',
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Accept': 'application/json',
        },
        maxBytes: 450000,
      );
      final parsed = parseOverpassPois(response, search);
      final snapshot = OsmPoiSnapshot(
        search: search,
        fetchedAtUtc: _now().toUtc(),
        pois: parsed.pois,
        truncated: parsed.truncated,
      );
      await cache.write(snapshot);
      return snapshot;
    } on MobilityHttpException catch (error) {
      if (cached != null &&
          (error.statusCode >= 500 || error.statusCode == 429)) {
        return cached.cached(fallback: true);
      }
      if (error.statusCode == 429 || error.statusCode == 503) {
        throw const FormatException(
          'Overpass is busy or rate-limited. Retry manually later.',
        );
      }
      throw FormatException(
        'Overpass HTTP ${error.statusCode}; check connectivity and provider availability.',
      );
    } on TimeoutException {
      if (cached != null) {
        return cached.cached(fallback: true);
      }
      throw const FormatException(
        'Overpass timed out. Try a smaller radius later.',
      );
    }
  }

  Future<void> dispose() async {
    if (_ownsTransport) {
      _transport.dispose();
    }
    if (cache is PersistentOsmPoiCache) {
      await (cache as PersistentOsmPoiCache).dispose();
    }
  }
}
