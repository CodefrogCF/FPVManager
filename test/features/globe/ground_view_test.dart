import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/ground_view_button.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'selected point exposes spawn; active/pending controls exit and flat terrain blocks entry',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GroundViewButton(controller: globe)),
        ),
      );
      peer.emit({
        'type': 'point-selected',
        'latitude': 46.7,
        'longitude': 8.4,
        'altitude': 1000,
        'heightReference': 'wgs84Ellipsoid',
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spawn here'));
      await tester.pumpAndSettle();
      expect(peer.commands.last['type'], 'enter-ground-view');
      peer.emit({
        'type': 'ground-view-state',
        'active': true,
        'pending': false,
      });
      await tester.pumpAndSettle();
      expect(find.byTooltip('Return to globe'), findsOneWidget);
      await tester.tap(find.byTooltip('Return to globe'));
      await tester.pumpAndSettle();
      expect(peer.commands.last['type'], 'exit-ground-view');
      peer.emit({
        'type': 'ground-view-state',
        'active': false,
        'pending': false,
        'reason': 'Terrain unavailable',
      });
      peer.emit({
        'type': 'terrain-status',
        'state': 'unavailable',
        'reason': 'tileFailed',
      });
      await tester.pumpAndSettle();
      await expectLater(
        globe.enterGroundView(latitude: 46.7, longitude: 8.4),
        throwsStateError,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
