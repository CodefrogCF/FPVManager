import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/uas_zone_fixture.dart';

void main() {
  late Map<String, dynamic> data;
  late MockClient client;
  late GlobeController controller;
  late FakeGlobeRenderer renderer;
  var downloads = 0;
  setUp(() {
    downloads = 0;
    data = uasFixtureCollection([uasFixtureFeature()]);
    client = MockClient((_) async {
      downloads++;
      return http.Response(jsonEncode(data), 200);
    });
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
  });
  tearDown(() {
    controller.dispose();
    client.close();
  });

  test('renderer receives usable features and metadata identifies a partial source', () async {
    data = {
      ...uasFixtureCollection([
        uasFixtureFeature(),
        {...uasFixtureFeature(), 'geometry': null},
        uasFixtureFeature(overrides: {'restriction': null}),
      ]),
      'numberMatched': 4,
      'links': [
        {'rel': 'next', 'href': 'https://example.invalid/next'},
      ],
    };
    await controller.setUasZonesVisible(true);
    final report = controller.uasDatasetAssessment!;
    expect(report.sourceFeatureCount, 3);
    expect(report.skippedFeatureCount, 1);
    expect(report.featuresMissingDetails, 1);
    expect(report.hasNextPage, isTrue);
    expect(downloads, 1); // No follow-up request to an arbitrary next-page URL.
    expect((renderer.commands.last['geojson']['features'] as List).length, 2);
    expect(
      (controller.uasDisplayedDataset!.data['features'] as List).length,
      3,
    );
  });

  test('rejected content retains prior provenance and an explicit retry bypasses its cache', () async {
    await controller.setUasZonesVisible(true);
    final first = controller.uasDatasetAssessment;
    final originalDataset = controller.uasDisplayedDataset;
    data = uasFixtureCollection([
      {'type': 'Feature', 'geometry': null},
    ]);
    await expectLater(controller.refreshUasZones(), throwsFormatException);
    expect(controller.uasDatasetAssessment, same(first));
    expect(controller.uasDisplayedDataset, same(originalDataset));
    expect(controller.uasZonesError, contains('incomplete dataset'));
    data = uasFixtureCollection([
      uasFixtureFeature(overrides: {'name': 'Recovered source zone'}),
    ]);
    await controller.setUasZonesVisible(false);
    await controller.setUasZonesVisible(true);
    expect(downloads, 3);
    expect(controller.uasDatasetAssessment, isNot(same(first)));
    expect(controller.uasZonesError, isNull);
  });

  test('failed renderer replacement keeps the assessment of the displayed snapshot', () async {
    await controller.setUasZonesVisible(true);
    final first = controller.uasDatasetAssessment;
    data = uasFixtureCollection([
      uasFixtureFeature(overrides: {'restriction': null}),
    ]);
    renderer.autoAcknowledge = false;
    final pending = controller.refreshUasZones();
    final check = expectLater(pending, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    renderer.acknowledge(
      renderer.commands.last,
      error: 'Fixture replacement failure',
    );
    await check;
    expect(controller.uasDatasetAssessment, same(first));
    expect(controller.uasDatasetAssessment!.featuresMissingDetails, 0);
  });
}
