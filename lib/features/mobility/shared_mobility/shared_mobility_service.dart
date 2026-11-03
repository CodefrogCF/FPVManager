import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../road_routing.dart';
import 'shared_mobility_models.dart';
import 'shared_mobility_parser.dart';

/// The documented REST identify endpoint filters on the server in metres.
/// Deliberately no nationwide GBFS download or automatic background polling.
Uri sharedMobilityIdentifyUri(
  SharedMobilityArea area,
) => Uri.https('api.sharedmobility.ch', '/v1/sharedmobility/identify', {
  'Geometry':
      '${area.longitude.toStringAsFixed(6)},${area.latitude.toStringAsFixed(6)}',
  'Tolerance': '${area.radiusMeters}',
  'offset': '0',
  'geometryFormat': 'esrijson',
});

abstract interface class SharedMobilityCache {
  Future<SharedMobilitySnapshot?> read(SharedMobilityArea area);
  Future<void> write(SharedMobilitySnapshot snapshot);
}

/// Local ephemeral OSINT cache is NOT part of personal profile backups.
class SqliteSharedMobilityCache implements SharedMobilityCache {
  SqliteSharedMobilityCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      ownsDatabase = database == null;
  final OsintCacheDatabase database;
  final bool ownsDatabase;
  String _key(SharedMobilityArea area) =>
      'shared-mobility-${sha256.convert(utf8.encode(area.identity))}';

  @override
  Future<SharedMobilitySnapshot?> read(SharedMobilityArea area) async {
    try {
      final row = await database.readSnapshot(_key(area), 650000);
      if (row == null ||
          sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
        return null;
      }
      final snapshot = SharedMobilitySnapshot.decode(row.$1);
      if (DateTime.now().toUtc().difference(snapshot.fetchedUtc) >
          const Duration(days: 1)) {
        await database.removeSnapshot(_key(area));
        return null;
      }
      return snapshot.area.identity == area.identity ? snapshot.cached() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(SharedMobilitySnapshot snapshot) async {
    final payload = snapshot.encode();
    if (utf8.encode(payload).length > 650000) {
      return;
    }
    await database.writeSnapshot(
      _key(snapshot.area),
      payload,
      sha256.convert(utf8.encode(payload)).toString(),
      snapshot.fetchedUtc.add(const Duration(days: 1)),
    );
    await database.customStatement('''
      DELETE FROM osint_snapshots WHERE provider LIKE 'shared-mobility-%'
      AND provider NOT IN (SELECT provider FROM osint_snapshots
        WHERE provider LIKE 'shared-mobility-%' ORDER BY rowid DESC LIMIT 12)
    ''');
  }

  Future<void> dispose() async {
    if (ownsDatabase) {
      await database.close();
    }
  }
}

class SharedMobilityRequestBudget {
  SharedMobilityRequestBudget({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  static final SharedMobilityRequestBudget shared =
      SharedMobilityRequestBudget();
  final List<DateTime> _requests = [];
  void reserve() {
    final now = clock().toUtc();
    _requests.removeWhere(
      (time) => now.difference(time) >= const Duration(hours: 1),
    );
    if (_requests.length >= 15 ||
        (_requests.isNotEmpty &&
            now.difference(_requests.last) < const Duration(seconds: 10))) {
      throw const FormatException(
        'Sharing request limit: 10-second interval, maximum 15/hour.',
      );
    }
    _requests.add(now);
  }
}

class SharedMobilityService {
  SharedMobilityService({
    SharedMobilityCache? cache,
    MobilityHttp? transport,
    SharedMobilityRequestBudget? budget,
    DateTime Function()? now,
    Uri Function(SharedMobilityArea)? endpoint,
  }) : cache = cache ?? SqliteSharedMobilityCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _clock = now ?? DateTime.now,
       _budget =
           budget ??
           (now == null
               ? SharedMobilityRequestBudget.shared
               : SharedMobilityRequestBudget(clock: now)),
       endpoint = endpoint ?? sharedMobilityIdentifyUri;
  final SharedMobilityCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final DateTime Function() _clock;
  final SharedMobilityRequestBudget _budget;
  final Uri Function(SharedMobilityArea) endpoint;
  final Map<String, Future<SharedMobilitySnapshot>> _inFlight = {};

  Future<SharedMobilitySnapshot?> offline(SharedMobilityArea area) =>
      cache.read(area);

  Future<SharedMobilitySnapshot> search(
    SharedMobilityArea area, {
    bool refresh = false,
  }) {
    final pending = _inFlight[area.identity];
    if (pending != null) {
      return pending;
    }
    final future = _search(area, refresh: refresh);
    _inFlight[area.identity] = future;
    // Swallow failure of the cleanup continuation, not of the original Future.
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

  Future<SharedMobilitySnapshot> _search(
    SharedMobilityArea area, {
    required bool refresh,
  }) async {
    final cached = await cache.read(area);
    if (!refresh &&
        cached != null &&
        !cached.isOld(_clock()) &&
        !cached.refreshFailed) {
      return cached;
    }
    try {
      _budget.reserve();
      Map<String, String> headers = {};
      final text = await _transport.text(
        endpoint(area),
        maxBytes: 1100000,
        headers: const {'Accept': 'application/json'},
        onHeaders: (incoming) => headers = incoming,
      );
      final snapshot = parseSharedMobilityResponse(
        text,
        area,
        _clock().toUtc(),
        headers: headers,
      );
      await cache.write(snapshot);
      return snapshot;
    } on MobilityHttpException catch (e) {
      if (cached != null) {
        return cached.cached(failed: true);
      }
      if (e.statusCode == 429) {
        throw const FormatException(
          'Sharing API is rate-limited (HTTP 429). Try again later.',
        );
      }
      throw FormatException(
        'Sharing API HTTP ${e.statusCode}; no saved results.',
      );
    } on TimeoutException {
      if (cached != null) {
        return cached.cached(failed: true);
      }
      throw const FormatException('Sharing API timeout; no saved results.');
    } on FormatException {
      if (cached != null) {
        return cached.cached(failed: true);
      }
      rethrow;
    } catch (_) {
      if (cached != null) {
        return cached.cached(failed: true);
      }
      throw const FormatException(
        'Sharing service unavailable; no saved results.',
      );
    }
  }

  Future<void> dispose() async {
    if (_ownsTransport) {
      _transport.dispose();
    }
    if (cache is SqliteSharedMobilityCache) {
      await (cache as SqliteSharedMobilityCache).dispose();
    }
  }
}
