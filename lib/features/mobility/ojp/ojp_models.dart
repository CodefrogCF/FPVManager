import '../road_routing.dart';

enum OjpTimeMode { departure, arrival }

class OjpTripQuery {
  const OjpTripQuery({
    required this.origin,
    required this.destination,
    required this.timeUtc,
    required this.mode,
  });

  final MobilityPoint origin, destination;
  final DateTime timeUtc;
  final OjpTimeMode mode;

  String get identity => [
    origin.latitude,
    origin.longitude,
    destination.latitude,
    destination.longitude,
    timeUtc.toUtc().toIso8601String(),
    mode.name,
  ].join('|');

  Map<String, Object?> toJson() => {
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'timeUtc': timeUtc.toUtc().toIso8601String(),
    'mode': mode.name,
  };

  factory OjpTripQuery.fromJson(Map<String, dynamic> json) => OjpTripQuery(
    origin: MobilityPoint.fromJson(json['origin']),
    destination: MobilityPoint.fromJson(json['destination']),
    timeUtc: DateTime.parse(json['timeUtc'] as String).toUtc(),
    mode: OjpTimeMode.values.byName(json['mode'] as String),
  );
}

class OjpServiceTime {
  const OjpServiceTime({this.timetableUtc, this.estimatedUtc});
  final DateTime? timetableUtc, estimatedUtc;
  bool get hasRealtimeChange =>
      timetableUtc != null &&
      estimatedUtc != null &&
      timetableUtc != estimatedUtc;
  DateTime? get effectiveUtc => estimatedUtc ?? timetableUtc;

  Map<String, Object?> toJson() => {
    'timetableUtc': timetableUtc?.toIso8601String(),
    'estimatedUtc': estimatedUtc?.toIso8601String(),
  };

  factory OjpServiceTime.fromJson(Map<String, dynamic> json) => OjpServiceTime(
    timetableUtc: _date(json['timetableUtc']),
    estimatedUtc: _date(json['estimatedUtc']),
  );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.parse(raw as String).toUtc();

enum OjpLegKind { publicTransport, walk, transfer, other }

class OjpLeg {
  const OjpLeg({
    required this.kind,
    required this.from,
    required this.to,
    required this.duration,
    this.line,
    this.mode,
    this.distanceMetres,
    this.departure = const OjpServiceTime(),
    this.arrival = const OjpServiceTime(),
  });
  final OjpLegKind kind;
  final String from, to;
  final Duration? duration;
  final String? line, mode;
  final double? distanceMetres;
  final OjpServiceTime departure, arrival;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'from': from,
    'to': to,
    'durationSeconds': duration?.inSeconds,
    'line': line,
    'mode': mode,
    'distanceMetres': distanceMetres,
    'departure': departure.toJson(),
    'arrival': arrival.toJson(),
  };

  factory OjpLeg.fromJson(Map<String, dynamic> json) => OjpLeg(
    kind: OjpLegKind.values.byName(json['kind'] as String),
    from: json['from'] as String,
    to: json['to'] as String,
    duration: json['durationSeconds'] == null
        ? null
        : Duration(seconds: json['durationSeconds'] as int),
    line: json['line'] as String?,
    mode: json['mode'] as String?,
    distanceMetres: (json['distanceMetres'] as num?)?.toDouble(),
    departure: OjpServiceTime.fromJson(
      Map<String, dynamic>.from(json['departure'] as Map),
    ),
    arrival: OjpServiceTime.fromJson(
      Map<String, dynamic>.from(json['arrival'] as Map),
    ),
  );
}

class OjpJourney {
  const OjpJourney({
    required this.id,
    required this.startUtc,
    required this.endUtc,
    required this.transfers,
    required this.legs,
  });
  final String id;
  final DateTime startUtc, endUtc;
  final int transfers;
  final List<OjpLeg> legs;

  Map<String, Object?> toJson() => {
    'id': id,
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
    'transfers': transfers,
    'legs': legs.map((leg) => leg.toJson()).toList(),
  };

  factory OjpJourney.fromJson(Map<String, dynamic> json) => OjpJourney(
    id: json['id'] as String,
    startUtc: DateTime.parse(json['startUtc'] as String).toUtc(),
    endUtc: DateTime.parse(json['endUtc'] as String).toUtc(),
    transfers: json['transfers'] as int,
    legs: (json['legs'] as List)
        .map((raw) => OjpLeg.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(),
  );
}

/// A dated, user-saved result; never implicitly refreshed or presented as live.
class OjpJourneySnapshot {
  const OjpJourneySnapshot({
    required this.query,
    required this.originName,
    required this.destinationName,
    required this.fetchedAtUtc,
    required this.journeys,
  });
  final OjpTripQuery query;
  final String originName, destinationName;
  final DateTime fetchedAtUtc;
  final List<OjpJourney> journeys;

  Map<String, Object?> toJson() => {
    'version': 1,
    'query': query.toJson(),
    'originName': originName,
    'destinationName': destinationName,
    'fetchedAtUtc': fetchedAtUtc.toUtc().toIso8601String(),
    'journeys': journeys.map((journey) => journey.toJson()).toList(),
  };

  factory OjpJourneySnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported journey snapshot');
    }
    final journeys = json['journeys'] as List;
    if (journeys.length > 8) {
      throw const FormatException('Too many saved journeys');
    }
    return OjpJourneySnapshot(
      query: OjpTripQuery.fromJson(
        Map<String, dynamic>.from(json['query'] as Map),
      ),
      originName: json['originName'] as String,
      destinationName: json['destinationName'] as String,
      fetchedAtUtc: DateTime.parse(json['fetchedAtUtc'] as String).toUtc(),
      journeys: journeys
          .map(
            (raw) => OjpJourney.fromJson(Map<String, dynamic>.from(raw as Map)),
          )
          .toList(),
    );
  }
}
