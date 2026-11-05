import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/infrastructure_clearance.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test('infrastructure findings preserve source, classification and missing coverage', () {
    final report = InfrastructureClearanceReport.fromJson({
      'findings': [
        {
          'segment': 1,
          'id': 'deck-123',
          'name': 'Test overpass',
          'kind': 'deck',
          'quality': 'external-unverified',
          'source': 'Local bridge dimensions',
          'sourceId': 'CH-123',
          'status': 'model-contact',
          'clearanceMeters': -0.25,
        },
      ],
      'checkedSamples': 35,
      'unknownHeightSamples': 5,
      'modelCount': 1,
      'incomplete': true,
      'processingLimited': false,
      'coverage': 'local-models-only',
      'message': 'No national coverage guarantee.',
    });
    expect(report.incomplete, isTrue);
    expect(report.findings.single.modelContact, isTrue);
    expect(report.findings.single.sourceId, 'CH-123');
    expect(report.findings.single.quality, 'external-unverified');
    expect(report.unknownHeightSamples, 5);
    expect(report.coverage, 'local-models-only');
  });

  test('malformed status and incomplete reported data are rejected', () {
    expect(
      () => InfrastructureClearanceReport.fromJson({}),
      throwsFormatException,
    );
    expect(
      () => InfrastructureClearanceFinding.fromJson({
        'segment': -1,
        'clearanceMeters': 0,
      }),
      throwsFormatException,
    );
  });

  test(
    'bounded renderer requests and reload discard stale local clearance',
    () async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
      peer.autoAcknowledge = false;
      peer.onCommand = (command) {
        switch (command['type']) {
          case 'import-infrastructure-clearance':
            peer.acknowledge(
              command,
              result: {'count': 1, 'quality': 'external-unverified'},
            );
            return;
          case 'query-infrastructure-clearance':
            peer.acknowledge(
              command,
              result: {
                'findings': [],
                'checkedSamples': 2,
                'unknownHeightSamples': 1,
                'modelCount': 1,
                'incomplete': true,
                'processingLimited': false,
                'coverage': 'local-models-only',
                'message': 'Local geometry only; no nationwide coverage.',
              },
            );
            return;
          default:
            peer.acknowledge(command);
            return;
        }
      };
      await globe.importInfrastructureGeometry({
        'version': 1,
        'elevationReference': 'WGS84_ELLIPSOID',
        'source': 'Unverified local test sections',
        'surfaces': [],
      });
      expect(globe.infrastructureSurfaceCount, 1);
      final report = await globe.queryInfrastructureClearance(const [
        InfrastructureRoutePoint(
          latitude: 46.8,
          longitude: 8.2,
          heightMetersWgs84: null,
          segment: 0,
        ),
        InfrastructureRoutePoint(
          latitude: 46.8,
          longitude: 8.2001,
          heightMetersWgs84: 120,
          segment: 0,
        ),
      ]);
      expect(report.incomplete, true);
      expect(report.findings, isEmpty);
      expect(
        peer.commands.any((c) => c['type'] == 'query-infrastructure-clearance'),
        true,
      );
      await globe.showInfrastructureClearance(true);
      expect(peer.commands.last['type'], 'set-infrastructure-clearance-layer');
      peer.emit({'type': 'renderer-loading'});
      expect(globe.infrastructureSurfaceCount, 0);
      await expectLater(
        globe.queryInfrastructureClearance(const [
          InfrastructureRoutePoint(
            latitude: 46.8,
            longitude: 8.2,
            heightMetersWgs84: 110,
            segment: 0,
          ),
          InfrastructureRoutePoint(
            latitude: 46.8,
            longitude: 8.2001,
            heightMetersWgs84: 110,
            segment: 0,
          ),
        ]),
        throwsStateError,
      );
    },
  );
}
