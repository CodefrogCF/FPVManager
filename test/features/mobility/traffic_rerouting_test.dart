import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/navigation_location.dart';
import 'package:fpvmanager/features/mobility/road_navigation.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

import '../../helpers/route_traffic_fixtures.dart';
import '../../helpers/route_traffic_provider.dart';

class _Locations implements NavigationLocationSource {
  final stream = StreamController<NavigationFix>.broadcast(sync: true);
  @override
  Stream<NavigationFix> watch() => stream.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in [
    'enabled',
    'disabled',
    'changed',
    'paused',
    'disposed',
  ]) {
    test(
      'traffic reroute respects $action policy, lifecycle and request cooldown',
      () async {
        final gps = _Locations(), response = Completer<http.Response>();
        var time = trafficTime;
        var requests = 0;
        final router = RoadRouter(
          now: () => time,
          client: MockClient((_) {
            requests++;
            return response.future;
          }),
        );
        final traffic = RouteTrafficProvider(
          trafficState({
            'records': [
              trafficEvent([trafficPart()]),
            ],
            'features': [],
          }),
        );
        final original = trafficRoute();
        final nav = RoadNavigation(
          route: original,
          router: router,
          locations: gps,
          traffic: traffic,
          trafficAwareRouting: action != 'disabled',
          now: () => time,
        );
        var disposed = false;
        addTearDown(() async {
          if (!disposed) nav.dispose();
          traffic.dispose();
          router.dispose();
          await gps.stream.close();
        });
        nav.start();
        gps.stream.add(
          NavigationFix(
            point: MobilityPoint(47.0002, 8),
            accuracyMeters: 5,
            timeUtc: trafficTime,
          ),
        );
        expect(nav.reliable, true);
        final pending = nav.reroute();
        if (action == 'changed') nav.setTrafficAwareRouting(false);
        if (action == 'paused') nav.pause();
        if (action == 'disposed') {
          nav.dispose();
          disposed = true;
        }
        response.complete(
          http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                trafficRouteJson(),
                trafficRouteJson(lon: 8.001, seconds: 90),
              ],
            }),
            200,
          ),
        );
        await pending;
        if (action == 'enabled') {
          expect(nav.route.points.first.longitude, 8.001);
          expect(nav.routeTrafficEvaluation!.recommendedIndex, 1);
          expect(nav.route.durationSeconds, 90);
          traffic.publish(trafficState({'records': [], 'features': []}));
          expect(nav.routeTrafficEvaluation, isNull);
          expect(
            nav.route.points.first.longitude,
            8.001,
          ); // no silent route switch
        } else if (action == 'disabled' || action == 'changed') {
          expect(nav.route.points.first.longitude, 8);
          expect(nav.routeTrafficEvaluation, isNull);
          time = time.add(const Duration(seconds: 1));
          gps.stream.add(
            NavigationFix(
              point: MobilityPoint(47.0004, 8),
              accuracyMeters: 5,
              timeUtc: time,
            ),
          );
          expect(
            nav.progressMeters,
            greaterThan(40),
          ); // policy did not kill GPS
        } else {
          expect(identical(nav.route, original), true);
          expect(nav.routeTrafficEvaluation, isNull);
        }
        if (!disposed) await nav.reroute();
        expect(requests, 1);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
    );
  }
}
