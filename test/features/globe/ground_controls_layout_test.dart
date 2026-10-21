import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'spawn is an icon beside the right menu, coordinates do not consume bottom space and saved spots use the same control',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final spots = SpotRepository(db);
      final id = await spots.createSpot(
        name: 'Inspection spot',
        latitude: 47,
        longitude: 8.5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            spotRepository: spots,
            preferencesRepository: UserPreferencesRepository(db),
          ),
        ),
      );
      final globe = tester.widget<GlobeView>(find.byType(GlobeView)).controller;
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.emit({
        'type': 'point-selected',
        'latitude': 46.7,
        'longitude': 8.4,
        'altitude': 1000,
        'heightReference': 'wgs84Ellipsoid',
      });
      await tester.pumpAndSettle();
      final spawn = find.byTooltip('Spawn here'),
          menu = find.byTooltip('Map actions');
      expect(find.text('Spawn here'), findsNothing);
      expect(
        tester.getRect(spawn).right,
        lessThanOrEqualTo(tester.getRect(menu).left),
      );
      expect(tester.getRect(find.byType(GlobeView)).bottom, 568);
      await tester.tap(spawn);
      await tester.pumpAndSettle();
      expect(peer.commands.last['type'], 'enter-ground-view');
      peer.emit({
        'type': 'ground-view-state',
        'active': true,
        'pending': false,
      });
      await tester.pumpAndSettle();
      expect(find.byTooltip('Return to globe'), findsOneWidget);
      expect(tester.getRect(find.byType(GlobeView)).bottom, 568);
      await tester.tap(find.byTooltip('Return to globe'));
      await tester.pumpAndSettle();
      peer.emit({
        'type': 'ground-view-state',
        'active': false,
        'pending': false,
      });
      peer.emit({'type': 'spot-selected', 'id': id});
      await tester.pumpAndSettle();
      expect(find.text('Spawn at spot'), findsNothing);
      await tester.tap(find.byTooltip('Spawn here'));
      await tester.pumpAndSettle();
      expect(peer.commands.last['latitude'], 47);
      expect(peer.commands.last['longitude'], 8.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
