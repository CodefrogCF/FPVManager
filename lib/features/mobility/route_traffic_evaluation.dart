import 'dart:math' as math;

import '../../core/osint/osint_provider_state.dart';
import 'road_routing.dart';

class RouteTrafficInput {
  const RouteTrafficInput(
    this.routes,
    this.time, {
    this.traffic,
    this.counters,
  });
  final List<RoadRoute> routes;
  final DateTime time;
  final OsintProviderState<Map<String, dynamic>>? traffic, counters;
}

class RouteTrafficEvidence {
  const RouteTrafficEvidence(
    this.id,
    this.title,
    this.road,
    this.kind,
    this.time, {
    this.delaySeconds,
    this.speedKmh,
    this.locationReference,
  });
  final String id, title, road, kind;
  final DateTime time;
  final double? delaySeconds, speedKmh;
  final String? locationReference;
}

class RouteTrafficAssessment {
  RouteTrafficAssessment(
    this.route, {
    required this.evidence,
    required this.closures,
    required this.reportedDelaySeconds,
    required this.speedRatio,
    required this.ignored,
    required this.incomplete,
  });
  final RoadRoute route;
  final List<RouteTrafficEvidence> evidence;
  final int closures, ignored;
  final double? reportedDelaySeconds, speedRatio;
  final bool incomplete;
}

class RouteTrafficEvaluation {
  const RouteTrafficEvaluation(
    this.assessments,
    this.recommendedIndex,
    this.trafficStatus,
    this.counterStatus,
    this.evaluatedAt, {
    required this.speedCompared,
    required this.trafficInfluenced,
  });
  final List<RouteTrafficAssessment> assessments;
  final int recommendedIndex;
  final String trafficStatus, counterStatus;
  final DateTime evaluatedAt;
  final bool speedCompared;
  final bool trafficInfluenced;
}

/// Local comparison, NOT a traffic ETA. No missing-data penalty is invented.
/// Known closures sort last; then baseline minutes + the largest published delay.
/// Only if every alternative has eligible aggregate speed observations, a bounded
/// 0..1 comparison point favours measurements closer to the local OSRM baseline.
RouteTrafficEvaluation evaluateRouteTraffic(RouteTrafficInput input) {
  if (input.routes.isEmpty || input.routes.length > 3) {
    throw ArgumentError('Compare 1–3 route alternatives');
  }
  final trafficReason = _sourceReason(input.traffic, input.time),
      counterReason = _sourceReason(input.counters, input.time);
  final traffic = trafficReason == null ? input.traffic!.dataset!.data : null,
      counters = counterReason == null ? input.counters!.dataset!.data : null;
  final assessments = <RouteTrafficAssessment>[];
  final indexes = [
    for (final route in input.routes)
      _RoadIndex(
        traffic == null && counters == null ? const [] : route.sections,
      ),
  ];
  _Match? matchFor(int routeIndex, Map data) {
    final match = indexes[routeIndex].match(data);
    if (match == null) return null;
    final both =
        data['directionCode'] == 'both' ||
        _label(data['directionBound']).trim().toLowerCase() == 'bothways';
    for (var i = 0; i < indexes.length; i++) {
      if (i == routeIndex) continue;
      final other = indexes[i].match(data);
      if (other == null) continue;
      final angle = ((match.heading - other.heading + 540) % 360 - 180).abs();
      if (both && angle >= 145) continue;
      if (match.distance > other.distance + 3) return null;
      if ((match.distance - other.distance).abs() <= 3 &&
          math.sqrt(
                math.pow(match.x - other.x, 2) + math.pow(match.y - other.y, 2),
              ) >
              3) {
        return null;
      }
    }
    return match;
  }

  _Match? tmcMatch(int routeIndex, Map part) {
    final r = part['tmcResolved'];
    if (r is! Map ||
        r['status'] != 'resolved' ||
        r['sourceVerified'] != true ||
        r['tableSha256'] is! String ||
        r['anchors'] is! List ||
        r['roadNumbers'] is! List ||
        (r['roadNumbers'] as List).length > 8) {
      return null;
    }
    final anchors = r['anchors'] as List;
    if (anchors.length < 2 || anchors.length > 512) return null;
    final primaryOffset = r['primaryOffset'],
        secondaryOffset = r['secondaryOffset'];
    if (primaryOffset is! num ||
        !primaryOffset.isFinite ||
        primaryOffset < 0 ||
        primaryOffset > 50000 ||
        r['linear'] == true &&
            (secondaryOffset is! num ||
                !secondaryOffset.isFinite ||
                secondaryOffset < 0 ||
                secondaryOffset > 50000)) {
      return null;
    }
    for (final ref in (r['roadNumbers'] as List).whereType<String>().expand(
      roadReferences,
    )) {
      final matches = <_Match>[];
      for (final point in anchors) {
        final match = matchFor(routeIndex, {
          ...part,
          'point': point,
          'roadNumbers': [ref],
          'directionBound': '',
          'directionCode': 'both',
        });
        if (match == null) break;
        matches.add(match);
      }
      if (matches.length != anchors.length) continue;
      final first = matches.first.along, last = matches.last.along;
      final sign = last > first ? 1 : -1;
      if (sign < 0 && r['both'] != true) continue;
      if (matches.indexed
          .skip(1)
          .any((m) => sign * (m.$2.along - matches[m.$1 - 1].along) < 1)) {
        continue;
      }
      final low = math.min(first, last), high = math.max(first, last);
      final head = last - sign * primaryOffset;
      final tail = r['linear'] == true
          ? first + sign * (secondaryOffset as num)
          : head;
      if (head < low - 1 ||
          head > high + 1 ||
          tail < low - 1 ||
          tail > high + 1 ||
          sign * (head - tail) < -1) {
        continue;
      }
      if (!indexes[routeIndex].coversRoad(ref, low, high)) continue;
      return matches.last;
    }
    return null;
  }

  for (var routeIndex = 0; routeIndex < input.routes.length; routeIndex++) {
    final route = input.routes[routeIndex], index = indexes[routeIndex];
    final evidence = <RouteTrafficEvidence>[],
        closureIds = <String>{},
        seen = <String>{},
        ratios = <double>[];
    var ignored = 0,
        incomplete =
            index.incomplete || traffic?['tmcResolutionIncomplete'] == true;
    double? maxDelay;
    final records = traffic?['records'];
    if (records is List) {
      if (records.length > 20000) incomplete = true;
      for (final raw in records.take(20000)) {
        if (raw is! Map ||
            raw['routingEvidenceComplete'] != true ||
            raw['routingEvidence'] is! List) {
          ignored++;
          continue;
        }
        final parts = raw['routingEvidence'] as List;
        if (parts.length > 32) {
          incomplete = true;
          ignored++;
          continue;
        }
        final parent = raw['id'];
        if (parent is! String || parent.isEmpty || parent.length > 160) {
          ignored++;
          continue;
        }
        var matched = false;
        for (final part in parts) {
          if (part is! Map) {
            continue;
          }
          final direct = part['geometryAccuracy'] == 'sourcePoint'
              ? matchFor(routeIndex, part)
              : null;
          final match =
              direct ??
              (part['tmc'] != null ? tmcMatch(routeIndex, part) : null);
          if (match == null || !_active(part, input.time)) continue;
          final sourceTime = _date(part['timestampUtc']);
          if (sourceTime == null ||
              sourceTime.isAfter(input.time.add(const Duration(seconds: 30)))) {
            continue;
          }
          final id = '$parent/${part['id']}';
          if (!seen.add(id)) continue;
          final category = part['category'];
          if (category == 'closure') closureIds.add(parent);
          double? delay;
          final metrics = part['metrics'];
          if (metrics is Map &&
              input.time.difference(sourceTime) <=
                  const Duration(minutes: 15)) {
            final value = metrics['delayTimeValue'];
            if (value is num &&
                value.isFinite &&
                value >= 0 &&
                value <= 86400) {
              delay = value.toDouble();
              maxDelay = math.max(maxDelay ?? 0, delay);
            }
          }
          matched = true;
          evidence.add(
            RouteTrafficEvidence(
              id,
              _label(raw['name']),
              match.reference,
              _label(category),
              sourceTime,
              delaySeconds: delay,
              locationReference: direct == null && part['tmcResolved'] is Map
                  ? 'TMC ${part['tmcResolved']['version']} · gerichtete Ankerkette und Routenoffsets'
                  : null,
            ),
          );
          if (evidence.length >= 1000) {
            incomplete = true;
            break;
          }
        }
        if (!matched) ignored++;
        if (incomplete && evidence.length >= 1000) break;
      }
    }
    final sites = counters?['features'];
    if (sites is List) {
      if (sites.length > 100) incomplete = true;
      for (final raw in sites.take(100)) {
        if (raw is! Map ||
            raw['metadataVersionVerified'] != true ||
            raw['geometry'] is! Map) {
          ignored++;
          continue;
        }
        final geometry = raw['geometry'] as Map;
        if (geometry['type'] != 'Point') {
          ignored++;
          continue;
        }
        final match = matchFor(routeIndex, {
          ...raw,
          'point': geometry['coordinates'],
        });
        if (match == null) {
          ignored++;
          continue;
        }
        final values = raw['values'];
        if (values is! List || values.length > 100) {
          ignored++;
          continue;
        }
        final speeds = <({double speed, DateTime time, bool aggregate})>[];
        for (final value in values) {
          if (value is! Map ||
              value['kind'] != 'trafficSpeed' ||
              value['unit'] != 'KilometresPerHour' ||
              value['error'] == true) {
            continue;
          }
          final speed = value['value'],
              period = value['periodSeconds'],
              time = _date(value['timeUtc'] ?? raw['timestampUtc']);
          if (speed is! num ||
              !speed.isFinite ||
              speed < 0 ||
              speed > 300 ||
              time == null ||
              time.isAfter(input.time.add(const Duration(seconds: 5))) ||
              input.time.difference(time) > const Duration(minutes: 2)) {
            continue;
          }
          final aggregate =
              value['vehicle'] == 'anyVehicle' &&
              raw['lane'] == 'allLanesCompleteCarriageway' &&
              period is num &&
              period.isFinite &&
              period > 0 &&
              period <= 300;
          speeds.add((
            speed: speed.toDouble(),
            time: time,
            aggregate: aggregate,
          ));
        }
        if (speeds.isEmpty) {
          ignored++;
          continue;
        }
        speeds.sort((a, b) => b.time.compareTo(a.time));
        final latest = speeds.first;
        evidence.add(
          RouteTrafficEvidence(
            'counter/${raw['id']}',
            _label(raw['name']),
            match.reference,
            'counter',
            latest.time,
            speedKmh: latest.speed,
          ),
        );
        if (latest.aggregate &&
            match.section.distanceMeters >= 100 &&
            match.section.durationSeconds > 0) {
          final baseline =
              match.section.distanceMeters /
              match.section.durationSeconds *
              3.6;
          if (baseline >= 10 && baseline <= 200) {
            ratios.add((latest.speed / baseline).clamp(0.0, 1.0));
          }
        }
      }
    }
    assessments.add(
      RouteTrafficAssessment(
        route,
        evidence: List.unmodifiable(evidence),
        closures: closureIds.length,
        reportedDelaySeconds: maxDelay,
        speedRatio: ratios.isEmpty ? null : ratios.reduce(math.min),
        ignored: ignored,
        incomplete: incomplete,
      ),
    );
  }
  final comparable =
      assessments.length > 1 &&
      assessments.every((a) => a.speedRatio != null && !a.incomplete);
  final complete = assessments.every((a) => !a.incomplete);
  final speedEffect =
      comparable &&
      assessments.map((a) => a.speedRatio!).reduce(math.max) -
              assessments.map((a) => a.speedRatio!).reduce(math.min) >=
          .15;
  final effects =
      assessments.any(
        (a) => a.closures > 0 || (a.reportedDelaySeconds ?? 0) > 0,
      ) ||
      speedEffect;
  var best = 0;
  double score(RouteTrafficAssessment a) =>
      a.route.durationSeconds / 60 +
      (a.reportedDelaySeconds ?? 0) / 60 +
      (speedEffect ? 1 - a.speedRatio! : 0);
  if (complete && effects) {
    for (var i = 1; i < assessments.length; i++) {
      final a = assessments[i], b = assessments[best];
      if (a.closures < b.closures ||
          a.closures == b.closures && score(a) < score(b) - .01) {
        best = i;
      }
    }
  }
  return RouteTrafficEvaluation(
    List.unmodifiable(assessments),
    best,
    trafficReason ?? 'Aktuell abgerufen · ASTRA-Verkehrsmeldungen',
    counterReason ?? 'Aktuell abgerufen · punktuelle ASTRA-Messwerte',
    input.time,
    speedCompared: speedEffect,
    trafficInfluenced: complete && effects,
  );
}

String? _sourceReason(
  OsintProviderState<Map<String, dynamic>>? status,
  DateTime now,
) {
  final dataset = status?.dataset;
  if (dataset == null) return 'Keine Daten geladen';
  if (dataset.requiresRevalidation) {
    return 'Importierter / nicht online bestätigter Stand · nur Information';
  }
  if (status!.error != null || status.update == OsintUpdateState.disposed) {
    return 'Aktualisierung fehlgeschlagen · nicht gewichtet';
  }
  if (dataset.freshnessAt(now) != OsintFreshness.fresh ||
      status.dataState != OsintDataState.fresh) {
    return 'Veralteter oder nicht verfügbarer Stand · nicht gewichtet';
  }
  if (dataset.publishedAtUtc == null ||
      dataset.publishedAtUtc!.isAfter(now.add(const Duration(seconds: 30)))) {
    return 'Quellenzeit fehlt oder liegt in der Zukunft · nicht gewichtet';
  }
  return null;
}

DateTime? _date(Object? value) =>
    value is String && RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)
    ? DateTime.tryParse(value)?.toUtc()
    : null;
String _label(Object? value) {
  final s = value is String ? value : '';
  return s.substring(0, s.length.clamp(0, 160));
}

bool _active(Map part, DateTime now) {
  if (part['withdrawn'] == true ||
      part['suspended'] == true ||
      part['recurring'] == true) {
    return false;
  }
  final from = _date(part['validFromUtc']),
      until = _date(part['validUntilUtc']);
  if (part['validFromUtc'] != null && from == null ||
      part['validUntilUtc'] != null && until == null) {
    return false;
  }
  if (from != null && from.isAfter(now)) return false;
  return (from != null && !from.isAfter(now) ||
          part['validityStatus'] == 'active') &&
      (until == null || until.isAfter(now));
}

class _Segment {
  const _Segment(
    this.a,
    this.b,
    this.section,
    this.reference,
    this.along,
    this.length,
  );
  final MobilityPoint a, b;
  final RoadSection section;
  final String reference;
  final double along, length;
}

class _Match {
  const _Match(
    this.section,
    this.reference,
    this.distance,
    this.x,
    this.y,
    this.heading,
    this.along,
  );
  final RoadSection section;
  final String reference;
  final double distance, x, y, heading;
  final double along;
}

/// Small geographic buckets avoid scanning every road vertex for every message.
/// Oversized index/input is declared incomplete and cannot choose a new route.
class _RoadIndex {
  _RoadIndex(List<RoadSection> sections) {
    var vertices = 0, entries = 0;
    var along = 0.0;
    MobilityPoint? previous;
    for (final section in sections) {
      vertices += section.points.length;
      if (vertices > 40000) {
        incomplete = true;
        break;
      }
      if (section.points.isEmpty) continue;
      if (previous != null) {
        final gap = _length(previous, section.points.first);
        if (gap > 5) {
          _spans.add((from: along, to: along + gap, roads: <String>{}));
          along += gap;
        }
      }
      final sectionStart = along;
      for (var i = 1; i < section.points.length; i++) {
        final a = section.points[i - 1], b = section.points[i];
        final startAlong = along, length = _length(a, b);
        along += length;
        if (section.link || section.references.isEmpty) continue;
        final x0 = (math.min(a.longitude, b.longitude) / .005).floor(),
            x1 = (math.max(a.longitude, b.longitude) / .005).floor(),
            y0 = (math.min(a.latitude, b.latitude) / .005).floor(),
            y1 = (math.max(a.latitude, b.latitude) / .005).floor();
        if ((x1 - x0 + 1) * (y1 - y0 + 1) > 64) {
          incomplete = true;
          continue;
        }
        for (final ref in section.references.take(8)) {
          final segment = _Segment(a, b, section, ref, startAlong, length);
          for (var x = x0; x <= x1; x++) {
            for (var y = y0; y <= y1; y++) {
              if (++entries > 250000) {
                incomplete = true;
                return;
              }
              (_grid[ref] ??= {}).putIfAbsent('$x/$y', () => []).add(segment);
            }
          }
        }
      }
      previous = section.points.last;
      _spans.add((
        from: sectionStart,
        to: along,
        roads: section.link ? <String>{} : section.references,
      ));
    }
  }
  final _grid = <String, Map<String, List<_Segment>>>{};
  final _spans = <({double from, double to, Set<String> roads})>[];
  bool coversRoad(String ref, double from, double to) =>
      !incomplete &&
      to - from > 1 &&
      _spans
          .where((s) => s.to > from + .5 && s.from < to - .5)
          .every((s) => s.roads.contains(ref));
  static double _length(MobilityPoint a, MobilityPoint b) {
    final x =
            (b.longitude - a.longitude) *
            111195 *
            math.cos((a.latitude + b.latitude) * math.pi / 360),
        y = (b.latitude - a.latitude) * 111195;
    return math.sqrt(x * x + y * y);
  }

  bool incomplete = false;
  _Match? match(Map evidence) {
    if (!{
      '',
      'mainCarriageway',
      'allCarriageways',
    }.contains(evidence['carriageway'] ?? '')) {
      return null;
    }
    if (!{'', 'allLanesCompleteCarriageway'}.contains(evidence['lane'] ?? '')) {
      return null;
    }
    final refs = evidence['roadNumbers'];
    if (refs is! List || refs.length > 8) return null;
    MobilityPoint p;
    try {
      p = MobilityPoint.fromJson(evidence['point']);
    } on FormatException {
      return null;
    }
    // The provider is Swiss; the tight proximity rule is not extrapolated globally.
    if (p.latitude < 45.5 ||
        p.latitude > 48.5 ||
        p.longitude < 5.5 ||
        p.longitude > 11) {
      return null;
    }
    final bound = _label(evidence['directionBound']).trim().toLowerCase();
    const headings = {
      'northbound': 0.0,
      'northeastbound': 45.0,
      'eastbound': 90.0,
      'southeastbound': 135.0,
      'southbound': 180.0,
      'southwestbound': 225.0,
      'westbound': 270.0,
      'northwestbound': 315.0,
    };
    final heading = headings[bound],
        both =
            _label(evidence['directionCode']).trim() == 'both' ||
            bound == 'bothways';
    if (heading == null && !both) {
      return null; // positive/negative requires the TMC topology.
    }
    final x = (p.longitude / .005).floor(),
        y = (p.latitude / .005).floor(),
        candidates = <_Match>[],
        seen = <_Segment>{};
    for (final ref in refs.whereType<String>().expand(roadReferences)) {
      final grid = _grid[ref];
      if (grid == null) continue;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final s in grid['${x + dx}/${y + dy}'] ?? <_Segment>[]) {
            if (!seen.add(s)) continue;
            final c = math.cos(p.latitude * math.pi / 180),
                vx = (s.b.longitude - s.a.longitude) * 111195 * c,
                vy = (s.b.latitude - s.a.latitude) * 111195,
                px = (p.longitude - s.a.longitude) * 111195 * c,
                py = (p.latitude - s.a.latitude) * 111195,
                length = vx * vx + vy * vy;
            if (length < .01) continue;
            final t = ((px * vx + py * vy) / length).clamp(0.0, 1.0),
                distance = math.sqrt(
                  math.pow(px - t * vx, 2) + math.pow(py - t * vy, 2),
                ),
                bearing = (math.atan2(vx, vy) * 180 / math.pi + 360) % 360;
            if (distance > 8 ||
                heading != null &&
                    ((bearing - heading + 540) % 360 - 180).abs() > 35) {
              continue;
            }
            candidates.add(
              _Match(
                s.section,
                ref,
                distance,
                t * vx - px,
                t * vy - py,
                bearing,
                s.along + t * s.length,
              ),
            );
          }
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final best = candidates.first;
    for (final other in candidates.skip(1)) {
      if (other.distance > best.distance + 3) break;
      final angle = ((other.heading - best.heading + 540) % 360 - 180).abs();
      if (math.sqrt(
                math.pow(other.x - best.x, 2) + math.pow(other.y - best.y, 2),
              ) >
              3 ||
          angle > 35 && angle < 145) {
        return null;
      }
    }
    return best;
  }
}
