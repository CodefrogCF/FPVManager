import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/api_access_policy.dart';
import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'road_routing.dart';
import 'traffic_snapshot.dart';
import 'tmc_repository.dart';
import 'tmc_traffic_resolution.dart';

export 'traffic_snapshot.dart'
    show parseTrafficSnapshot, parseTrafficStream, trafficMaxResponseBytes;

enum SituationalKind { traffic, aircraft }

final astraTrafficAccess = ApiAccessPolicy(
  id: 'astra-traffic',
  name: 'ASTRA traffic situations',
  access: ApiAccessClass.verifiedFreeKey,
  registrationUri: Uri.parse('https://api-manager.opentransportdata.swiss/'),
);

String _text(Object? value, [int max = 800]) {
  final text = value?.toString() ?? '';
  return text.substring(0, text.length.clamp(0, max));
}

DateTime? _utc(String? value) {
  if (value == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// Positions are displayed as ground-projected awareness markers. Barometric
/// altitudes are not silently converted into Cesium ellipsoid/terrain heights.
Map<String, dynamic> parseAircraftSnapshot(String input) {
  if (input.length > 4 * 1024 * 1024) {
    throw const FormatException('Aircraft snapshot too large');
  }
  final json = jsonDecode(input) as Map<String, dynamic>;
  final records = json['ac'], epoch = json['now'];
  if (records is! List ||
      records.length > 5000 ||
      epoch is! num ||
      !epoch.isFinite ||
      epoch < 1e12 ||
      epoch > 1e14) {
    throw const FormatException('Unsupported readsb/adsb.lol response');
  }
  final published = DateTime.fromMillisecondsSinceEpoch(
    epoch.round(),
    isUtc: true,
  );
  final features = <Map<String, dynamic>>[], ids = <String>{};
  var unlocated = 0, omitted = 0;
  for (final raw in records) {
    if (raw is! Map) {
      omitted++;
      continue;
    }
    final lat = raw['lat'],
        lon = raw['lon'],
        seen = raw['seen_pos'],
        hex = raw['hex'];
    if (lat is! num ||
        lon is! num ||
        seen is! num ||
        !seen.isFinite ||
        seen < 0 ||
        hex is! String ||
        !RegExp(r'^~?[a-fA-F0-9]{6}$').hasMatch(hex)) {
      unlocated++;
      continue;
    }
    MobilityPoint point;
    try {
      point = MobilityPoint(lat.toDouble(), lon.toDouble());
    } on FormatException {
      unlocated++;
      continue;
    }
    if (features.length >= 1000 || !ids.add(hex)) {
      omitted++;
      continue;
    }
    if (seen > 86400) {
      omitted++;
      continue;
    }
    final timestamp = published.subtract(
      Duration(milliseconds: (seen * 1000).round()),
    );
    final baro = raw['alt_baro'], geom = raw['alt_geom'];
    String altitude(Object? value) => value is num && value.isFinite
        ? '${(value * .3048).toStringAsFixed(0)} m / $value ft'
        : _text(value ?? 'unknown', 40);
    features.add({
      'id': hex,
      'name': _text((raw['flight'] ?? hex).toString().trim(), 160),
      'timestampUtc': timestamp.toIso8601String(),
      'detail': _text(
        'Source: adsb.lol · ODbL 1.0\nICAO: $hex\nPosition: ${point.latitude}, ${point.longitude}\nPosition time: ${timestamp.toIso8601String()}\nBarometric altitude (not terrain AGL): ${altitude(baro)}\nReported geometric altitude: ${altitude(geom)}; source reference not independently verified.\n${_text(raw["type"], 40)} position; displayed on terrain, not at aircraft altitude.',
      ),
      'geometry': {'type': 'Point', 'coordinates': point.toJson()},
    });
  }
  return {
    'features': features,
    'publishedAtUtc': published.toIso8601String(),
    'unlocated': unlocated,
    'omitted': omitted,
    'coverage': 'Community ADS-B/MLAT reception within the requested radius; low-flying, non-transmitting and unreceived aircraft may be absent. No extrapolation.',
  };
}

class SituationalProvider extends CachedOsintProvider<Map<String, dynamic>> {
  SituationalProvider({
    required this.kind,
    required this.center,
    this.readTrafficKey,
    this.tmc,
    http.Client? client,
    super.now,
  }) : transport = MobilityHttp(client: client),
       super(
         cacheDuration: kind == SituationalKind.aircraft
             ? const Duration(seconds: 30)
             : const Duration(minutes: 5),
       ) {
    if (kind == SituationalKind.traffic && tmc != null) {
      addListener(_queueTmc);
      tmc!.addListener(_queueTmc);
    }
  }
  final SituationalKind kind;
  final MobilityPoint center;
  final Future<String?> Function()? readTrafficKey;
  final MobilityHttp transport;
  final TmcRepository? tmc;
  OsintDataset<Map<String, dynamic>>? _resolvedDataset;
  Map<String, dynamic>? _resolvingSource;
  String? _resolvedSignature;
  bool _tmcDisposed = false, _tmcAgain = false;
  int _tmcEpoch = 0;
  Future<void>? _resolution;
  String? tmcError;
  Future<void> get tmcSettled async {
    while (_resolution != null) {
      await _resolution;
    }
  }

  @override
  OsintProviderState<Map<String, dynamic>> get status {
    final base = super.status;
    final resolved = _resolvedDataset;
    if (resolved == null || !identical(_resolvingSource, base.dataset?.data)) {
      return base;
    }
    return OsintProviderState(
      update: base.update,
      freshness: base.freshness,
      checkedAtUtc: base.checkedAtUtc,
      dataset: resolved,
      lastAttemptAtUtc: base.lastAttemptAtUtc,
      error: base.error,
      servedFromCache: base.servedFromCache,
      cacheError: base.cacheError,
    );
  }

  void _queueTmc() {
    if (_tmcDisposed || tmc == null) return;
    final base = super.status.dataset;
    if (base == null) return;
    final needed = neededTmcVersions(base.data);
    if (needed.isEmpty &&
        !(base.data['records'] as List? ?? const [])
            .take(20000)
            .any(
              (r) =>
                  r is Map &&
                  (r['routingEvidence'] as List? ?? const [])
                      .take(32)
                      .any((p) => p is Map && p['tmc'] != null),
            )) {
      return;
    }
    unawaited(tmc!.restore(needed));
    final snapshots = tmc!.snapshots;
    final signature = [
      for (final v in needed)
        '$v:${snapshots[v]?.table.sha256sum}:${snapshots[v]?.imported}',
    ].join('|');
    if (identical(_resolvingSource, base.data) &&
        _resolvedSignature == signature) {
      return;
    }
    if (_resolution != null) {
      _tmcAgain = true;
      ++_tmcEpoch;
      return;
    }
    final epoch = ++_tmcEpoch;
    tmcError = null;
    _resolvingSource = base.data;
    _resolvedSignature = signature;
    _resolvedDataset = null;
    final completion = Completer<void>();
    _resolution = completion.future;
    unawaited(() async {
      try {
        final data = await compute(
          resolveTrafficTmc,
          TmcTrafficInput(
            base.data,
            {
              for (final v in needed)
                if (snapshots[v] != null) v: snapshots[v]!.table,
            },
            {
              for (final v in needed)
                if (snapshots[v] != null)
                  v: {
                    'verified': !snapshots[v]!.imported,
                    'retrievedUtc': snapshots[v]!.retrievedUtc
                        .toIso8601String(),
                    'publication': snapshots[v]!.table.publication,
                  },
            },
          ),
        );
        if (!_tmcDisposed && epoch == _tmcEpoch) {
          _resolvedDataset = OsintDataset(
            source: base.source,
            data: data,
            fetchedAtUtc: base.fetchedAtUtc,
            cacheExpiresAtUtc: base.cacheExpiresAtUtc,
            lastCheckedAtUtc: base.lastCheckedAtUtc,
            publishedAtUtc: base.publishedAtUtc,
            validity: base.validity,
            persistable: base.persistable,
            requiresRevalidation: base.requiresRevalidation,
            httpEtag: base.httpEtag,
            httpLastModified: base.httpLastModified,
          );
        }
      } catch (_) {
        if (!_tmcDisposed && epoch == _tmcEpoch) tmcError = 'TMC-Ortsauflösung nicht verfügbar. Ursprüngliche Meldungen bleiben erhalten; Tabellen prüfen oder erneut laden.';
        // Keep raw messages available; a failed reference lookup is not a live
        // traffic download failure and must never renew the source timestamp.
      } finally {
        _resolution = null;
        completion.complete();
        if (!_tmcDisposed) {
          if (_tmcAgain) {
            _tmcAgain = false;
            _resolvingSource = null;
            _queueTmc();
          }
          notifyListeners();
        }
      }
    }());
  }

  String? _import;
  Stream<List<int>>? _importStream;
  DateTime? _lastNetworkAttempt;
  TrafficSnapshot? _networkSnapshot;
  DateTime? _networkCheckedAt, _fullSnapshotAt;
  bool get canRefreshNetwork =>
      _lastNetworkAttempt == null ||
      nowUtc.difference(_lastNetworkAttempt!) >= const Duration(seconds: 15);
  void _rateLimit(Duration minimum) {
    final now = nowUtc;
    if (_lastNetworkAttempt != null &&
        now.difference(_lastNetworkAttempt!) < minimum) {
      throw FormatException(
        'Please wait at least ${minimum.inSeconds} seconds between source requests.',
      );
    }
    _lastNetworkAttempt = now;
  }

  static const trafficUrl =
      'https://api.opentransportdata.swiss/TDP/Soap_Datex2/TrafficSituations/Pull';
  @override
  OsintSource get source => kind == SituationalKind.traffic
      ? OsintSource(
          id: 'astra-traffic',
          name: 'Swiss traffic situations',
          publisher: 'ASTRA / VMZ-CH',
          dataUri: Uri.parse(trafficUrl),
          metadataUri: Uri.parse(
            'https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/traffic-situations/',
          ),
          licenseName: 'ASTRA VDP terms; own registered access, no raw API redistribution',
          licenseUri: Uri.parse(
            'https://opentransportdata.swiss/de/tac-fedro/',
          ),
          attribution: 'Datenquelle: Verkehrsdaten-Plattform (VDP) ASTRA',
          coordinateReference: 'EPSG:4326',
        )
      : OsintSource(
          id: 'adsb-lol-aircraft',
          name: 'Aircraft reception snapshot',
          publisher: 'adsb.lol community',
          dataUri: Uri.https(
            'api.adsb.lol',
            '/v2/lat/${center.latitude.toStringAsFixed(3)}/lon/${center.longitude.toStringAsFixed(3)}/dist/25',
          ),
          metadataUri: Uri.parse('https://api.adsb.lol/docs'),
          licenseName: 'ODbL 1.0',
          licenseUri: Uri.parse(
            'https://opendatacommons.org/licenses/odbl/1-0/',
          ),
          attribution: 'adsb.lol · ODbL 1.0',
          coordinateReference: 'EPSG:4326',
        );
  Future<OsintDataset<Map<String, dynamic>>> importText(String text) async {
    if (status.update == OsintUpdateState.loading) {
      throw StateError('An update is already running');
    }
    _import = text;
    try {
      return await fetch(forceRefresh: true);
    } finally {
      _import = null;
    }
  }

  Future<OsintDataset<Map<String, dynamic>>> importTrafficStream(
    Stream<List<int>> bytes,
  ) async {
    if (kind != SituationalKind.traffic ||
        status.update == OsintUpdateState.loading) {
      throw StateError('Traffic import unavailable');
    }
    _importStream = bytes;
    try {
      return await fetch(forceRefresh: true);
    } finally {
      _importStream = null;
    }
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final imported = _import != null || _importStream != null;
    String? body;
    Map<String, dynamic>? trafficData;
    TrafficSnapshot? nextSnapshot;
    DateTime? requestStarted;
    var delta = false;
    if (_importStream != null) {
      trafficData = (await readTrafficStream(_importStream!)).data();
    } else if (imported) {
      body = _import!;
    } else if (kind == SituationalKind.aircraft) {
      if (kIsWeb) {
        throw const FormatException(
          'adsb.lol does not allow direct browser requests (CORS). Import a source JSON snapshot, use Android, or open the provider map. No third-party proxy is used.',
        );
      }
      _rateLimit(const Duration(seconds: 15));
      body = await transport.text(sourceUri);
    } else {
      if (kIsWeb) {
        throw OsintProviderException(
          providerId: id,
          kind: OsintFailureKind.network,
          message: 'The ASTRA traffic API rejects direct browser requests (CORS). Use Android or import a DATEX XML snapshot downloaded with your own registered access. No third-party proxy is used.',
        );
      }
      final key = await readTrafficKey?.call();
      if (key == null ||
          key.trim().isEmpty ||
          key.length > 4096 ||
          key.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException(
          'Add your registered ASTRA API key, or import a DATEX snapshot.',
        );
      }
      // The current portal plan permits five calls/minute; allow headroom.
      _rateLimit(const Duration(seconds: 15));
      requestStarted = nowUtc;
      delta =
          _networkSnapshot != null &&
          _networkCheckedAt != null &&
          nowUtc.difference(_networkCheckedAt!) >= Duration.zero &&
          nowUtc.difference(_networkCheckedAt!) < const Duration(minutes: 4) &&
          _fullSnapshotAt != null &&
          nowUtc.difference(_fullSnapshotAt!) < const Duration(hours: 24);
      try {
        final patch = await transport.read<TrafficSnapshot>(
          sourceUri,
          maxBytes: trafficMaxResponseBytes,
          timeout: const Duration(seconds: 60),
          consume: readTrafficStream,
          onNotModified: delta ? () => TrafficSnapshot({}) : null,
          headers: {
            'Authorization': key.startsWith('Bearer ') ? key : 'Bearer $key',
            if (delta)
              'If-Modified-Since': _networkCheckedAt!
                  .subtract(const Duration(seconds: 30))
                  .toIso8601String(),
            'Content-Type': 'text/xml; charset=utf-8',
            'SOAPAction': 'http://opentransportdata.swiss/TDP/Soap_Datex2/Pull/v1/pullTrafficMessages',
          },
          body:
              '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><d2LogicalModel modelBaseVersion="2" xmlns="http://datex2.eu/schema/2/2_0"><exchange><supplierIdentification><country>ch</country><nationalIdentifier>FEDRO</nationalIdentifier></supplierIdentification><subscription><operatingMode>operatingMode1</operatingMode><subscriptionStartTime>${nowUtc.toIso8601String()}</subscriptionStartTime><subscriptionState>active</subscriptionState><updateMethod>singleElementUpdate</updateMethod><target><address></address><protocol>http</protocol></target></subscription></exchange></d2LogicalModel></soap:Body></soap:Envelope>',
        );
        nextSnapshot = delta ? _networkSnapshot!.merge(patch) : patch;
        trafficData = nextSnapshot.data();
        trafficData['updateMode'] = delta ? 'changes' : 'full';
      } on MobilityHttpException catch (error) {
        throw OsintProviderException(
          providerId: id,
          kind: OsintFailureKind.http,
          httpStatus: error.statusCode,
          message: switch (error.statusCode) {
            401 => 'ASTRA rejected the token (HTTP 401). Use the Token for "Road traffic - traffic situations", not Token Hash or an OJP token.',
            403 => 'ASTRA denied access (HTTP 403). Check that your app has an active "Road traffic - traffic situations" subscription.',
            429 => 'ASTRA request limit reached (HTTP 429). Wait before retrying and check the quota in your API plan.',
            _ =>
              'ASTRA request failed (HTTP ${error.statusCode}). Retry later or import a DATEX XML snapshot.',
          },
        );
      } on http.ClientException {
        throw OsintProviderException(
          providerId: id,
          kind: OsintFailureKind.network,
          message:
              'ASTRA network request failed. Check your connection and retry.',
        );
      }
    }
    final data =
        trafficData ??
        await compute<String, Map<String, dynamic>>(
          kind == SituationalKind.traffic
              ? parseTrafficSnapshot
              : parseAircraftSnapshot,
          body!,
        );
    data['transport'] = imported
        ? 'Imported local snapshot; not revalidated online'
        : 'Direct provider request';
    final time = nowUtc;
    final dataset = OsintDataset(
      source: source,
      data: data,
      fetchedAtUtc: time,
      cacheExpiresAtUtc: imported ? time : time.add(cacheDuration),
      publishedAtUtc: _utc(data['publishedAtUtc'] as String?),
      persistable: false,
      requiresRevalidation: imported,
    );
    if (imported) {
      _networkSnapshot = null;
      _networkCheckedAt = null;
      _fullSnapshotAt = null;
    } else if (nextSnapshot != null) {
      _networkSnapshot = nextSnapshot;
      _networkCheckedAt = requestStarted;
      if (!delta) _fullSnapshotAt = requestStarted;
    }
    return dataset;
  }

  @override
  void dispose() {
    _tmcDisposed = true;
    ++_tmcEpoch;
    tmc?.removeListener(_queueTmc);
    removeListener(_queueTmc);
    transport.dispose();
    super.dispose();
  }
}
