import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/osint/osint_provider_state.dart';
import 'navigation_location.dart';
import 'road_routing.dart';
import 'situational_provider.dart';
import 'traffic_incident.dart';
import 'traffic_counters_provider.dart';

double _lon(double delta) => (delta + 540) % 360 - 180;
double roadDistance(MobilityPoint a, MobilityPoint b) {
  final dy = (b.latitude - a.latitude) * 111195;
  final dx =
      _lon(b.longitude - a.longitude) *
      111195 *
      math.cos((a.latitude + b.latitude) * math.pi / 360);
  return math.sqrt(dx * dx + dy * dy);
}

double roadHeading(MobilityPoint a, MobilityPoint b) =>
    (math.atan2(
              _lon(b.longitude - a.longitude) *
                  math.cos((a.latitude + b.latitude) * math.pi / 360),
              b.latitude - a.latitude,
            ) *
            180 /
            math.pi +
        360) %
    360;
double _headingDifference(double a, double b) =>
    ((a - b + 540) % 360 - 180).abs();

class RoadMatch {
  const RoadMatch(this.distance, this.along, this.point, this.heading);
  final double distance, along, heading;
  final MobilityPoint point;
}

class RoadGeometry {
  RoadGeometry(this.points) {
    if (points.length < 2 || points.length > 20000) {
      throw const FormatException('Ungültige Routengeometrie.');
    }
    cumulative = [0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + roadDistance(points[i - 1], points[i]));
    }
    if (cumulative.last < 1) {
      throw const FormatException('Die Route ist zu kurz für eine Navigation.');
    }
    for (var start = 1; start < points.length; start += 64) {
      final end = math.min(start + 64, points.length),
          part = points.sublist(start - 1, end);
      _chunks.add((
        start: start,
        end: end,
        south: part.map((p) => p.latitude).reduce(math.min),
        north: part.map((p) => p.latitude).reduce(math.max),
        west: part.map((p) => p.longitude).reduce(math.min),
        east: part.map((p) => p.longitude).reduce(math.max),
      ));
    }
  }
  final List<MobilityPoint> points;
  late final List<double> cumulative;
  final _chunks =
      <
        ({
          int start,
          int end,
          double south,
          double north,
          double west,
          double east,
        })
      >[];
  RoadMatch nearest(
    MobilityPoint p, {
    double? previous,
    double? headingDegrees,
    double? maxTravelMeters,
  }) {
    RoadMatch? best;
    var bestScore = double.infinity;
    final cosine = math.max(.000001, math.cos(p.latitude * math.pi / 180));
    for (final chunk in _chunks) {
      final dy = p.latitude < chunk.south
          ? chunk.south - p.latitude
          : math.max(0.0, p.latitude - chunk.north);
      var dx = 0.0;
      if (chunk.east - chunk.west < 180 &&
          (p.longitude - (chunk.east + chunk.west) / 2).abs() < 180) {
        dx = p.longitude < chunk.west
            ? chunk.west - p.longitude
            : math.max(0.0, p.longitude - chunk.east);
      }
      if (best != null &&
          math.sqrt(dx * dx * cosine * cosine + dy * dy) * 111195 >
              bestScore + 2) {
        continue;
      }
      for (var i = chunk.start; i < chunk.end; i++) {
        final a = points[i - 1], b = points[i];
        final dx = _lon(b.longitude - a.longitude) * 111195 * cosine,
            dy = (b.latitude - a.latitude) * 111195;
        final px = _lon(p.longitude - a.longitude) * 111195 * cosine,
            py = (p.latitude - a.latitude) * 111195;
        final length = dx * dx + dy * dy,
            t = length == 0
                ? 0.0
                : ((px * dx + py * dy) / length).clamp(0.0, 1.0);
        final distance = math.sqrt(
          math.pow(px - t * dx, 2) + math.pow(py - t * dy, 2),
        );
        final along =
            cumulative[i - 1] + (cumulative[i] - cumulative[i - 1]) * t;
        final heading = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
        // Direction disambiguates nearby carriageways; continuity avoids jumping
        // to a later crossing or the destination on a loop. Neither changes the
        // measured distance, used for detecting actual route departures.
        final score =
            distance +
            (headingDegrees == null
                ? 0
                : 30 *
                      math.pow(
                        _headingDifference(heading, headingDegrees) / 180,
                        2,
                      )) +
            (previous == null || maxTravelMeters == null
                ? 0
                : math.min(
                    80,
                    math.max(0, (along - previous).abs() - maxTravelMeters),
                  ));
        if (best == null ||
            score < bestScore - .01 ||
            ((score - bestScore).abs() <= 2 &&
                previous != null &&
                (along - previous).abs() < (best.along - previous).abs())) {
          bestScore = score;
          best = RoadMatch(
            distance,
            along,
            MobilityPoint(
              a.latitude + (b.latitude - a.latitude) * t,
              (a.longitude + _lon(b.longitude - a.longitude) * t + 540) % 360 -
                  180,
            ),
            (math.atan2(dx, dy) * 180 / math.pi + 360) % 360,
          );
        }
      }
    }
    return best!;
  }

  RoadMatch nearestLine(List<MobilityPoint> line) {
    RoadMatch? best;
    for (final p in line) {
      final match = nearest(p);
      if (best == null || match.distance < best.distance) best = match;
    }
    for (var j = 1; j < line.length; j++) {
      final c = line[j - 1],
          d = line[j],
          cosine = math.max(.000001, math.cos(c.latitude * math.pi / 180));
      final south = math.min(c.latitude, d.latitude) - .003,
          north = math.max(c.latitude, d.latitude) + .003,
          west = math.min(c.longitude, d.longitude) - .003 / cosine,
          east = math.max(c.longitude, d.longitude) + .003 / cosine;
      for (final chunk in _chunks) {
        if (east - west < 180 &&
            chunk.east - chunk.west < 180 &&
            (chunk.north < south ||
                chunk.south > north ||
                chunk.east < west ||
                chunk.west > east)) {
          continue;
        }
        for (var i = chunk.start; i < chunk.end; i++) {
          final a = points[i - 1], b = points[i];
          final vx = _lon(b.longitude - a.longitude) * 111195 * cosine,
              vy = (b.latitude - a.latitude) * 111195,
              cx = _lon(c.longitude - a.longitude) * 111195 * cosine,
              cy = (c.latitude - a.latitude) * 111195,
              wx = _lon(d.longitude - c.longitude) * 111195 * cosine,
              wy = (d.latitude - c.latitude) * 111195;
          void candidate(double t, double distance) {
            if (best == null || distance < best!.distance) {
              best = RoadMatch(
                distance,
                cumulative[i - 1] + t * (cumulative[i] - cumulative[i - 1]),
                MobilityPoint(
                  a.latitude + (b.latitude - a.latitude) * t,
                  (a.longitude + _lon(b.longitude - a.longitude) * t + 540) %
                          360 -
                      180,
                ),
                (math.atan2(vx, vy) * 180 / math.pi + 360) % 360,
              );
            }
          }

          final cross = vx * wy - vy * wx;
          if (cross.abs() > 1e-9) {
            final t = (cx * wy - cy * wx) / cross,
                u = (cx * vy - cy * vx) / cross;
            if (t >= 0 && t <= 1 && u >= 0 && u <= 1) candidate(t, 0);
          }
          final length = wx * wx + wy * wy;
          if (length > 0) {
            for (final t in [0.0, 1.0]) {
              final px = vx * t - cx,
                  py = vy * t - cy,
                  s = ((px * wx + py * wy) / length).clamp(0.0, 1.0);
              candidate(
                t,
                math.sqrt(math.pow(px - s * wx, 2) + math.pow(py - s * wy, 2)),
              );
            }
          }
        }
      }
    }
    return best!;
  }
}

/// Uses a 300m corridor, not road identity or a verified traffic direction.
/// Runs off the UI isolate; only public normalized records are transferred.
List<Map<String, dynamic>> navigationTraffic(Map<String, dynamic> input) {
  final route = RoadGeometry(
    (input['points'] as List).map(MobilityPoint.fromJson).toList(),
  );
  final time = DateTime.parse(input['now'] as String),
      progress = (input['progress'] as num).toDouble();
  final result = <Map<String, dynamic>>[];
  for (final item in (input['features'] as List).take(20000)) {
    final feature = Map<String, dynamic>.from(item as Map);
    final until = DateTime.tryParse(feature['validUntilUtc'] as String? ?? '');
    if (feature['suspended'] == true ||
        (until != null && !until.isAfter(time))) {
      continue;
    }
    final geometry = feature['geometry'] as Map;
    final coordinates = geometry['type'] == 'Point'
        ? [geometry['coordinates']]
        : geometry['coordinates'] as List;
    RoadMatch? nearest;
    final positions = coordinates.take(32).map(MobilityPoint.fromJson).toList();
    if (positions.isNotEmpty) nearest = route.nearestLine(positions);
    if (nearest != null &&
        nearest.distance <= 300 &&
        nearest.along >= progress - 100) {
      result.add({
        ...feature,
        'alongMeters': nearest.along,
        'distanceToRouteMeters': nearest.distance,
      });
    }
  }
  result.sort(
    (a, b) => (a['alongMeters'] as num).compareTo(b['alongMeters'] as num),
  );
  return result;
}

class RoadNavigation extends ChangeNotifier {
  RoadNavigation({
    required RoadRoute route,
    required this.router,
    required this.locations,
    this.traffic,
    this.counters,
    this.automaticTrafficUpdates = false,
    DateTime Function()? now,
  }) : _route = route,
       _geometry = RoadGeometry(route.points),
       _now = now ?? DateTime.now {
    traffic?.addListener(_trafficChanged);
    counters?.addListener(_trafficChanged);
  }
  final RoadRouter router;
  final NavigationLocationSource locations;
  final SituationalProvider? traffic;
  final TrafficCountersProvider? counters;
  bool automaticTrafficUpdates;
  Timer? _trafficTimer;
  void setAutomaticTrafficUpdates(bool enabled) {
    automaticTrafficUpdates = enabled && (traffic != null || counters != null);
    _scheduleTrafficUpdates();
    notifyListeners();
  }

  void _scheduleTrafficUpdates() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    if (active &&
        automaticTrafficUpdates &&
        (traffic != null || counters != null)) {
      _trafficTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (traffic != null &&
            traffic!.canRefreshNetwork &&
            traffic!.status.update != OsintUpdateState.loading) {
          unawaited(refreshTraffic());
        }
        if (counters != null &&
            counters!.canRefresh &&
            counters!.status.update != OsintUpdateState.loading) {
          unawaited(refreshCounters());
        }
      });
    }
  }

  final DateTime Function() _now;
  RoadRoute _route;
  RoadGeometry _geometry;
  StreamSubscription<NavigationFix>? _subscription;
  Future<void>? _cancelling;
  Timer? _clock;
  bool _disposed = false,
      active = false,
      recalculating = false,
      arrived = false;
  NavigationFix? fix;
  RoadMatch? match;
  String? error, routeError, trafficAnalysisError;
  int routeRevision = 0, _epoch = 0, _trafficEpoch = 0, _arrivalFixes = 0;
  DateTime? _offSince, _lastReroute, _courseTime;
  NavigationFix? _courseAnchor;
  double? _travelHeading, _motionSpeed;
  double? get travelHeadingDegrees => _travelHeading;
  bool get _moving => (_motionSpeed ?? 0) > 2;
  bool get _currentCourse =>
      _courseTime != null &&
      _now().toUtc().difference(_courseTime!) <= const Duration(seconds: 15);
  bool get wrongDirection =>
      reliable &&
      _moving &&
      _currentCourse &&
      match != null &&
      _travelHeading != null &&
      _headingDifference(_travelHeading!, match!.heading) > 110;
  bool get passedDestination =>
      reliable &&
      match != null &&
      remainingMeters < 25 &&
      roadDistance(fix!.point, _route.points.last) >
          math.max(40, fix!.accuracyMeters * 2);
  List<Map<String, dynamic>> trafficAlerts = [];
  Object? _trafficSnapshot;
  bool _trafficBusy = false, _trafficPending = false;
  RoadRoute get route => _route;
  double get progressMeters =>
      (match?.along ?? 0) / _geometry.cumulative.last * _route.distanceMeters;
  double get remainingMeters =>
      math.max(0, _route.distanceMeters - progressMeters);
  double get remainingSeconds {
    if (_route.maneuvers.isEmpty) {
      return _route.durationSeconds *
          (1 - progressMeters / math.max(1, _route.distanceMeters));
    }
    return _route.maneuvers.fold(
      0.0,
      (sum, step) =>
          sum +
          step.durationSeconds *
              (step.distanceMeters == 0
                  ? 0
                  : ((step.atMeters + step.distanceMeters - progressMeters) /
                            step.distanceMeters)
                        .clamp(0.0, 1.0)),
    );
  }

  bool get reliable =>
      active &&
      fix != null &&
      fix!.accuracyMeters.isFinite &&
      fix!.accuracyMeters >= 0 &&
      fix!.accuracyMeters <= 50 &&
      _now().toUtc().difference(fix!.timeUtc) >= const Duration(seconds: -5) &&
      _now().toUtc().difference(fix!.timeUtc) <= const Duration(seconds: 15);
  bool get offRoute =>
      reliable &&
      match != null &&
      (match!.distance > math.max(35, fix!.accuracyMeters * 2) ||
          wrongDirection ||
          passedDestination);
  RoadManeuver? get nextManeuver {
    for (final step in _route.maneuvers) {
      if (step.type != 'depart' && step.atMeters >= progressMeters - 10) {
        return step;
      }
    }
    return _route.maneuvers.lastOrNull;
  }

  List<Map<String, dynamic>> get upcomingTraffic => trafficAlerts
      .where((f) {
        return (f['alongMeters'] as num) >= (match?.along ?? 0) - 100 &&
            TrafficIncident(f).relevantNow(_now().toUtc());
      })
      .take(50)
      .toList();
  void start() {
    if (_disposed || active) return;
    active = true;
    error = null;
    final epoch = ++_epoch;
    void subscribe() {
      if (_disposed || !active || epoch != _epoch) return;
      _subscription = locations.watch().listen(
        (value) {
          if (!_disposed && active && epoch == _epoch) _position(value);
        },
        onError: (Object failure) {
          if (!_disposed && active && epoch == _epoch) {
            fix = null;
            error = failure is FormatException
                ? failure.message
                : 'GPS nicht verfügbar. Standort und Berechtigung prüfen.';
            notifyListeners();
          }
        },
      );
    }

    final cancelling = _cancelling;
    _cancelling = null;
    if (cancelling == null) {
      subscribe();
    } else {
      unawaited(cancelling.then((_) => subscribe()));
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed && active) notifyListeners();
    });
    _trafficChanged();
    _scheduleTrafficUpdates();
    unawaited(refreshTraffic(force: false));
    unawaited(refreshCounters(force: false));
    notifyListeners();
  }

  void pause() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    active = false;
    ++_epoch;
    if (_subscription != null) {
      _cancelling = _subscription!.cancel().catchError((Object _) {});
    }
    _subscription = null;
    _clock?.cancel();
    _clock = null;
    fix = null;
    _courseAnchor = null;
    _courseTime = null;
    _motionSpeed = null;
    _offSince = null;
    _arrivalFixes = 0;
    recalculating = false;
    if (!_disposed) notifyListeners();
  }

  void _position(NavigationFix value) {
    if (fix != null && reliable && !value.timeUtc.isAfter(fix!.timeUtc)) return;
    final previousFix = reliable ? fix : null;
    fix = value;
    if (!reliable) {
      _offSince = null;
      _arrivalFixes = 0;
      _courseAnchor = null;
      _courseTime = null;
      notifyListeners();
      return;
    }
    final elapsed = previousFix == null
        ? null
        : value.timeUtc.difference(previousFix.timeUtc).inMilliseconds / 1000;
    _motionSpeed = value.speedMetersPerSecond;
    if (_motionSpeed == null &&
        elapsed != null &&
        elapsed > 0 &&
        elapsed <= 15) {
      _motionSpeed = roadDistance(previousFix!.point, value.point) / elapsed;
    }
    final nativeHeading = value.headingDegrees;
    final headingAccuracy = value.headingAccuracyDegrees;
    if (_moving &&
        nativeHeading != null &&
        nativeHeading.isFinite &&
        nativeHeading >= 0 &&
        nativeHeading < 360 &&
        (headingAccuracy == null ||
            (headingAccuracy.isFinite &&
                headingAccuracy >= 0 &&
                headingAccuracy <= 45))) {
      _travelHeading = nativeHeading;
      _courseTime = value.timeUtc;
      _courseAnchor = value;
    } else {
      final anchor = _courseAnchor;
      if (anchor != null &&
          value.timeUtc.difference(anchor.timeUtc) <=
              const Duration(seconds: 12) &&
          roadDistance(anchor.point, value.point) >=
              math.max(
                10,
                (anchor.accuracyMeters + value.accuracyMeters) * .75,
              )) {
        _travelHeading = roadHeading(anchor.point, value.point);
        _courseTime = value.timeUtc;
        _courseAnchor = value;
      } else if (anchor == null ||
          value.timeUtc.difference(anchor.timeUtc) >
              const Duration(seconds: 12)) {
        _courseAnchor = value;
      }
    }
    match = _geometry.nearest(
      value.point,
      previous: previousFix == null ? null : match?.along,
      headingDegrees: _moving && _currentCourse ? _travelHeading : null,
      maxTravelMeters: elapsed == null
          ? null
          : math.max(
              40,
              (_motionSpeed ?? 15) * elapsed * 1.8 + value.accuracyMeters * 2,
            ),
    );
    error = null;
    _arrivalFixes =
        remainingMeters < 25 &&
            !_moving &&
            !offRoute &&
            value.accuracyMeters <= 30 &&
            roadDistance(value.point, _route.points.last) < 35
        ? _arrivalFixes + 1
        : 0;
    if (arrived &&
        roadDistance(value.point, _route.points.last) >
            math.max(60, value.accuracyMeters * 2)) {
      arrived = false;
    }
    arrived = arrived || _arrivalFixes >= 3;
    if (offRoute) {
      _offSince ??= _now().toUtc();
      if (_now().toUtc().difference(_offSince!) >= const Duration(seconds: 8)) {
        unawaited(reroute());
      }
    } else {
      _offSince = null;
    }
    notifyListeners();
  }

  Future<void> reroute() async {
    final time = _now().toUtc();
    if (_disposed ||
        !reliable ||
        recalculating ||
        arrived ||
        (_lastReroute != null &&
            time.difference(_lastReroute!) < const Duration(seconds: 30))) {
      return;
    }
    _lastReroute = time;
    recalculating = true;
    routeError = null;
    final epoch = _epoch;
    final origin = fix!.point;
    notifyListeners();
    try {
      final next = await router.calculate(
        origin,
        _route.destination ?? _route.points.last,
        headingDegrees: _moving && _currentCourse ? _travelHeading : null,
      );
      final geometry = RoadGeometry(next.points);
      if (_disposed || !active || epoch != _epoch) return;
      _route = next;
      _geometry = geometry;
      trafficAlerts = [];
      routeRevision++;
      match = fix == null ? null : geometry.nearest(fix!.point);
      _offSince = null;
      _arrivalFixes = 0;
      arrived = false;
      _trafficSnapshot = null;
      _trafficChanged();
    } catch (_) {
      if (!_disposed && active && epoch == _epoch) {
        routeError =
            'Neuberechnung fehlgeschlagen. Letzte Route bleibt sichtbar.';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        recalculating = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshTraffic({bool force = true}) async {
    if (traffic == null || _disposed || !active) return;
    try {
      await traffic!.fetch(forceRefresh: force);
    } catch (_) {
      /* Provider publishes a safe status and retains the previous snapshot. */
      if ({401, 403, 429}.contains(traffic!.status.error?.httpStatus)) {
        setAutomaticTrafficUpdates(false);
      }
    }
  }

  Future<void> refreshCounters({bool force = true}) async {
    if (counters == null || _disposed || !active) return;
    try {
      await counters!.fetch(forceRefresh: force);
    } catch (_) {
      if ({401, 403, 429}.contains(counters!.status.error?.httpStatus)) {
        setAutomaticTrafficUpdates(false);
      }
    }
  }

  void _trafficChanged() {
    if (_disposed) return;
    final data = traffic?.status.dataset?.data;
    if (data != null && !identical(data, _trafficSnapshot)) {
      if (_trafficBusy) {
        _trafficPending = true;
        ++_trafficEpoch;
        notifyListeners();
        return;
      }
      _trafficBusy = true;
      _trafficSnapshot = data;
      final epoch = ++_trafficEpoch;
      unawaited(
        compute(navigationTraffic, {
              'points': _route.points.map((p) => p.toJson()).toList(),
              'progress': match?.along ?? 0,
              'features': data['features'],
              'now': _now().toUtc().toIso8601String(),
            })
            .then(
              (alerts) {
                if (!_disposed && epoch == _trafficEpoch) {
                  trafficAnalysisError = null;
                  trafficAlerts = alerts;
                  notifyListeners();
                }
              },
              onError: (Object _, StackTrace _) {
                if (!_disposed && epoch == _trafficEpoch) {
                  trafficAnalysisError = 'Verkehrsmeldungen konnten der Route nicht zugeordnet werden.';
                  trafficAlerts = [];
                  notifyListeners();
                }
              },
            )
            .whenComplete(() {
              _trafficBusy = false;
              if (!_disposed && _trafficPending) {
                _trafficPending = false;
                _trafficSnapshot = null;
                _trafficChanged();
              }
            }),
      );
    }
    notifyListeners();
  }

  String get trafficStatus {
    if (trafficAnalysisError != null) return trafficAnalysisError!;
    if (traffic == null) return 'Verkehrsdaten ausgeschaltet';
    if (traffic!.status.update == OsintUpdateState.loading) {
      return 'Verkehrsmeldungen werden geladen';
    }
    return traffic!.status.error?.message ??
        (traffic!.status.dataset == null
            ? 'Keine Verkehrsdaten geladen'
            : '${traffic!.status.dataState == OsintDataState.fresh ? 'Verkehrsstand' : 'Veralteter Verkehrsstand'} · ${traffic!.status.dataset!.fetchedAtUtc.toLocal()}');
  }

  String get trafficBadge {
    if (trafficAnalysisError != null) return 'Verkehr nicht zugeordnet';
    if (_trafficBusy) return 'Verkehr wird zugeordnet';
    if (traffic == null) {
      return counters == null ? 'Verkehr aus' : 'Messstellen aktiv';
    }
    if (traffic!.status.update == OsintUpdateState.loading) {
      return 'Verkehr lädt';
    }
    if (traffic!.status.error != null) return 'Verkehr nicht aktuell';
    final dataset = traffic!.status.dataset;
    if (dataset == null) return 'Verkehr nicht verfügbar';
    final time = dataset.fetchedAtUtc.toLocal();
    return '${traffic!.status.dataState == OsintDataState.fresh ? 'Stand' : 'Veraltet'} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    ++_trafficEpoch;
    traffic?.removeListener(_trafficChanged);
    counters?.removeListener(_trafficChanged);
    super.dispose();
  }
}
