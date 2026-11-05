import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/scene_layers_section.dart';

import '../../helpers/fake_globe_renderer.dart';

Map<String, dynamic> meshDocument() => {
  'version': 2,
  'format': 'fpvmanager-georeferenced-trimesh',
  'source': 'Local demonstration only',
  'sourceId': 'fixture',
  'coordinateReference': 'EPSG:4979',
  'elevationReference': 'WGS84_ELLIPSOID',
  'visualMesh': {
    'vertices': [
      [8.2, 46.8, 500],
      [8.2001, 46.8, 500],
      [8.2, 46.80001, 501],
    ],
    'triangles': [
      [0, 1, 2],
    ],
  },
  'collisionMesh': {
    'vertices': [
      [8.2, 46.8, 500],
      [8.2001, 46.8, 500],
      [8.2, 46.80001, 501],
    ],
    'triangles': [
      [0, 1, 2],
    ],
  },
};

void main() {
  test('v2 imports as a bounded, chunkable renderer command', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await globe.importTunnelModel(meshDocument());
    expect(peer.commands.last['type'], 'import-tunnel-model');
    expect(
      (peer.commands.last['document'] as Map)['coordinateReference'],
      'EPSG:4979',
    );
    expect(
      (peer.commands.last['document'] as Map)['collisionMesh'],
      isA<Map>(),
    );

    final invalid = meshDocument()..remove('coordinateReference');
    await expectLater(globe.importTunnelModel(invalid), throwsFormatException);
    expect(
      peer.commands.where((c) => c['type'] == 'import-tunnel-model'),
      hasLength(1),
      reason: 'Invalid CRS must be rejected before sending',
    );

    final oversized = meshDocument();
    oversized['sourceId'] = 'a' * 2097153;
    await expectLater(
      globe.importTunnelModel(oversized),
      throwsFormatException,
    );
    expect(
      peer.commands.where((c) => c['type'] == 'import-tunnel-model'),
      hasLength(1),
      reason: 'Oversized mesh must not cross the bridge',
    );
  });

  testWidgets(
    'import is discoverable without tunnel route layer; mesh-only models cannot fly',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
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
      await tester.tap(find.text('3D-Umgebung und Himmelslicht'));
      await tester.pumpAndSettle();
      expect(globe.tunnelRoutesVisible, false);
      expect(
        find.text('3D-Tunnelmesh / Querschnitte importieren (JSON)'),
        findsOneWidget,
      );

      await globe.importTunnelModel(meshDocument());
      peer.emit({
        'type': 'tunnel-model-state',
        'ready': true,
        'flight': false,
        'pending': false,
        'quality': 'external-mesh-unverified',
        'datasetSource': 'Local demonstration only',
        'canFly': false,
        'visualTriangles': 1,
        'collisionTriangles': 1,
      });
      await tester.pumpAndSettle();
      expect(globe.tunnelModelReady, true);
      expect(globe.tunnelMeshTriangles, 1);
      expect(globe.tunnelCollisionTriangles, 1);
      expect(globe.tunnelModelSource, 'Local demonstration only');
      expect(globe.tunnelModelCanFly, false);
      expect(find.textContaining('GEOREFERENZIERTES MESH'), findsOneWidget);
      expect(
        find.text('Modellquelle: Local demonstration only'),
        findsOneWidget,
      );
      expect(
        find.text('Sichtdreiecke: 1 · Kollisionsdreiecke: 1'),
        findsOneWidget,
      );
      final fly = find.widgetWithText(OutlinedButton, 'Durchflug: GPS');
      expect(fly, findsOneWidget);
      expect(tester.widget<OutlinedButton>(fly).onPressed, isNull);
      await expectLater(globe.enterTunnelFlight(), throwsStateError);

      peer.emit({'type': 'renderer-loading'});
      await tester.pump();
      expect(globe.tunnelModelReady, false);
      expect(globe.tunnelModelCanFly, false);
      expect(globe.tunnelMeshTriangles, isNull);
    },
  );
}
