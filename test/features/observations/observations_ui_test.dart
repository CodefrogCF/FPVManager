import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_cache_database.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/observations/meteo_station_provider.dart';
import 'package:fpvmanager/features/observations/observation_controller.dart';
import 'package:fpvmanager/features/observations/observations_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'observations_test.dart' show metadata, measured;

void main() {
  testWidgets(
    'station selection shows measured units and missing values; visibility and renderer restore retain dated readings',
    (tester) async {
      final cache = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(cache.close);
      await tester.runAsync(() => cache.customSelect('SELECT 1').get());
      var calls = 0;
      final meteo = MeteoStationProvider(
        now: () => DateTime.utc(2026, 10, 30, 12, 5),
        client: MockClient((r) async {
          calls++;
          return http.Response(
            r.url.path.endsWith('stations.csv') ? metadata : measured,
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );
      final commands = <Map<String, dynamic>>[];
      final controller = ObservationController(
        cacheFactory: () => cache,
        meteoProvider: meteo,
        now: () => DateTime.utc(2026, 10, 30, 13),
        send: (c) async {
          commands.add(c);
        },
      );
      addTearDown(() {
        controller.dispose();
        meteo.dispose();
      });
      await tester.runAsync(
        () => controller.setContext([MobilityPoint(46.49, 7.56)]),
      );
      expect(calls, 0); // Choosing a location does not submit it automatically.
      await tester.runAsync(() => meteo.fetch());
      await tester.pumpWidget(
        MaterialApp(home: ObservationsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Gemessene Stationswerte · keine Prognose'),
        findsOneWidget,
      );
      await tester.tap(find.text('Messwerte abrufen').first);
      await tester.pumpAndSettle();
      expect(calls, 2);
      final station = find.text('Adelboden');
      await tester.scrollUntilVisible(
        station,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(station);
      await tester.pumpAndSettle();
      expect(find.textContaining('Wind: 36.0 km/h'), findsOneWidget);
      expect(
        find.textContaining('Niederschlagssumme: 0.0 mm / 10 min'),
        findsOneWidget,
      );
      await tester.runAsync(
        () => controller.setVisible(StationKind.meteo, true),
      );
      expect(commands.last['id'], 'meteo-stations');
      final features = commands.last['features'] as List;
      expect(features, hasLength(1));
      expect(features.first['detail'], contains('veraltet'));
      commands.clear();
      await tester.runAsync(controller.restoreRenderer);
      expect(commands.single['features'], features);
      await tester.runAsync(
        () => controller.setVisible(StationKind.meteo, false),
      );
      expect(commands.last['visible'], isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'station tabs and controls fit narrow landscape with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cache = OsintCacheDatabase(NativeDatabase.memory());
      addTearDown(cache.close);
      final controller = ObservationController(
        cacheFactory: () => cache,
        send: (_) async {},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ObservationsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('BAFU · Gewässer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Gemessene Stationswerte · keine Prognose'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
