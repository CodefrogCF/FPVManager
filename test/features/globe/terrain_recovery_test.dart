import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late GlobeController controller;
  late FakeGlobeRenderer renderer;
  late MockClient client;
  setUp(() {
    client = MockClient(
      (_) async =>
          http.Response('{"type":"FeatureCollection","features":[]}', 200),
    );
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
  });
  tearDown(() {
    controller.dispose();
    client.close();
  });
  void status(String state, [String? reason]) => renderer.emit({
    'type': 'terrain-status',
    'state': state,
    'reason': reason,
  });
  void point() => renderer.emit({
    'type': 'point-selected',
    'latitude': 46.7,
    'longitude': 8.4,
    'altitude': 500,
    'heightReference': 'wgs84Ellipsoid',
  });

  test('partial tile failures warn without discarding terrain, selection or the profile generation', () {
    point();
    final selection = controller.selectedPoint,
        revision = controller.terrainRevision;
    renderer.emit({'type': 'terrain-resource-warning', 'active': true});
    expect(controller.terrainAvailable, isTrue);
    expect(controller.terrainResourceWarning, isTrue);
    expect(controller.canRetryTerrain, isTrue);
    expect(controller.selectedPoint, same(selection));
    expect(controller.terrainRevision, revision);
    renderer.emit({'type': 'terrain-resource-warning', 'active': false});
    expect(controller.terrainResourceWarning, isFalse);
    expect(controller.canRetryTerrain, isFalse);
  });

  test('tile failure updates the complete state before notifying and blocks height queries', () async {
    point();
    var observed = false;
    controller.addListener(() {
      observed = true;
      expect(controller.isReady, isTrue);
      expect(controller.terrainAvailable, isFalse);
      expect(controller.terrainState, GlobeTerrainState.unavailable);
      expect(controller.selectedPoint, isNull);
      expect(controller.error, isNull);
    });
    status('unavailable', 'tileFailed');
    expect(observed, isTrue);
    await expectLater(
      controller.queryTerrainElevation(latitude: 46.7, longitude: 8.4),
      throwsStateError,
    );
    expect(renderer.commands, isEmpty);
  });

  test('fallback map picks have an unverified height reference', () {
    status('offline', 'networkOffline');
    point();
    expect(
      controller.selectedPoint!.heightReference,
      VerticalReference.unverified,
    );
  });

  test('malformed states and reasons cannot alter terrain or selection', () {
    point();
    final selected = controller.selectedPoint;
    for (final value in [
      {'state': 'ready', 'reason': 'tileFailed'},
      {'state': 'offline', 'reason': null},
      {'state': 'unavailable', 'reason': 'untrusted'},
      {'state': 'loading', 'reason': 42},
      {'state': 'unknown', 'reason': null},
    ]) {
      renderer.emit({'type': 'terrain-status', ...value});
    }
    expect(controller.terrainAvailable, isTrue);
    expect(controller.selectedPoint, same(selected));
  });

  test('a height result from before outage and recovery is rejected', () async {
    final request = controller.queryTerrainElevation(
      latitude: 46.7,
      longitude: 8.4,
    );
    final check = expectLater(request, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final command = renderer.commands.last;
    status('unavailable', 'tileFailed');
    status('loading');
    status('ready');
    renderer.acknowledge(
      command,
      result: {
        'latitude': 46.7,
        'longitude': 8.4,
        'heightMeters': 1234.0,
        'heightReference': 'wgs84Ellipsoid',
        'samplingMethod': 'most-detailed',
      },
    );
    await check;
    expect(controller.terrainAvailable, isTrue);
  });

  test(
    'retry is deduplicated, preserves map settings and follows renderer status',
    () async {
      await controller.setMapStyle(GlobeMapStyle.relief);
      await controller.setSavedSpotsVisible(false);
      status('unavailable', 'tileFailed');
      renderer.commands.clear();
      renderer.autoAcknowledge = false;
      final first = controller.retryTerrain();
      await controller.retryTerrain();
      await Future<void>.delayed(Duration.zero);
      expect(renderer.commands.single['type'], 'retry-terrain');
      expect(controller.terrainRetrying, isTrue);
      status('loading');
      status('ready');
      renderer.acknowledge(renderer.commands.single);
      await first;
      expect(controller.terrainRetrying, isFalse);
      expect(controller.terrainAvailable, isTrue);
      expect(controller.savedSpotsVisible, isFalse);
      renderer.emit({'type': 'map-style-changed', 'style': 'relief'});
      expect(controller.mapStyle, GlobeMapStyle.relief);
    },
  );

  test('failed retry releases busy state; a retired session cannot recover terrain', () async {
    status('unavailable', 'connectionFailed');
    renderer.autoAcknowledge = false;
    final retry = controller.retryTerrain();
    final check = expectLater(retry, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    status('loading');
    renderer.acknowledge(renderer.commands.last, error: 'Transport failed');
    await check;
    expect(controller.canRetryTerrain, isTrue);
    final old = renderer.sessionId;
    renderer.sessionId = 'replacement';
    renderer.sequence = 0;
    renderer.ready();
    status('unavailable', 'tileFailed');
    renderer.emit({
      'type': 'terrain-status',
      'state': 'ready',
      'reason': null,
      'sessionId': old,
    });
    expect(controller.terrainAvailable, isFalse);
    controller.suspend();
    status('ready');
    expect(controller.isReady, isFalse);
    expect(controller.terrainAvailable, isFalse);
  });

  test('diagnostic offline mode disables retries without I/O', () async {
    status('offline', 'diagnosticOffline');
    expect(controller.canRetryTerrain, isFalse);
    await controller.retryTerrain();
    expect(renderer.commands, isEmpty);
  });
}
