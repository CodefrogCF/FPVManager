import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../road_routing.dart';
import 'ev_charging_models.dart';
import 'ev_charging_parser.dart';

/// HTTPS, WGS84 bounding-box query, maximum 200 features. No tile download.
/// This is the currently documented GeoAdmin Identify service, not the OCPI API
/// scheduled for December 2026 or the legacy HTTP-only GeoServer.
Uri geoAdminEvQuery(EvChargingArea area) {
  final bounds = area.envelope.map((n) => n.toStringAsFixed(6)).join(',');
  return Uri.https(
    'api3.geo.admin.ch',
    '/rest/services/ech/MapServer/identify',
    {
      'geometryType': 'esriGeometryEnvelope',
      'geometry': bounds,
      'mapExtent': bounds,
      'imageDisplay': '256,256,96',
      'tolerance': '0',
      'sr': '4326',
      'geometryFormat': 'geojson',
      'layers': 'all:ch.bfe.ladestellen-elektromobilitaet',
      'limit': '200',
      'returnGeometry': 'true',
      'lang': 'de',
    },
  );
}

abstract interface class EvChargingCache {
  Future<EvChargingSnapshot?> read(EvChargingArea area);
  Future<void> write(EvChargingSnapshot snapshot);
}

/// Existing separate OSINT database, never backed up with personal spots.
class SqliteEvChargingCache implements EvChargingCache {
  SqliteEvChargingCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;
  String _key(EvChargingArea area) =>
      'ev-charge-${sha256.convert(utf8.encode(area.identity))}';
  @override
  Future<EvChargingSnapshot?> read(EvChargingArea area) async {
    try {
      final row = await database.readSnapshot(_key(area), 650000);
      if (row == null ||
          sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final snapshot = EvChargingSnapshot.decode(row.$1);
      if (DateTime.now().toUtc().difference(snapshot.fetchedUtc) >
          const Duration(days: 3)) {
        await database.removeSnapshot(_key(area));
        return null;
      }
      return snapshot.area.identity == area.identity ? snapshot.cached() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(EvChargingSnapshot snapshot) async {
    final payload = snapshot.encode();
    if (utf8.encode(payload).length > 650000) return;
    await database.writeSnapshot(
      _key(snapshot.area),
      payload,
      sha256.convert(utf8.encode(payload)).toString(),
      snapshot.fetchedUtc.add(const Duration(days: 3)),
    );
    await database.customStatement('''
      DELETE FROM osint_snapshots WHERE provider LIKE 'ev-charge-%'
      AND provider NOT IN (SELECT provider FROM osint_snapshots
        WHERE provider LIKE 'ev-charge-%' ORDER BY rowid DESC LIMIT 12)
    ''');
  }

  Future<void> dispose() async {
    if (ownsDatabase) await database.close();
  }
}

class EvChargingBudget {
  EvChargingBudget({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  static final EvChargingBudget shared = EvChargingBudget();
  final List<DateTime> _history = [];
  void reserve() {
    final now = clock().toUtc();
    _history.removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    if (_history.length >= 20 ||
        (_history.isNotEmpty &&
            now.difference(_history.last) < const Duration(seconds: 10))) {
      throw const FormatException(
        'BFE request budget: wait 10 seconds, maximum 20 requests/hour.',
      );
    }
    _history.add(now);
  }
}

class EvChargingService {
  EvChargingService({
    EvChargingCache? cache,
    MobilityHttp? transport,
    EvChargingBudget? budget,
    DateTime Function()? now,
    Uri Function(EvChargingArea)? endpoint,
  }) : cache = cache ?? SqliteEvChargingCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _budget =
           budget ??
           (now == null
               ? EvChargingBudget.shared
               : EvChargingBudget(clock: now)),
       _now = now ?? DateTime.now,
       endpoint = endpoint ?? geoAdminEvQuery;
  final EvChargingCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final EvChargingBudget _budget;
  final DateTime Function() _now;
  final Uri Function(EvChargingArea) endpoint;
  final Map<String, Future<EvChargingSnapshot>> _inFlight = {};

  Future<EvChargingSnapshot?> offline(EvChargingArea area) => cache.read(area);

  Future<EvChargingSnapshot> search(
    EvChargingArea area, {
    bool refresh = false,
  }) {
    final pending = _inFlight[area.identity];
    if (pending != null) return pending;
    final future = _search(area, refresh: refresh);
    _inFlight[area.identity] = future;
    // Do not forward a failed Future through whenComplete (unhandled async error).
    unawaited(
      future.then<void>(
        (_) {
          _inFlight.remove(area.identity);
        },
        onError: (Object error, StackTrace stack) {
          _inFlight.remove(area.identity);
        },
      ),
    );
    return future;
  }

  Future<EvChargingSnapshot> _search(
    EvChargingArea area, {
    required bool refresh,
  }) async {
    final cached = await cache.read(area);
    if (!refresh && cached != null && !cached.isOld(_now())) return cached;
    try {
      _budget.reserve();
      final body = await _transport.text(
        endpoint(area),
        headers: const {'Accept': 'application/json'},
        maxBytes: 1500000,
      );
      final decoded = parseEvChargingResponse(body, area, _now().toUtc());
      await cache.write(decoded);
      return decoded;
    } on FormatException {
      if (cached != null) return cached.cached(failed: true);
      rethrow;
    } on TimeoutException {
      if (cached != null) return cached.cached(failed: true);
      throw const FormatException(
        'BFE timeout: retry with a smaller search area.',
      );
    } catch (_) {
      if (cached != null) return cached.cached(failed: true);
      throw const FormatException(
        'BFE charging service unavailable; no local snapshot.',
      );
    }
  }

  Future<void> dispose() async {
    if (_ownsTransport) _transport.dispose();
    if (cache is SqliteEvChargingCache) {
      await (cache as SqliteEvChargingCache).dispose();
    }
  }
}
