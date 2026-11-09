import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/simulation/flight_recording.dart';
import 'package:fpvmanager/features/simulation/flight_recording_sheet.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/routes/route_editor_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import 'flight_recording_test.dart' show point;
import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'HUD stop opens review; a retained recording can be saved after renderer loss and opens the route editor',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final repo = FlightPlanRepository(db),
          peer = FakeGlobeRenderer(globe)..attach();
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            globeController: globe,
            flightPlanRepository: repo,
            spotRepository: SpotRepository(db),
            preferencesRepository: UserPreferencesRepository(db),
          ),
        ),
      );
      peer.attach();
      peer.ready();
      await tester.pumpAndSettle();
      peer.emit({'type': 'simulation-state', 'active': true, 'pending': false});
      await globe.recording.control('start');
      final id = globe.recording.id;
      peer.emit({
        'type': 'flight-recording-sample',
        'id': id,
        'sample': [1, 0, 0, 46.7, 8.4, 1040, 1000],
      });
      peer.emit({
        'type': 'flight-recording-sample',
        'id': id,
        'sample': [2, 0, 1, 46.701, 8.4, 1100, null],
      });
      peer.emit({'type': 'flight-recording-action', 'action': 'stop'});
      await tester.pumpAndSettle();
      expect(find.text('Review simulated flight'), findsOneWidget);
      await tester.tap(find.text('Keep for later'));
      await tester.pumpAndSettle();
      globe.rendererLoading();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kartenaktionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flugaufzeichnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as route'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteEditorScreen), findsOneWidget);
      expect(globe.recording.hasSamples, false);
      final records = await repo.getAllFlightPlans();
      expect(records.length, 1);
      final saved = (await repo.getRoute(records.single.id))!;
      expect(saved.waypoints.map((p) => p.height!.meters), [1040, 1100]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'recording preview fits portrait and landscape, selects a continuous section and saves real heights',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FlightPlanRepository(db);
      final flight = RecordedFlight('test', DateTime.utc(2026, 10, 28), [
        point(0),
        point(1),
        point(2, segment: 1, height: 1200),
        point(3, segment: 1, height: 1300, ground: null),
      ]);
      int? result;
      var discarded = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showFlightRecordingReview(
                    c,
                    flight: flight,
                    repository: repo,
                    onDiscard: () async {
                      discarded = true;
                    },
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Section 2 · 2 samples'), findsOneWidget);
      final agl = find.widgetWithText(
        SwitchListTile,
        'Use height above terrain (AGL)',
      );
      await tester.ensureVisible(agl);
      expect(tester.widget<SwitchListTile>(agl).onChanged, isNull);
      for (final size in [
        const Size(800, 360),
        const Size(320, 480),
        const Size(320, 640),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final name = find.widgetWithText(TextField, 'Route name');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Recorded climb');
      await tester.tap(find.text('Save as route'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(discarded, false);
      final route = (await repo.getRoute(result!))!;
      expect(route.plan.name, 'Recorded climb');
      expect(route.waypoints.map((p) => p.height!.meters), [1200, 1300]);
      expect(
        (route.waypoints.first.height as AbsoluteWaypointHeight)
            .elevation
            .reference,
        VerticalReference.wgs84Ellipsoid,
      );
    },
  );

  testWidgets(
    'keep for later preserves data; discarding requires an explicit confirmation',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var discards = 0;
      final flight = RecordedFlight('test', DateTime.utc(2026), [
        point(0),
        point(1),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showFlightRecordingReview(
                  c,
                  flight: flight,
                  repository: FlightPlanRepository(db),
                  onDiscard: () async {
                    discards++;
                  },
                ),
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep for later'));
      await tester.pumpAndSettle();
      expect(discards, 0);
      expect(flight.points.length, 2);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep recording'));
      await tester.pumpAndSettle();
      expect(discards, 0);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(discards, 1);
      expect(find.text('Review simulated flight'), findsNothing);
    },
  );

  testWidgets(
    'route cap is explicit and trimming can retain a bounded unsimplified section',
    (tester) async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final flight = RecordedFlight('test', DateTime.utc(2026), [
        for (var i = 0; i < 1100; i++) point(i),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showFlightRecordingReview(
                  c,
                  flight: flight,
                  repository: FlightPlanRepository(db),
                  onDiscard: () async {},
                ),
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      final simplification = find.byType(DropdownButtonFormField<double>);
      await tester.ensureVisible(simplification);
      await tester.tap(simplification);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep all samples').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save as route'),
            )
            .onPressed,
        isNull,
      );
      final slider = find.byType(RangeSlider);
      tester.widget<RangeSlider>(slider).onChanged!(const RangeValues(0, 500));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save as route'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.textContaining('501 samples → 501 waypoints'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
