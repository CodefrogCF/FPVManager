import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:http/http.dart' as http;

import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_source.dart';
import '../mobility/road_routing.dart';
import 'station_observation.dart';

List<ObservationStation> parseHydroMetadata(Object? raw) {
  if (raw is! List || raw.length > 1000) {
    throw const FormatException('Ungültige hydrologische Stationsmetadaten');
  }
  final ids = <String>{};
  return [
    for (final value in raw)
      (() {
        if (value is! Map ||
            value['no'] is! String ||
            !RegExp(r'^\d{4}$').hasMatch(value['no']) ||
            value['name'] is! String ||
            value['latitude'] is! num ||
            value['longitude'] is! num ||
            value['status'] != 'Aufgebaut' ||
            !ids.add(value['no'] as String)) {
          throw const FormatException('Ungültige hydrologische Messstation');
        }
        return ObservationStation(
          id: value['no'] as String,
          name: value['name'] as String,
          position: MobilityPoint(
            (value['latitude'] as num).toDouble(),
            (value['longitude'] as num).toDouble(),
          ),
          elevation: (value['elevation'] as num?)?.toDouble(),
          readings: const [],
          metadata: Map<String, dynamic>.from(value),
        );
      })(),
  ];
}

Map<String, dynamic> parseHydroReadings(
  List<ObservationStation> stations,
  Map<String, dynamic> observations, {
  required DateTime now,
}) {
  final aggregate = observations['data_10min_mean'],
      live = observations['data_live'];
  if (aggregate is! List ||
      live is! List ||
      aggregate.length > 2000 ||
      live.length > 2000) {
    throw const FormatException('Hydrologisches Ergebnislimit überschritten');
  }
  final byId = {for (final s in stations) s.id: s};
  final latest = <String, Map<String, dynamic>>{}, units = <String, String>{};
  var unsupported = 0;
  for (final pair in [(aggregate, false), (live, true)]) {
    for (final raw in pair.$1) {
      if (raw is! Map) throw const FormatException('Ungültiger BAFU-Messwert');
      final id = pair.$2 ? raw['stationNo'] : (raw['station'] as Map?)?['no'];
      final code = raw['parameterName'];
      if (!byId.containsKey(id) || !{'W', 'Q', 'WT'}.contains(code)) {
        unsupported++;
        continue;
      }
      final value = raw['value'];
      if (value == null) continue;
      if (value is! num || !value.isFinite) {
        throw const FormatException('Ungültiger BAFU-Zahlenwert');
      }
      final at = observationUtc(raw['timestamp']);
      if (at.isBefore(now.toUtc().subtract(const Duration(hours: 4))) ||
          at.isAfter(now.toUtc().add(const Duration(minutes: 2)))) {
        throw const FormatException(
          'BAFU-Messwert außerhalb des Abfragefensters',
        );
      }
      final unit = raw['unitSymbol'];
      if (!pair.$2 && unit is String && unit.isNotEmpty && unit.length <= 80) {
        units['$id:$code'] = unit;
      }
      final key = '$id:$code:${pair.$2}';
      final previous = latest[key];
      if (previous == null ||
          at.isAfter(observationUtc(previous['timestamp']))) {
        latest[key] = Map<String, dynamic>.from(raw)..['live'] = pair.$2;
      }
    }
  }
  final output = <Map<String, dynamic>>[];
  for (final station in stations) {
    final readings = <StationReading>[];
    for (final entry in latest.entries.where(
      (e) => e.key.startsWith('${station.id}:'),
    )) {
      final raw = entry.value,
          code = raw['parameterName'] as String,
          isLive = raw['live'] == true;
      final quality = isLive
          ? switch (raw['releaseStatus']) {
              0 => 'unkorrigierter Live-Messwert (Status 0)',
              _ =>
                'Live-Freigabestatus: ${raw['releaseStatus'] ?? "nicht bereitgestellt"}',
            }
          : switch (raw['releaseState']?.toString()) {
              '1' => 'provisorisch (Status 1)',
              '2' => 'validiert (Status 2)',
              '3' => 'definitiv / ersetzt (Status 3)',
              _ =>
                'Freigabestatus: ${raw['releaseState'] ?? "nicht bereitgestellt"}',
            };
      readings.add(
        StationReading(
          parameter:
              '${switch (code) {
                'W' => 'Wasserstand',
                'Q' => 'Abfluss',
                _ => 'Wassertemperatur',
              }} · ${isLive ? "Live" : "10-Minuten-Mittel"}',
          value: (raw['value'] as num).toDouble(),
          unit: isLive
              ? units['${station.id}:$code'] ??
                    'native Einheit nicht bereitgestellt'
              : raw['unitSymbol'] as String? ?? 'Einheit nicht bereitgestellt',
          atUtc: observationUtc(raw['timestamp']),
          quality: quality,
          intervalMinutes: isLive ? null : 10,
        ),
      );
    }
    output.add(
      ObservationStation(
        id: station.id,
        name: station.name,
        position: station.position,
        elevation: station.elevation,
        readings: readings,
        metadata: {
          ...station.metadata,
          'readingsSource': [
            for (final e in latest.entries.where(
              (e) => e.key.startsWith('${station.id}:'),
            ))
              e.value,
          ],
        },
      ).toJson(),
    );
  }
  final result = <String, dynamic>{
    'stations': output,
    'unsupported': unsupported,
    'incomplete': aggregate.length == 2000 || live.length == 2000,
    'coverage': 'Höchstens zehn aktive Stationen im gewählten Umfeld; Messlücken sind möglich. Live und 10-Minuten-Mittel sind getrennte Produkte.',
  };
  readStations(result);
  return result;
}

class HydroStationProvider extends CachedOsintProvider<Map<String, dynamic>> {
  HydroStationProvider({
    required List<MobilityPoint> path,
    http.Client? client,
    super.persistentCache,
    super.now,
  }) : path = List.unmodifiable(path),
       transport = MobilityHttp(client: client),
       super(cacheDuration: const Duration(minutes: 10)) {
    if (path.isEmpty || path.length > 20000) {
      throw ArgumentError('Ungültiger Stationsbezug');
    }
  }
  final List<MobilityPoint> path;
  final MobilityHttp transport;
  DateTime? _lastAttempt;
  DateTime? _backoffUntil;
  bool _persistable = true;
  static final metadataUri = Uri.parse(
    'https://data.bafu.admin.ch/dataproduct-water-observations',
  );
  static final termsUri = Uri.parse(
    'https://data.bafu.admin.ch/lizenz-und-quelle',
  );
  @override
  OsintSource get source => _source;
  late final _source = OsintSource(
    id: 'bafu-hydro-v1-${sha256.convert(utf8.encode(jsonEncode(path.map((p) => p.toJson()).toList()))).toString().substring(0, 24)}',
    name: 'BAFU Hydrologische Messungen',
    publisher: 'BAFU / Partnerorganisationen',
    dataUri: Uri.parse('https://data.bafu.admin.ch/api'),
    metadataUri: metadataUri,
    licenseName: 'Freie Nutzung. Quellenangabe ist Pflicht.',
    licenseUri: termsUri,
    attribution: 'BAFU · Hydrologische Beobachtungen · data.bafu.admin.ch',
    coordinateReference:
        'EPSG:4326; Höhe und Wasserstand mit jeweiliger Quellenreferenz',
  );
  @override
  void validateData(Map<String, dynamic> data) {
    readStations(data);
  }

  Future<Map<String, dynamic>> _query(String document) async {
    try {
      final text = await transport.text(
        sourceUri,
        body: jsonEncode({'query': document}),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        maxBytes: 2 * 1024 * 1024,
        onHeaders: (h) {
          if ((h['cache-control'] ?? '').toLowerCase().contains('no-store')) {
            _persistable = false;
          }
        },
      );
      final result = jsonDecode(text);
      if (result is! Map ||
          result['errors'] != null ||
          result['data'] is! Map ||
          result['data']['water']?['observations'] is! Map) {
        throw const FormatException(
          'BAFU-Abfrage abgewiesen oder unvollständig; vorheriger Stand bleibt erhalten',
        );
      }
      return Map<String, dynamic>.from(
        result['data']['water']['observations'] as Map,
      );
    } on MobilityHttpException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 429) {
        _backoffUntil = nowUtc.add(const Duration(minutes: 1));
      }
      rethrow;
    }
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final time = nowUtc, previous = cached;
    if (previous != null &&
        time.isBefore(previous.cacheExpiresAtUtc) &&
        !previous.requiresRevalidation) {
      return previous;
    }
    if ((_backoffUntil != null && time.isBefore(_backoffUntil!)) ||
        (_lastAttempt != null &&
            time.difference(_lastAttempt!) < const Duration(seconds: 30))) {
      throw const FormatException(
        'BAFU-Abrufpause aktiv. Bitte nach mindestens 30 Sekunden erneut versuchen.',
      );
    }
    _lastAttempt = time;
    _persistable = true;
    var metadataCacheable = previous?.data['metadataCacheable'] != false;
    List<ObservationStation> metadata;
    final metaTime = DateTime.tryParse(
      '${previous?.data['metadataFetchedAtUtc']}',
    );
    if (previous?.data['stationMetadata'] is List &&
        metaTime != null &&
        time.difference(metaTime) < const Duration(days: 1)) {
      _persistable = metadataCacheable;
      metadata = [
        for (final m in previous!.data['stationMetadata'] as List)
          ObservationStation.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    } else {
      final raw = await _query(
        '{ water { observations { stations(where:{status:{_eq:"Aufgebaut"}},limit:1000) { no name siteName riverName latitude longitude elevation status coverageFrom coverageTo } } } }',
      );
      metadata = parseHydroMetadata(raw['stations']);
      metadataCacheable = _persistable;
    }
    final selected = nearbyStations(metadata, path, limit: 10);
    var readings = <String, dynamic>{
      'data_live': <dynamic>[],
      'data_10min_mean': <dynamic>[],
    };
    if (selected.isNotEmpty) {
      final ids = jsonEncode(selected.map((s) => s.id).toList()),
          from = time.subtract(const Duration(hours: 3)).toIso8601String(),
          until = time.toIso8601String();
      readings = await _query(
        '{ water { observations { data_10min_mean(where:{station:{no:{_in:$ids}},timestamp:{_gte:"$from",_lt:"$until"}},limit:2000) {parameterName unitName unitSymbol timestamp value releaseState station {no}} data_live(where:{stationNo:{_in:$ids},timestamp:{_gte:"$from",_lt:"$until"}},limit:2000) {stationNo parameterName timestamp value releaseStatus} } } }',
      );
    }
    final data = parseHydroReadings(selected, readings, now: time);
    data['stationMetadata'] = metadata.map((s) => s.toJson()).toList();
    data['metadataCacheable'] = metadataCacheable;
    data['metadataFetchedAtUtc'] =
        metaTime != null && time.difference(metaTime) < const Duration(days: 1)
        ? metaTime.toIso8601String()
        : time.toIso8601String();
    data['incomplete'] = data['incomplete'] == true || metadata.length == 1000;
    return OsintDataset(
      source: source,
      data: data,
      fetchedAtUtc: time,
      lastCheckedAtUtc: time,
      cacheExpiresAtUtc: time.add(cacheDuration),
      persistable: _persistable,
    );
  }

  @override
  void dispose() {
    transport.dispose();
    super.dispose();
  }
}
