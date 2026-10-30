import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/weather/weather_models.dart';
import 'package:fpvmanager/features/weather/weather_overlay_service.dart';
import 'package:fpvmanager/features/weather/weather_preferences.dart';
import 'package:fpvmanager/features/weather/weather_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';

class _Overlay extends WeatherOverlayService {
  final pending = Completer<WeatherMapOverlay>();
  int calls = 0;
  @override
  Future<WeatherMapOverlay> load({
    required double latitude,
    required double longitude,
    required DateTime timeUtc,
    required WeatherOverlayKind kind,
    double spacingMeters = 1000,
  }) {
    calls++;
    return pending.future;
  }
}

class _Provider implements WeatherProvider {
  _Provider(this.id);
  @override
  final WeatherProviderId id;
  final List<bool> refreshes = [];
  Completer<WeatherForecast>? pending;
  @override
  String get title =>
      id == WeatherProviderId.openMeteo ? 'Open fixture' : 'Swiss fixture';
  @override
  String get termsUrl => 'https://example.invalid';
  @override
  WeatherCapabilities get capabilities => const WeatherCapabilities(
    variables: {
      WeatherVariable.wind,
      WeatherVariable.gust,
      WeatherVariable.precipitation,
    },
    forecast: true,
    spatialOverlay: false,
    description: 'Fixture capabilities',
  );
  WeatherForecast result() {
    final now = DateTime.now().toUtc();
    return WeatherForecast(
      provider: id,
      source: title,
      sourceUrl: termsUrl,
      retrievedUtc: now,
      modelResolution: 'Fixture resolution',
      locationDescription: 'Fixture point',
      samples: List.generate(
        8,
        (index) => WeatherSample(
          timeUtc: DateTime.utc(
            now.year,
            now.month,
            now.day,
            now.hour + index + 1,
          ),
          windMs: 4,
          gustMs: 6,
          precipitationMm: 0,
        ),
      ),
    );
  }

  @override
  Future<WeatherForecast> forecast(
    double latitude,
    double longitude, {
    bool forceRefresh = false,
  }) async {
    refreshes.add(forceRefresh);
    return pending?.future ?? Future.value(result());
  }

  @override
  void dispose() {}
}

void main() {
  late FpvDatabase database;
  late SpotRepository spots;
  late DroneRepository drones;
  late WeatherPreferencesRepository preferences;
  late GlobeController globe;
  late FakeGlobeRenderer renderer;
  late MockClient client;
  late _Provider open, swiss;

  setUp(() async {
    database = FpvDatabase(NativeDatabase.memory());
    spots = SpotRepository(database);
    drones = DroneRepository(database);
    preferences = WeatherPreferencesRepository(database);
    await spots.createSpot(name: 'First spot', latitude: 47, longitude: 8);
    await spots.createSpot(name: 'Second spot', latitude: 46.5, longitude: 8.5);
    client = MockClient(
      (_) async =>
          http.Response('{"type":"FeatureCollection","features":[]}', 200),
    );
    globe = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(globe)..attach();
    renderer.ready();
    open = _Provider(WeatherProviderId.openMeteo);
    swiss = _Provider(WeatherProviderId.meteoSwiss);
  });
  tearDown(() async {
    globe.dispose();
    client.close();
    await database.close();
  });

  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    WeatherOverlayService? overlay,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: WeatherScreen(
          spots: spots,
          drones: drones,
          globe: globe,
          preferences: preferences,
          availableProviders: {open.id: open, swiss.id: swiss},
          overlayService: overlay,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseProvider(WidgetTester tester, String label) async {
    final dropdown = find.byType(DropdownButtonFormField<WeatherProviderId>);
    await tester.scrollUntilVisible(
      dropdown,
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(dropdown), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'provider choice persists and manual refresh reaches the provider with force enabled',
    (tester) async {
      await show(tester);
      expect(open.refreshes, [false]);
      await tester.ensureVisible(find.text('Refresh forecast'));
      await tester.tap(find.text('Refresh forecast'));
      await tester.pumpAndSettle();
      expect(open.refreshes, [false, true]);
      await chooseProvider(tester, 'Swiss fixture');
      expect(swiss.refreshes, [false]);
      expect((await preferences.load()).provider, WeatherProviderId.meteoSwiss);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester);
      expect(swiss.refreshes, [false, false]);
      expect(find.text('Swiss fixture'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late comparison from a previous provider cannot return after a source switch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester);
      open.pending = Completer<WeatherForecast>();
      final compare = find.text('Evaluate saved spots');
      await tester.scrollUntilVisible(
        compare,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(compare);
      await tester.pumpAndSettle();
      await tester.tap(compare);
      await tester.pump();
      expect(open.refreshes, hasLength(2));
      await chooseProvider(tester, 'Swiss fixture');
      open.pending!.complete(open.result());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Evaluate saved spots'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(
        find.textContaining('Terrain and legal airspace not assessed.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late terrain response is discarded when the selected spot changes',
    (tester) async {
      await show(tester, dark: true);
      final terrain = find.text('Inspect local terrain');
      await tester.scrollUntilVisible(
        terrain,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(terrain);
      await tester.pump();
      final query = renderer.commands.lastWhere(
        (c) => c['type'] == 'query-terrain-elevation',
      );
      final dropdown = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == 'Saved flying spot',
      );
      await tester.scrollUntilVisible(
        dropdown,
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second spot').last);
      await tester.pumpAndSettle();
      renderer.acknowledge(
        query,
        result: {
          'latitude': query['latitude'],
          'longitude': query['longitude'],
          'heightMeters': 500,
          'heightReference': 'wgs84Ellipsoid',
          'samplingMethod': 'fixture',
        },
      );
      await tester.pumpAndSettle();
      expect(
        renderer.commands.where((c) => c['type'] == 'query-terrain-elevation'),
        hasLength(1),
      );
      expect(find.textContaining('Nearby relief'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a visibility-criterion change invalidates an in-flight comparison',
    (tester) async {
      await show(tester);
      open.pending = Completer<WeatherForecast>();
      final compare = find.text('Evaluate saved spots');
      await tester.scrollUntilVisible(
        compare,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(compare);
      await tester.pumpAndSettle();
      await tester.tap(compare);
      await tester.pump();
      expect(open.refreshes, hasLength(2));
      final visibility = find.text('Require visibility forecast');
      await tester.scrollUntilVisible(
        visibility,
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.ensureVisible(visibility);
      await tester.pump();
      await tester.tap(visibility);
      await tester.pump();
      open.pending!.complete(open.result());
      await tester.pumpAndSettle();
      expect(open.refreshes, hasLength(2));
      expect(
        find.textContaining('Terrain and legal airspace not assessed.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an overlay for the previous selection cannot appear after a provider switch',
    (tester) async {
      final overlay = _Overlay();
      addTearDown(overlay.dispose);
      await show(tester, overlay: overlay);
      final button = find.text('Show on globe');
      await tester.scrollUntilVisible(
        button,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(overlay.calls, 1);
      await chooseProvider(tester, 'Swiss fixture');
      overlay.pending.complete(
        WeatherMapOverlay(
          kind: WeatherOverlayKind.wind,
          atUtc: DateTime.now().toUtc(),
          cells: const [
            WeatherOverlayCell(
              west: 8,
              east: 8.01,
              south: 47,
              north: 47.01,
              value: 4,
            ),
          ],
          stepLatitudeDegrees: .01,
          stepLongitudeDegrees: .01,
          spacingMeters: 1000,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        renderer.commands.where((c) => c['type'] == 'set-weather-overlay'),
        isEmpty,
      );
      expect(globe.weatherOverlayVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
