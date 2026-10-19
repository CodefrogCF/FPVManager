import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

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
    'saved spot selection prevents terrain queries and stale defaults',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: FPVHomeScreen(spotRepository: repository)),
      );
      final controller = tester
          .widget<GlobeView>(find.byType(GlobeView))
          .controller;
      controller.attach((_) async {});
      controller.handleEvent(
        jsonEncode({
          'source': 'fpvmanager-globe',
          'type': 'globe-ready',
          'terrainAvailable': true,
        }),
      );
      await tester.pumpAndSettle();

      controller.handleEvent(
        jsonEncode({
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
        jsonEncode({
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
