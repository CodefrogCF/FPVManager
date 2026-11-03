import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/osint/osint_cache_database.dart';
import '../../mobility/road_routing.dart';
import '../../observations/meteo_station_provider.dart' show decodeStationCsv;
import 'pollen_models.dart';
import 'pollen_parser.dart';

abstract interface class PollenCache {
  Future<List<PollenStation>?> readStations();
  Future<void> writeStations(List<PollenStation> stations);
  Future<PollenSnapshot?> readSnapshot(String stationId);
  Future<void> writeSnapshot(PollenSnapshot snapshot);
}

/// Public OSINT cache, not part of user profiles/backups.
class SqlitePollenCache implements PollenCache {
  SqlitePollenCache({OsintCacheDatabase? database})
    : database = database ?? OsintCacheDatabase.open(),
      _owns = database == null;
  final OsintCacheDatabase database;
  final bool _owns;
  static const _stationsKey = 'pollen-stations-v1';
  String _stationKey(String id) =>
      'pollen-v1-${sha256.convert(utf8.encode(id.toUpperCase()))}';

  Future<String?> _read(String key, int maxBytes) async {
    final row = await database.readSnapshot(key, maxBytes);
    if (row == null ||
        sha256.convert(utf8.encode(row.$1)).toString() != row.$2) {
      return null;
    }
    return row.$1;
  }

  Future<void> _write(String key, String json, int maxBytes) async {
    if (utf8.encode(json).length > maxBytes) {
      return;
    }
    await database.writeSnapshot(
      key,
      json,
      sha256.convert(utf8.encode(json)).toString(),
      DateTime.now().toUtc().add(const Duration(days: 7)),
    );
  }

  @override
  Future<List<PollenStation>?> readStations() async {
    try {
      final json = await _read(_stationsKey, 50000);
      if (json == null) {
        return null;
      }
      final rows = jsonDecode(json) as List<dynamic>;
      return rows
          .map((e) => PollenStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeStations(List<PollenStation> stations) => _write(
    _stationsKey,
    jsonEncode(stations.map((s) => s.toJson()).toList()),
    50000,
  );

  @override
  Future<PollenSnapshot?> readSnapshot(String stationId) async {
    try {
      final raw = await _read(_stationKey(stationId), 64000);
      return raw == null ? null : decodePollenSnapshot(raw).cached();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSnapshot(PollenSnapshot snapshot) => _write(
    _stationKey(snapshot.station.id),
    encodePollenSnapshot(snapshot),
    64000,
  );

  Future<void> dispose() async {
    if (_owns) {
      await database.close();
    }
  }
}

/// Application-side protection, not a claim about an official API quota.
class PollenRequestBudget {
  PollenRequestBudget({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  static final shared = PollenRequestBudget();
  final List<DateTime> _requests = [];
  final Map<String, DateTime> _lastPerResource = {};
  void reserve([String resource = 'general']) {
    final now = _clock().toUtc();
    _requests.removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    _lastPerResource.removeWhere(
      (_, t) => now.difference(t) >= const Duration(hours: 1),
    );
    final last = _lastPerResource[resource];
    if (_requests.length >= 20 ||
        (last != null && now.difference(last) < const Duration(seconds: 15))) {
      throw const FormatException('Pollen query throttled; retry later.');
    }
    _requests.add(now);
    _lastPerResource[resource] = now;
  }
}

class PollenService {
  PollenService({
    PollenCache? cache,
    MobilityHttp? transport,
    PollenRequestBudget? budget,
    DateTime Function()? now,
  }) : cache = cache ?? SqlitePollenCache(),
       _transport = transport ?? MobilityHttp(),
       _ownsTransport = transport == null,
       _now = now ?? DateTime.now,
       _budget =
           budget ??
           (now == null
               ? PollenRequestBudget.shared
               : PollenRequestBudget(clock: now));

  final PollenCache cache;
  final MobilityHttp _transport;
  final bool _ownsTransport;
  final DateTime Function() _now;
  final PollenRequestBudget _budget;
  Future<List<PollenStation>>? _stationsRequest;
  DateTime? _stationCheckUtc;
  List<PollenStation>? _stations;
  bool stationMetadataFromCache = false;
  bool stationMetadataRefreshFailed = false;
  DateTime? stationMetadataCheckedUtc;
  final Map<String, Future<PollenSnapshot>> _inFlight = {};
  bool _disposed = false;

  static final Uri stationsUri = Uri.parse(
    'https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/'
    'ogd-pollen_meta_stations.csv',
  );
  static Uri itemUri(String id) => Uri.https(
    'data.geo.admin.ch',
    '/api/stac/v1/collections/ch.meteoschweiz.ogd-pollen/items/'
        '${id.toLowerCase()}',
  );

  Future<String> _downloadText(Uri uri, {int maxBytes = 700000}) =>
      _transport.read<String>(
        uri,
        maxBytes: maxBytes,
        headers: const {'Accept': 'text/csv,application/json'},
        consume: (stream) async {
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in stream) {
            bytes.add(chunk);
          }
          return decodeStationCsv(bytes.takeBytes());
        },
      );

  /// Stations metadata refreshes at most once a day; supports offline reuse.
  Future<List<PollenStation>> stations({bool refresh = false}) {
    if (_disposed) {
      return Future.error(StateError('Pollen service closed'));
    }
    if (_stationsRequest != null) {
      return _stationsRequest!;
    }
    if (!refresh &&
        _stations != null &&
        _stationCheckUtc != null &&
        _now().toUtc().difference(_stationCheckUtc!) <
            const Duration(days: 1)) {
      return Future.value(_stations!);
    }
    late final Future<List<PollenStation>> request;
    request = _loadStations(refresh: refresh).then(
      (value) {
        if (identical(_stationsRequest, request)) {
          _stationsRequest = null;
        }
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_stationsRequest, request)) {
          _stationsRequest = null;
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
    _stationsRequest = request;
    return request;
  }

  Future<List<PollenStation>> _loadStations({required bool refresh}) async {
    final stored = _stations ?? await cache.readStations();
    if (!refresh && stored != null) {
      _stations = stored;
      stationMetadataFromCache = true;
      return stored;
    }
    try {
      _budget.reserve('stations');
      final csv = await _downloadText(stationsUri, maxBytes: 120000);
      final parsed = parsePollenStations(csv);
      if (_disposed) {
        throw StateError('Pollen service closed');
      }
      await cache.writeStations(parsed);
      _stations = parsed;
      _stationCheckUtc = _now().toUtc();
      stationMetadataCheckedUtc = _stationCheckUtc;
      stationMetadataFromCache = false;
      stationMetadataRefreshFailed = false;
      return parsed;
    } catch (_) {
      if (stored != null) {
        _stations = stored;
        stationMetadataFromCache = true;
        stationMetadataRefreshFailed = true;
        return stored;
      }
      rethrow;
    }
  }

  static double distanceKm(double lat, double lon, PollenStation station) {
    const r = 6371.0;
    double radians(double d) => d * math.pi / 180;
    final dLat = radians(station.latitude - lat);
    final dLon = radians(station.longitude - lon);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(lat)) *
            math.cos(radians(station.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  List<PollenStation> nearest(
    List<PollenStation> stations,
    double latitude,
    double longitude, {
    int maxResults = 5,
  }) {
    final ordered = List<PollenStation>.of(stations)
      ..sort(
        (a, b) => distanceKm(
          latitude,
          longitude,
          a,
        ).compareTo(distanceKm(latitude, longitude, b)),
      );
    return ordered.take(maxResults.clamp(1, 15)).toList();
  }

  Future<PollenSnapshot?> offline(String stationId) =>
      cache.readSnapshot(stationId);

  Future<PollenSnapshot> observations(
    PollenStation station, {
    bool refresh = false,
  }) {
    if (_disposed) {
      return Future.error(StateError('Pollen service closed'));
    }
    final pending = _inFlight[station.id];
    if (pending != null) {
      return pending;
    }
    late final Future<PollenSnapshot> request;
    request = _load(station, refresh: refresh).then(
      (value) {
        if (identical(_inFlight[station.id], request)) {
          _inFlight.remove(station.id);
        }
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_inFlight[station.id], request)) {
          _inFlight.remove(station.id);
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
    _inFlight[station.id] = request;
    return request;
  }

  Future<PollenSnapshot> _load(
    PollenStation station, {
    required bool refresh,
  }) async {
    final stored = await cache.readSnapshot(station.id);
    final now = _now().toUtc();
    if (!refresh && stored != null && stored.freshnessAt(now).name == 'fresh') {
      return stored;
    }
    try {
      _budget.reserve('station-${station.id}');
      final itemText = await _downloadText(
        itemUri(station.id),
        maxBytes: 160000,
      );
      final item = jsonDecode(itemText);
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid pollen STAC item');
      }
      final asset = pollenAssetFromStac(item, station.id);
      final csv = await _downloadText(asset.url, maxBytes: 700000);
      final parsed = parsePollenHourlyCsv(csv, station.id);
      final snapshot = PollenSnapshot(
        station: station,
        samples: parsed.samples,
        unknownParameters: parsed.unknownParameters,
        assetUrl: asset.url,
        fetchedUtc: _now().toUtc(),
        publishedUtc: asset.updatedUtc,
      );
      if (_disposed) {
        throw StateError('Pollen service closed');
      }
      await cache.writeSnapshot(snapshot);
      return snapshot;
    } catch (error) {
      if (stored != null) {
        return stored.cached(failed: true);
      }
      if (error is MobilityHttpException) {
        throw FormatException(
          'MeteoSwiss pollen HTTP ${error.statusCode}; no cached observations.',
        );
      }
      if (error is TimeoutException) {
        throw const FormatException('MeteoSwiss pollen request timed out.');
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_ownsTransport) {
      _transport.dispose();
    }
    if (cache is SqlitePollenCache) {
      await (cache as SqlitePollenCache).dispose();
    }
  }
}
