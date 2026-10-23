import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/polygon_intersections.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/features/airspace/airspace_check_sheet.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/airspace/uas_airspace_checker.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/uas_zone_fixture.dart';

const _point = Wgs84Coordinate(latitude: 47.02, longitude: 8.08);

UasAirspaceCheck _report({
  String name = 'Zone one',
  bool empty = false,
  List<String> limitations = const [],
  OsintFreshness freshness = OsintFreshness.fresh,
}) => UasAirspaceCheck(
  source: SwissUasProvider.defaultSource,
  fetchedAtUtc: DateTime.utc(2026, 10, 21),
  freshness: freshness,
  checkedFeatureCount: 2,
  intersections: empty
      ? []
      : [
          UasAirspaceIntersection(
            UasZoneDetails(
              id: 'zone',
              name: name,
              attributes: uasFixtureAttributes,
            ),
            PolygonIntersection(0, {}, {0}),
          ),
        ],
  limitations: limitations,
);

class _CheckingGlobe extends GlobeController {
  Future<UasAirspaceCheck> Function(bool refresh) respond = (_) async =>
      _report();
  final calls = <(List<Wgs84Coordinate>, bool)>[];
  @override
  Future<UasAirspaceCheck> checkAirspace(
    List<Wgs84Coordinate> positions, {
    bool forceRefresh = false,
  }) {
    calls.add((List.of(positions), forceRefresh));
    return respond(forceRefresh);
  }
}

Widget _sheet(
  _CheckingGlobe globe, {
  List<Wgs84Coordinate> points = const [_point],
}) => MaterialApp(
  home: Scaffold(
    body: AirspaceCheckSheet(
      controller: globe,
      name: 'Selected spot',
      positions: points,
    ),
  ),
);

// Scroll to a control until it can actually receive a tap. A finder may
// locate a lazily built child or one just beyond the test viewport even when
// ensureVisible() alone leaves its centre outside the hit-test region.
Future<void> _tapInAirspaceList(
  WidgetTester tester,
  Finder target, {
  required bool towardEnd,
}) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    final tappable = target.hitTestable();
    if (tappable.evaluate().isNotEmpty) {
      await tester.tap(tappable);
      return;
    }
    await tester.drag(
      find.byType(ListView).last,
      Offset(0, towardEnd ? -160 : 160),
    );
    await tester.pumpAndSettle();
  }
  // A missing or obstructed button must still fail the test, not be ignored.
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
}

void main() {
  testWidgets(
    'loading retains the authorization boundary and completed restrictions open details',
    (tester) async {
      final pending = Completer<UasAirspaceCheck>();
      final globe = _CheckingGlobe()..respond = (_) => pending.future;
      addTearDown(globe.dispose);
      await tester.pumpWidget(_sheet(globe));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('not flight authorization'), findsOneWidget);
      pending.complete(_report());
      await tester.pumpAndSettle();
      expect(find.text('Intersecting zones: 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('REQ_AUTHORISATION.MTOM_ALL'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('REQ_AUTHORISATION.MTOM_ALL'), findsOneWidget);
      expect(find.text('Lower: 0 M · AGL'), findsOneWidget);
      expect(find.text('Upper: 900 M · AMSL'), findsOneWidget);
      await _tapInAirspaceList(
        tester,
        find.text('Inspect restrictions'),
        towardEnd: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Restrictions as supplied'), findsOneWidget);
      expect(find.text('Source classification'), findsOneWidget);
    },
  );

  testWidgets(
    'failure offers a forced retry; empty and incomplete results do not imply clearance',
    (tester) async {
      final globe = _CheckingGlobe()
        ..respond = (_) => Future.error(StateError('Offline'));
      addTearDown(globe.dispose);
      await tester.pumpWidget(_sheet(globe));
      await tester.pumpAndSettle();
      expect(find.textContaining('No current result'), findsOneWidget);
      globe.respond = (_) async => _report(
        empty: true,
        limitations: ['Only part of the source was received.'],
        freshness: OsintFreshness.stale,
      );
      await tester.tap(find.text('Retry with fresh data'));
      await tester.pumpAndSettle();
      expect(globe.calls.last.$2, isTrue);
      expect(
        find.text('No horizontal intersections found in the checked data.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not establish unrestricted airspace'),
        findsOneWidget,
      );
      expect(
        find.text('Only part of the source was received.'),
        findsOneWidget,
      );
      expect(find.textContaining('cache is stale'), findsOneWidget);
      globe.respond = (_) => Future.error(StateError('Unavailable'));
      await tester.ensureVisible(find.text('Refresh source data'));
      await tester.tap(find.text('Refresh source data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No current result'), findsOneWidget);
      expect(
        find.text('No horizontal intersections found in the checked data.'),
        findsNothing,
      );
    },
  );

  testWidgets('changed input and disposal ignore late checks', (tester) async {
    final old = Completer<UasAirspaceCheck>(),
        next = Completer<UasAirspaceCheck>();
    final globe = _CheckingGlobe()..respond = (_) => old.future;
    addTearDown(globe.dispose);
    await tester.pumpWidget(_sheet(globe));
    globe.respond = (_) => next.future;
    await tester.pumpWidget(
      _sheet(
        globe,
        points: const [Wgs84Coordinate(latitude: 46, longitude: 7)],
      ),
    );
    next.complete(_report(name: 'New zone'));
    await tester.pumpAndSettle();
    old.complete(_report(name: 'Obsolete zone'));
    await tester.pumpAndSettle();
    expect(find.text('New zone'), findsOneWidget);
    expect(find.text('Obsolete zone'), findsNothing);
    final late = Completer<UasAirspaceCheck>();
    globe.respond = (_) => late.future;
    await tester.ensureVisible(find.text('Refresh source data'));
    await tester.tap(find.text('Refresh source data'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    late.complete(_report());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow sheet with larger text scrolls to source details without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final globe = _CheckingGlobe();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: AirspaceCheckSheet(
                controller: globe,
                name: 'A longer selected flying spot',
                positions: const [_point],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('not flight authorization'),
        200,
      );
      expect(find.textContaining('not flight authorization'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Inspect restrictions'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Inspect restrictions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected saved spot exposes its own coordinates to the check', (
    tester,
  ) async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = SpotRepository(db);
    final id = await repository.createSpot(
      name: 'Saved check spot',
      latitude: _point.latitude,
      longitude: _point.longitude,
    );
    final globe = _CheckingGlobe();
    addTearDown(globe.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FPVHomeScreen(
          spotRepository: repository,
          preferencesRepository: UserPreferencesRepository(db),
          globeController: globe,
        ),
      ),
    );
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await tester.pumpAndSettle();
    peer.emit({'type': 'spot-selected', 'id': id});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check airspace'));
    await tester.pumpAndSettle();
    expect(globe.calls.single.$1.single.latitude, _point.latitude);
    expect(globe.calls.single.$1.single.longitude, _point.longitude);
    expect(find.text('Saved check spot'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('REQ_AUTHORISATION.MTOM_ALL'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('REQ_AUTHORISATION.MTOM_ALL'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // The home screen must not dispose an injected controller.
    expect(() => globe.addListener(() {}), returnsNormally);
  });

  testWidgets(
    'route check uses the current draft and reports crossing segments',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final id = await repository.createFlightPlan(
        name: 'Crossing route',
        waypoints: [
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 47.02, longitude: 7.9),
          ),
          const RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 47.02, longitude: 8.2),
          ),
        ],
      );
      final globe = _CheckingGlobe();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteEditorScreen(
            repository: repository,
            routeId: id,
            globeController: globe,
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Check route airspace'));
      await tester.pumpAndSettle();
      expect(globe.calls.single.$1, hasLength(2));
      await tester.scrollUntilVisible(
        find.text('Waypoints: none · Segments: 1–2'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Waypoints: none · Segments: 1–2'), findsOneWidget);
      await _tapInAirspaceList(
        tester,
        find.byTooltip('Close airspace check'),
        towardEnd: false,
      );
      await tester.pumpAndSettle();
      final state = peer.commands.lastWhere(
        (c) => c['type'] == 'set-route-editor',
      );
      peer.emit({
        'type': 'route-map-action',
        'editorId': state['editorId'],
        'revision': state['revision'],
        'action': 'move',
        'id': 1,
        'latitude': 47.2,
        'longitude': 8.8,
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Check route airspace'));
      await tester.pumpAndSettle();
      expect(globe.calls.last.$1.first.latitude, 47.2);
      expect(globe.calls.last.$1.first.longitude, 8.8);
      // Checking must not save or rewrite the route.
      expect(
        (await repository.getRoute(id))!.waypoints.first.position.longitude,
        7.9,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
