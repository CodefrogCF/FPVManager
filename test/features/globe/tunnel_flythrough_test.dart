import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/scene_layers_section.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  testWidgets(
    'synthetic 3D tunnel is explicitly opt-in; renderer loss clears it',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.autoAcknowledge = false;
      peer.onCommand = (command) {
        if (command['type'] == 'scan-tunnel-infrastructure') {
          peer.acknowledge(
            command,
            result: {
              'incomplete': false,
              'routes': [
                {
                  'id': 'road:tunnel:0',
                  'name': 'Demo Tunnel',
                  'kind': 'tunnel',
                  'transport': 'road',
                  'source': 'ch.swisstopo.swisstlm3d-strassen',
                  'sourceId': 'tunnel',
                  'heightReference': 'unavailable',
                },
              ],
            },
          );
        } else {
          peer.acknowledge(command);
          if (command['type'] == 'prepare-tunnel-model') {
            peer.emit({
              'type': 'tunnel-model-state',
              'ready': true,
              'flight': false,
              'pending': false,
              'quality': 'simulation-only',
            });
          } else if (command['type'] == 'enter-tunnel-flight') {
            peer.emit({
              'type': 'tunnel-model-state',
              'ready': true,
              'flight': true,
              'pending': false,
              'quality': 'simulation-only',
            });
          } else if (command['type'] == 'remove-tunnel-model') {
            peer.emit({
              'type': 'tunnel-model-state',
              'ready': false,
              'flight': false,
              'pending': false,
            });
          }
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: globe,
                builder: (context, _) => SceneLayersSection(controller: globe),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('3D & Licht'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tunnelwerkzeuge'));
      await tester.tap(find.text('Tunnelwerkzeuge'));
      await tester.pumpAndSettle();
      final scan = find.text('Tunnel in der Nähe suchen');
      await tester.ensureVisible(scan);
      await tester.tap(scan);
      await tester.pumpAndSettle();
      expect(globe.tunnelRoutes, hasLength(1));
      // Tapping an automatically discovered axis can also offer the same
      // explicit, simulation-only 3D model generation action.
      peer.emit({
        'type': 'infrastructure-selected',
        'id': 'road:tunnel:0',
        'name': 'Demo Tunnel',
        'kind': 'tunnel',
        'datasetSource': 'ch.swisstopo.swisstlm3d-strassen',
      });
      await tester.pumpAndSettle();
      expect(
        globe.selectedInfrastructure?['datasetSource'],
        'ch.swisstopo.swisstlm3d-strassen',
      );
      expect(
        find.text('Quelle: ch.swisstopo.swisstlm3d-strassen'),
        findsOneWidget,
      );
      expect(find.text('Aus Achse 3D-Gewölbe simulieren'), findsOneWidget);
      final menu = find.byType(PopupMenuButton<String>);
      await tester.ensureVisible(menu.last);
      await tester.tap(menu.last);
      await tester.pumpAndSettle();
      final modelOption = find.text('3D-Gewölbetunnel erzeugen (synthetisch)');
      await tester.tap(modelOption);
      await tester.pumpAndSettle();
      expect(
        peer.commands.any(
          (c) =>
              c['type'] == 'prepare-tunnel-model' && c['profile'] == 'vaulted',
        ),
        true,
      );
      expect(globe.tunnelModelReady, true);
      expect(globe.tunnelModelQuality, 'simulation-only');
      expect(find.textContaining('Nur Simulation'), findsWidgets);
      final fly = find.text('Durchflug: GPS');
      await tester.ensureVisible(fly);
      await tester.tap(fly);
      await tester.pumpAndSettle();
      expect(peer.commands.last['type'], 'enter-tunnel-flight');
      expect(peer.commands.last['flightMode'], 'gps');
      expect(globe.tunnelFlightActive, true);
      peer.emit({'type': 'renderer-loading'});
      await tester.pump();
      expect(globe.tunnelModelReady, false);
      expect(globe.tunnelFlightActive, false);
    },
  );
}
