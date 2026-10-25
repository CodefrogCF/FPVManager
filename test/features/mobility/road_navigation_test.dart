import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/navigation_location.dart';
import 'package:fpvmanager/features/mobility/road_navigation.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';

import '../../helpers/fake_globe_renderer.dart';

class _Locations implements NavigationLocationSource {
  final stream = StreamController<NavigationFix>.broadcast(sync: true);
  @override
  Stream<NavigationFix> watch() => stream.stream;
}

RoadRoute exampleRoute() => RoadRoute(
  distanceMeters: 222.39,
  durationSeconds: 100,
  points: [
    MobilityPoint(47, 8),
    MobilityPoint(47.001, 8),
    MobilityPoint(47.002, 8),
  ],
  retrievedUtc: DateTime.utc(2026, 10, 25),
  maneuvers: const [
    RoadManeuver(
      type: 'depart',
      modifier: '',
      road: 'Start',
      atMeters: 0,
      distanceMeters: 111.195,
      durationSeconds: 50,
    ),
    RoadManeuver(
      type: 'turn',
      modifier: 'left',
      road: 'Testweg',
      atMeters: 111.195,
      distanceMeters: 111.195,
      durationSeconds: 50,
    ),
    RoadManeuver(
      type: 'arrive',
      modifier: '',
      road: 'Ziel',
      atMeters: 222.39,
      distanceMeters: 0,
      durationSeconds: 0,
    ),
  ],
);

void main() {
  test('direction and continuity disambiguate overlapping carriageways and crossings', () {
    final line = RoadGeometry([
      MobilityPoint(47, 8),
      MobilityPoint(47.004, 8),
      MobilityPoint(47.004, 8.0001),
      MobilityPoint(47, 8.0001),
    ]);
    final north = line.nearest(
      MobilityPoint(47.002, 8.00005),
      headingDegrees: 0,
    );
    final south = line.nearest(
      MobilityPoint(47.002, 8.00005),
      headingDegrees: 180,
    );
    expect(north.heading, closeTo(0, .1));
    expect(south.heading, closeTo(180, .1));
    final crossing = RoadGeometry([
      MobilityPoint(47, 8),
      MobilityPoint(47.004, 8),
      MobilityPoint(47.004, 8.004),
      MobilityPoint(47.002, 8),
      MobilityPoint(47, 8.004),
    ]);
    final match = crossing.nearest(
      MobilityPoint(47.002, 8),
      previous: 210,
      maxTravelMeters: 40,
      headingDegrees: 0,
    );
    expect(match.along, closeTo(222.39, 1));
    expect(match.distance, lessThan(.01));
  });
  test('course derives from movement, rejects inaccurate bearings and holds at a stop', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations(), router = RoadRouter();
    final nav = RoadNavigation(
      route: exampleRoute(),
      router: router,
      locations: gps,
      now: () => now,
    );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    void send(
      double lat, {
      double speed = 10,
      double? heading,
      double? accuracy,
    }) {
      now = now.add(const Duration(seconds: 1));
      gps.stream.add(
        NavigationFix(
          point: MobilityPoint(lat, 8),
          accuracyMeters: 5,
          timeUtc: now,
          speedMetersPerSecond: speed,
          headingDegrees: heading,
          headingAccuracyDegrees: accuracy,
        ),
      );
    }

    send(47.0002, speed: 0, heading: 0);
    expect(nav.travelHeadingDegrees, isNull);
    send(47.0001, heading: 0, accuracy: 120);
    expect(nav.travelHeadingDegrees, closeTo(180, .1));
    expect(nav.wrongDirection, isTrue);
    send(47.0001, speed: 0, heading: 0);
    expect(nav.travelHeadingDegrees, closeTo(180, .1));
    expect(nav.wrongDirection, isFalse);
    send(47.0003, heading: 0, accuracy: 5);
    expect(nav.travelHeadingDegrees, 0);
    expect(nav.offRoute, isFalse);
  });
  test('sustained wrong-way travel reroutes with course; failure retains the route', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations();
    final requests = <Uri>[];
    final router = RoadRouter(
      now: () => now,
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response('unavailable', 503);
      }),
    );
    final nav = RoadNavigation(
      route: exampleRoute(),
      router: router,
      locations: gps,
      now: () => now,
    );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    for (var i = 0; i <= 9; i++) {
      now = now.add(const Duration(seconds: 1));
      gps.stream.add(
        NavigationFix(
          point: MobilityPoint(47.0018 - i * .0001, 8),
          accuracyMeters: 5,
          timeUtc: now,
          speedMetersPerSecond: 11,
          headingDegrees: 180,
          headingAccuracyDegrees: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(nav.offRoute, isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['bearings'], '180,60;');
    expect(nav.routeRevision, 0);
    expect(nav.routeError, contains('fehlgeschlagen'));
  });
  test('driving through the arrival area does not end guidance and passing it reroutes', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations();
    var requests = 0;
    final router = RoadRouter(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return http.Response('unavailable', 503);
      }),
    );
    final nav = RoadNavigation(
      route: exampleRoute(),
      router: router,
      locations: gps,
      now: () => now,
    );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    for (var i = 0; i < 18; i++) {
      now = now.add(const Duration(seconds: 1));
      gps.stream.add(
        NavigationFix(
          point: MobilityPoint(47.00185 + i * .0001, 8),
          accuracyMeters: 5,
          timeUtc: now,
          speedMetersPerSecond: 11,
          headingDegrees: 0,
          headingAccuracyDegrees: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(nav.arrived, isFalse);
    }
    expect(nav.passedDestination, isTrue);
    expect(requests, 1);
  });
  test(
    'guidance resumes after leaving a previously reached destination',
    () async {
      var now = DateTime.utc(2026, 10, 25);
      final gps = _Locations(), router = RoadRouter();
      final nav = RoadNavigation(
        route: exampleRoute(),
        router: router,
        locations: gps,
        now: () => now,
      );
      addTearDown(() async {
        nav.dispose();
        router.dispose();
        await gps.stream.close();
      });
      nav.start();
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 1));
        gps.stream.add(
          NavigationFix(
            point: MobilityPoint(47.002, 8),
            accuracyMeters: 5,
            timeUtc: now,
            speedMetersPerSecond: 0,
          ),
        );
      }
      expect(nav.arrived, isTrue);
      now = now.add(const Duration(seconds: 5));
      gps.stream.add(
        NavigationFix(
          point: MobilityPoint(47.0027, 8),
          accuracyMeters: 5,
          timeUtc: now,
          speedMetersPerSecond: 15,
          headingDegrees: 0,
        ),
      );
      expect(nav.arrived, isFalse);
      expect(nav.offRoute, isTrue);
    },
  );

  test('navigation reuses a valid traffic snapshot and failed manual updates preserve its warnings', () async {
    var now = DateTime.utc(2026, 10, 25, 10), fail = false, requests = 0;
    const xml =
        '<d2LogicalModel><payloadPublication><publicationTime>2026-10-25T10:00:00Z</publicationTime><situation><situationRecord id="incident"><pointCoordinates><latitude>47.0017</latitude><longitude>8</longitude></pointCoordinates></situationRecord></situation></payloadPublication></d2LogicalModel>';
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      readTrafficKey: () async => 'test-key',
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return http.Response(fail ? 'unavailable' : xml, fail ? 503 : 200);
      }),
    );
    final gps = _Locations(),
        router = RoadRouter(),
        nav = RoadNavigation(
          route: exampleRoute(),
          router: router,
          locations: gps,
          traffic: provider,
          now: () => now,
        );
    addTearDown(() async {
      nav.dispose();
      provider.dispose();
      router.dispose();
      await gps.stream.close();
    });
    final snapshot = await provider.fetch();
    nav.start();
    for (
      var attempt = 0;
      attempt < 200 && nav.trafficAlerts.isEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(nav.upcomingTraffic.single['id'], 'incident');
    expect(requests, 1);
    fail = true;
    now = now.add(const Duration(seconds: 16));
    await nav.refreshTraffic();
    expect(identical(provider.status.dataset, snapshot), isTrue);
    expect(nav.upcomingTraffic.single['id'], 'incident');
    expect(nav.trafficBadge, 'Verkehr nicht aktuell');
  });
  test('route matching handles the date line and crossing traffic lines without requiring a nearby source vertex', () {
    final geometry = RoadGeometry([
      MobilityPoint(0, 179.999),
      MobilityPoint(0, -179.999),
    ]);
    expect(geometry.nearest(MobilityPoint(0, 180)).distance, lessThan(.01));
    final route = RoadGeometry(exampleRoute().points);
    final crossing = route.nearestLine([
      MobilityPoint(47.001, 7.99),
      MobilityPoint(47.001, 8.01),
    ]);
    expect(crossing.distance, lessThan(.01));
    expect(crossing.along, closeTo(111.195, 1));
  });
  test('GPS progression selects the upcoming turn, pauses on stale/inaccurate fixes and recovers after future timestamps', () async {
    var now = DateTime.utc(2026, 10, 25, 10);
    final gps = _Locations(), router = RoadRouter();
    final nav = RoadNavigation(
      route: exampleRoute(),
      router: router,
      locations: gps,
      now: () => now,
    );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    void send(double lat, {double accuracy = 5, DateTime? time}) =>
        gps.stream.add(
          NavigationFix(
            point: MobilityPoint(lat, 8),
            accuracyMeters: accuracy,
            timeUtc: time ?? now,
          ),
        );
    nav.start();
    send(47.0002);
    expect(nav.reliable, isTrue);
    expect(nav.nextManeuver!.modifier, 'left');
    expect(nav.remainingMeters, closeTo(200.151, 1));
    expect(nav.remainingSeconds, closeTo(90, 1));
    final progress = nav.progressMeters;
    now = now.add(const Duration(seconds: 1));
    send(47.0018, accuracy: 200);
    expect(nav.reliable, isFalse);
    expect(nav.progressMeters, progress);
    send(47.0018, time: now.add(const Duration(days: 1)));
    expect(nav.reliable, isFalse);
    now = now.add(const Duration(seconds: 1));
    send(47.0004);
    expect(nav.reliable, isTrue);
    now = now.add(const Duration(seconds: 16));
    expect(nav.reliable, isFalse);
    expect(nav.offRoute, isFalse);
    nav.pause();
    expect(gps.stream.hasListener, isFalse);
    expect(nav.active, isFalse);
  });
  test('arrival requires repeated precise endpoint fixes, rather than a single jump', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations(), router = RoadRouter();
    final nav = RoadNavigation(
      route: exampleRoute(),
      router: router,
      locations: gps,
      now: () => now,
    );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(seconds: 1));
      gps.stream.add(
        NavigationFix(
          point: MobilityPoint(47.002, 8),
          accuracyMeters: 5,
          timeUtc: now,
        ),
      );
      expect(nav.arrived, i == 2);
    }
  });
  test('recalculation is coalesced and a late result after pause does not replace the route', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations(), reply = Completer<http.Response>();
    var requests = 0;
    final router = RoadRouter(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return reply.future;
      }),
    );
    final original = exampleRoute(),
        nav = RoadNavigation(
          route: exampleRoute(),
          router: router,
          locations: gps,
          now: () => now,
        );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    gps.stream.add(
      NavigationFix(
        point: MobilityPoint(47.0002, 8.01),
        accuracyMeters: 5,
        timeUtc: now,
      ),
    );
    final update = nav.reroute();
    await nav.reroute();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(nav.recalculating, isTrue);
    nav.pause();
    reply.complete(
      http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 100,
              'duration': 20,
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [8.01, 47.0002],
                  [8, 47.002],
                ],
              },
            },
          ],
        }),
        200,
      ),
    );
    await update;
    expect(nav.routeRevision, 0);
    expect(nav.route.distanceMeters, original.distanceMeters);
    expect(nav.active, isFalse);
  });
  test('failed recalculation keeps the previous route and does not repeat during cooldown', () async {
    var now = DateTime.utc(2026, 10, 25);
    final gps = _Locations();
    var requests = 0;
    final router = RoadRouter(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return http.Response('unavailable', 503);
      }),
    );
    final original = exampleRoute(),
        nav = RoadNavigation(
          route: exampleRoute(),
          router: router,
          locations: gps,
          now: () => now,
        );
    addTearDown(() async {
      nav.dispose();
      router.dispose();
      await gps.stream.close();
    });
    nav.start();
    gps.stream.add(
      NavigationFix(
        point: MobilityPoint(47.0002, 8.01),
        accuracyMeters: 5,
        timeUtc: now,
      ),
    );
    await nav.reroute();
    await nav.reroute();
    expect(requests, 1);
    expect(nav.route.distanceMeters, original.distanceMeters);
    expect(nav.routeError, contains('fehlgeschlagen'));
  });
  test('traffic corridor retains nearby and planned records for later activation and excludes distant, expired and passed records', () {
    Map<String, dynamic> incident(
      String id,
      double lat,
      double lon, {
      String? from,
      String? until,
    }) => {
      'id': id,
      'name': id,
      'detail': 'public',
      'validFromUtc': from,
      'validUntilUtc': until,
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat],
      },
    };
    final alerts = navigationTraffic({
      'points': exampleRoute().points.map((p) => p.toJson()).toList(),
      'progress': 150,
      'now': '2026-10-25T10:00:00Z',
      'features': [
        incident('near', 47.0017, 8.0001),
        incident('far', 48, 9),
        incident('behind', 47, 8),
        incident('future', 47.001, 8, from: '2026-10-26T00:00:00Z'),
        incident('expired', 47.001, 8, until: '2026-10-25T09:00:00Z'),
      ],
    });
    expect(alerts.map((a) => a['id']), ['future', 'near']);
  });
  test('OSRM navigation requests include instructions and preserve roundabout exit and road names', () async {
    final router = RoadRouter(
      client: MockClient((request) async {
        expect(request.url.queryParameters['steps'], 'true');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 100,
                'duration': 20,
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [8, 47],
                    [8, 47.001],
                  ],
                },
                'legs': [
                  {
                    'steps': [
                      {
                        'distance': 100,
                        'duration': 20,
                        'name': 'Teststrasse',
                        'maneuver': {
                          'type': 'roundabout',
                          'exit': 2,
                          'location': [8, 47],
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(router.dispose);
    final route = await router.calculate(
      MobilityPoint(47, 8),
      MobilityPoint(47.001, 8),
    );
    expect(route.maneuvers.single.instruction, contains('Ausfahrt 2'));
    expect(route.maneuvers.single.road, 'Teststrasse');
  });
  test(
    'navigation fix replays after renderer reload and ending clears it',
    () async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await globe.setRoadNavigation(
        active: true,
        follow: true,
        latitude: 47,
        longitude: 8,
        heading: 90,
        cameraDistanceMeters: 100,
      );
      await globe.setRenderingPaused(true);
      peer.sessionId = 'renderer-new';
      peer.ready();
      await Future<void>.delayed(Duration.zero);
      final commands = peer.commands
          .where((c) => c['type'] == 'set-road-navigation')
          .toList();
      expect(commands.length, greaterThanOrEqualTo(2));
      expect((commands.last['position'] as Map)['heading'], 90);
      expect(commands.last['cameraDistanceMeters'], 100);
      peer.emit({'type': 'road-navigation-follow', 'follow': false});
      expect(globe.roadNavigationFollowing, false);
      peer.sessionId = 'renderer-after-compass';
      peer.ready();
      await Future<void>.delayed(Duration.zero);
      expect(
        peer.commands.lastWhere(
          (c) => c['type'] == 'set-road-navigation',
        )['follow'],
        false,
      );
      for (final distance in [59.0, 1801.0, double.nan, double.infinity]) {
        await expectLater(
          globe.setRoadNavigation(
            active: true,
            follow: true,
            cameraDistanceMeters: distance,
          ),
          throwsArgumentError,
        );
      }
      expect(
        peer.commands
            .where((c) => c['type'] == 'set-rendering-paused')
            .last['paused'],
        isTrue,
      );
      await globe.setRenderingPaused(false);
      await globe.setRoadNavigation(active: false, follow: true);
      peer.commands.clear();
      peer.sessionId = 'renderer-after-exit';
      peer.ready();
      await Future<void>.delayed(Duration.zero);
      expect(
        peer.commands.where((c) => c['type'] == 'set-road-navigation'),
        isEmpty,
      );
    },
  );
}
