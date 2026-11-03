import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

import '../../../core/osint/api_access_policy.dart';
import '../road_routing.dart';
import 'ojp_models.dart';
import 'ojp_parser.dart';

/// Official, free-with-registration OJP 2.0 product. Never use an OJP 1.0 key.
final ojp20Access = ApiAccessPolicy(
  id: 'ojp20',
  name: 'Open Journey Planner 2.0',
  access: ApiAccessClass.verifiedFreeKey,
  registrationUri: Uri.parse('https://api-manager.opentransportdata.swiss/'),
);

/// Published API-manager plans; limits are per API key across all clients.
enum OjpApiPlan {
  free(50, 20000, 'Kostenlos · 50/min · 20 000/Tag'),
  standard(2500, 1000000, 'CHF 500/Monat · 2500/min'),
  extended(5000, 2000000, 'CHF 1000/Monat · 5000/min');

  const OjpApiPlan(this.perMinute, this.perDay, this.label);
  final int perMinute, perDay;
  final String label;
}

class OjpRequestLimit {
  OjpRequestLimit({this.plan = OjpApiPlan.free, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  OjpApiPlan plan;
  final DateTime Function() _now;
  final Queue<DateTime> _minute = Queue<DateTime>();
  final Queue<DateTime> _day = Queue<DateTime>();
  DateTime? blockedUntil;

  void reserve() {
    final now = _now().toUtc();
    if (blockedUntil != null && now.isBefore(blockedUntil!)) {
      throw const FormatException('OJP rate limit reached. Retry later.');
    }
    while (_minute.isNotEmpty &&
        !_minute.first.isAfter(now.subtract(const Duration(minutes: 1)))) {
      _minute.removeFirst();
    }
    while (_day.isNotEmpty &&
        !_day.first.isAfter(now.subtract(const Duration(days: 1)))) {
      _day.removeFirst();
    }
    if (_minute.length >= plan.perMinute || _day.length >= plan.perDay) {
      throw const FormatException('OJP plan limit reached. Retry later.');
    }
    _minute.add(now);
    _day.add(now);
  }

  void rateLimited() =>
      blockedUntil = _now().toUtc().add(const Duration(minutes: 1));
}

class OjpTripClient {
  OjpTripClient({
    required this.readKey,
    http.Client? httpClient,
    OjpRequestLimit? budget,
    DateTime Function()? now,
  }) : _transport = MobilityHttp(client: httpClient),
       _budget = budget ?? _sessionBudget,
       _now = now ?? DateTime.now;

  static final endpoint = Uri.parse(
    'https://api.opentransportdata.swiss/ojp20',
  );
  // Shared across OJP screens in this process; not a server-side quota ledger.
  static final OjpRequestLimit _sessionBudget = OjpRequestLimit();
  final Future<String?> Function() readKey;
  final MobilityHttp _transport;
  final OjpRequestLimit _budget;
  final DateTime Function() _now;
  final Map<String, Future<OjpJourneySnapshot>> _inFlight = {};
  final Map<String, OjpJourneySnapshot> _recent = {};
  bool _disposed = false;

  OjpApiPlan get plan => _budget.plan;
  set plan(OjpApiPlan value) => _budget.plan = value;

  Future<OjpJourneySnapshot> search(
    OjpTripQuery query, {
    required String originName,
    required String destinationName,
  }) {
    if (_disposed) return Future.error(StateError('OJP client closed'));
    final identity = '${query.identity}|$originName|$destinationName';
    final cached = _recent[identity];
    if (cached != null &&
        _now().toUtc().difference(cached.fetchedAtUtc).inSeconds < 30) {
      return Future.value(cached);
    }
    final running = _inFlight[identity];
    if (running != null) return running;
    final future = _fetch(query, originName, destinationName);
    _inFlight[identity] = future;
    unawaited(
      future
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .whenComplete(() {
            _inFlight.remove(identity);
          }),
    );
    return future;
  }

  Future<OjpJourneySnapshot> _fetch(
    OjpTripQuery query,
    String originName,
    String destinationName,
  ) async {
    final key = await readKey();
    if (key == null || key.trim().isEmpty) {
      throw const FormatException(
        'OJP 2.0 API key missing. Configure one locally.',
      );
    }
    if (key.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid OJP credential');
    }
    _budget.reserve();
    String response;
    try {
      response = await _transport.text(
        endpoint,
        body: buildOjpTripXml(query, timestamp: _now().toUtc()),
        maxBytes: 2 * 1024 * 1024,
        headers: {
          'Content-Type': 'application/xml',
          'Accept': 'application/xml',
          'Authorization': 'Bearer $key',
        },
      );
    } on MobilityHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        throw const FormatException(
          'OJP authentication failed (401/403). Check the OJP 2.0 key and subscription.',
        );
      }
      if (error.statusCode == 429) {
        _budget.rateLimited();
        throw const FormatException(
          'OJP server rate limit reached (429). Retry later.',
        );
      }
      throw FormatException('OJP HTTP ${error.statusCode}.');
    }
    final journeys = const OjpTripParser().parse(response);
    final snapshot = OjpJourneySnapshot(
      query: query,
      originName: originName,
      destinationName: destinationName,
      fetchedAtUtc: _now().toUtc(),
      journeys: journeys,
    );
    _recent.removeWhere(
      (_, item) =>
          _now().toUtc().difference(item.fetchedAtUtc) >=
          const Duration(seconds: 30),
    );
    if (_recent.length >= 16) _recent.remove(_recent.keys.first);
    _recent['${query.identity}|$originName|$destinationName'] = snapshot;
    return snapshot;
  }

  void dispose() {
    _disposed = true;
    _transport.dispose();
    _recent.clear();
  }
}

String buildOjpTripXml(OjpTripQuery query, {required DateTime timestamp}) {
  final requestTime = _isoSeconds(timestamp);
  final travelTime = _isoSeconds(query.timeUtc);
  String place(MobilityPoint point, {String? time}) =>
      '''
        <PlaceRef><GeoPosition>
          <siri:Longitude>${point.longitude}</siri:Longitude>
          <siri:Latitude>${point.latitude}</siri:Latitude>
        </GeoPosition></PlaceRef>
        ${time == null ? '' : '<DepArrTime>$time</DepArrTime>'}''';
  return '''<?xml version="1.0" encoding="UTF-8"?>
<OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
  <OJPRequest><siri:ServiceRequest>
    <siri:RequestTimestamp>$requestTime</siri:RequestTimestamp>
    <siri:RequestorRef>FPVManager_prod</siri:RequestorRef>
    <OJPTripRequest>
      <siri:RequestTimestamp>$requestTime</siri:RequestTimestamp>
      <siri:MessageIdentifier>FPVManager-TR</siri:MessageIdentifier>
      <Origin>${place(query.origin, time: query.mode == OjpTimeMode.departure ? travelTime : null)}</Origin>
      <Destination>${place(query.destination, time: query.mode == OjpTimeMode.arrival ? travelTime : null)}</Destination>
      <Params>
        <NumberOfResults>5</NumberOfResults>
        <IncludeIntermediateStops>false</IncludeIntermediateStops>
        <UseRealtimeData>explanatory</UseRealtimeData>
      </Params>
    </OJPTripRequest>
  </siri:ServiceRequest></OJPRequest>
</OJP>''';
}

String _isoSeconds(DateTime value) =>
    value.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+(?=Z$)'), '');
