import '../../../core/models/flight_route.dart';
import '../../../core/models/route_constraints.dart';
import 'route_analysis.dart';

class RouteRuleFinding {
  const RouteRuleFinding(this.segment, this.message);
  final int segment;
  final String message;
}

class RouteRuleCheck {
  const RouteRuleCheck(this.findings, this.unknownHeightSamples);
  final List<RouteRuleFinding> findings;
  final int unknownHeightSamples;
  factory RouteRuleCheck.calculate(
    RouteAnalysis route,
    List<RouteWaypointInput> points,
    RouteConstraints constraints,
  ) {
    constraints.validate();
    final bySegment = <int, Set<String>>{};
    void add(int segment, String text) =>
        bySegment.putIfAbsent(segment, () => {}).add(text);
    var unknown = 0;
    for (final p in route.profile) {
      final clearance = p.clearance;
      // Shared endpoints constrain both neighbouring segments.
      final segments = {
        p.sample.segment,
        if (p.sample.fraction == 1 && p.sample.segment < points.length - 2)
          p.sample.segment + 1,
      };
      if (clearance == null) {
        unknown++;
      } else {
        for (final s in segments) {
          if (clearance < 0) add(s, 'Planned height is below sampled terrain');
          if (constraints.legalCeilingAgl case final ceiling?) {
            if (clearance > ceiling) {
              add(
                s,
                'Above configured legal AGL ceiling ($ceiling m); verify authorisation and applicability',
              );
            }
          }
          if (constraints.operationalCeilingAgl case final ceiling?) {
            if (clearance > ceiling) {
              add(s, 'Above configured operational AGL ceiling ($ceiling m)');
            }
          }
        }
      }
      if (constraints.planningRadiusMeters case final radius?) {
        if (routeDistance(points.first.position, p.sample.position) > radius) {
          for (final s in segments) {
            add(
              s,
              'Beyond configured planning radius ($radius m) from waypoint 1; VLOS requires manual verification',
            );
          }
        }
      }
    }
    // AGL supplied at a waypoint is known even if terrain sampling is offline.
    for (var i = 0; i < points.length; i++) {
      if (points[i].height case AglWaypointHeight(:final height)) {
        for (final s in {if (i > 0) i - 1, if (i < points.length - 1) i}) {
          if (constraints.legalCeilingAgl case final c?) {
            if (height.meters > c) {
              add(
                s,
                'Waypoint ${i + 1} exceeds configured legal AGL ceiling ($c m)',
              );
            }
          }
          if (constraints.operationalCeilingAgl case final c?) {
            if (height.meters > c) {
              add(
                s,
                'Waypoint ${i + 1} exceeds configured operational AGL ceiling ($c m)',
              );
            }
          }
        }
      }
    }
    return RouteRuleCheck(
      List.unmodifiable([
        for (final entry in bySegment.entries)
          for (final text in entry.value) RouteRuleFinding(entry.key, text),
      ]),
      unknown,
    );
  }
}
