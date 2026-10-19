import '../../helpers/fake_globe_renderer.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';
import 'package:fpvmanager/features/globe/terrain_information_dialog.dart';

void main() {
  late FpvDatabase database;
  late SpotRepository repository;
  late int spotId;

  setUp(() async {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
    spotId = await repository.createSpot(
      name: 'Saved Spot B',
      latitude: 47,
      longitude: 8.5,
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'terrain results reach the typed dialog and stale selections do not',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: FPVHomeScreen(spotRepository: repository)),
      );
      final controller = tester
          .widget<GlobeView>(find.byType(GlobeView))
          .controller;
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      void point(double latitude) => renderer.emit({
        'type': 'point-selected',
        'latitude': latitude,
        'longitude': 8.4,
        'altitude': 500,
        'heightReference': 'wgs84Ellipsoid',
      });
      void answer() => renderer.acknowledge(
        renderer.commands.last,
        result: {
          'latitude': 46.7,
          'longitude': 8.4,
          'heightMeters': 550,
          'heightReference': 'wgs84Ellipsoid',
          'samplingMethod': 'most-detailed',
        },
      );
      point(46.7);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Query terrain elevation'));
      answer();
      await tester.pumpAndSettle();
      expect(find.byType(TerrainInformationDialog), findsOneWidget);
      expect(find.text('550.0 m · WGS84 ellipsoid'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Query terrain elevation'));
      point(47);
      answer();
      await tester.pumpAndSettle();
      expect(find.byType(TerrainInformationDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'saved spot selection prevents terrain queries and stale defaults',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: FPVHomeScreen(spotRepository: repository)),
      );
      final controller = tester
          .widget<GlobeView>(find.byType(GlobeView))
          .controller;
      final renderer = FakeGlobeRenderer(controller);
      renderer.attach();
      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );
      await tester.pumpAndSettle();

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'point-selected',
          'latitude': 46.7,
          'longitude': 8.4,
          'altitude': 500,
        }),
      );
      await tester.pump();
      final terrainButton = find.widgetWithIcon(
        IconButton,
        Icons.terrain_outlined,
      );
      expect(tester.widget<IconButton>(terrainButton).onPressed, isNotNull);

      controller.handleEvent(
        renderer.encode({
          'source': 'fpvmanager-globe',
          'type': 'spot-selected',
          'id': spotId,
        }),
      );
      await tester.pump();
      expect(find.text('Saved Spot B'), findsOneWidget);
      expect(tester.widget<IconButton>(terrainButton).onPressed, isNull);

      await tester.tap(find.byTooltip('FPV Spots'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Spot'));
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      for (final label in ['Latitude (WGS84)', 'Longitude (WGS84)']) {
        final field = fields.singleWhere(
          (field) => field.decoration?.labelText == label,
        );
        expect(field.controller!.text, isEmpty);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // The screen must not close an injected repository's database.
      expect((await repository.getSpot(spotId))?.name, 'Saved Spot B');
    },
  );
}
