import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/activity_profile.dart';
import 'package:fpvmanager/core/models/outdoor_layer.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/outdoor/outdoor_context.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 12, 15, 12);
  final polygon = {
    'type': 'Polygon',
    'coordinates': [
      [
        [8.0, 47.0],
        [8.1, 47.0],
        [8.1, 47.1],
        [8.0, 47.1],
        [8.0, 47.0],
      ],
    ],
  };
  Map<String, dynamic> feature(
    String id, {
    String status = 'rechtsverbindlich',
  }) => {
    'featureId': id,
    'layerBodId': OutdoorLayer.wildlife.serviceLayer,
    'properties': {
      'wrz_name': 'Schutzfläche $id',
      'schutzs_de': status,
      'schutzzeit': '01.12. - 20.04.',
      'best_de': 'Zutrittsverbot',
      'wegtyp_de': 'Erlaubter Weg / Route',
      'url_kanton': 'https://example.org/official-info',
    },
    'geometry': polygon,
  };
  test('protection and seasonal validity retain legal/recommended/unknown distinctions', () {
    expect(
      natureProtection({'schutzs_de': 'rechtsverbindlich'}),
      NatureProtection.statutory,
    );
    expect(
      natureProtection({'schutzs_de': 'empfohlen'}),
      NatureProtection.recommended,
    );
    expect(natureProtection({}), NatureProtection.unknown);
    expect(
      outdoorValidity({'schutzzeit': '01.12. - 20.04.'}, now, wildlife: true),
      startsWith('Innerhalb'),
    );
    expect(
      outdoorValidity(
        {'schutzzeit': '01.12. - 20.04.'},
        DateTime.utc(2026, 7, 1),
        wildlife: true,
      ),
      startsWith('Außerhalb'),
    );
    expect(
      outdoorValidity({'schutzzeit': '31.02. - 01.03.'}, now, wildlife: true),
      contains('nicht auswertbar'),
    );
    expect(outdoorValidity({}, now), startsWith('Undatiert'));
    expect(
      outdoorValidity({'duration_de': '01.01.2025 - 15.12.2026'}, now),
      startsWith('Innerhalb'),
    );
    expect(
      outdoorValidity({'duration_de': '01.01.2025 - 30.10.2026'}, now),
      'Abgelaufen',
    );
    expect(
      outdoorValidity({'duration_de': '01.01.2027 - 30.10.2027'}, now),
      'Zukünftig',
    );
  });
  test('overlapping objects, source attributes and bounded geometry checks remain independent', () {
    final path = [MobilityPoint(47.05, 8.05)];
    final data = parseOutdoorContext((
      jsonEncode({
        'results': [feature('one'), feature('two', status: 'empfohlen')],
      }),
      path,
      now,
    ));
    expect(data['records'], hasLength(2));
    expect(data['incomplete'], isTrue);
    expect(data['records'][0]['relation'], 'Geometrische Schneidung');
    expect(data['records'][1]['classification'], 'recommended');
    expect(
      data['records'][0]['attributes']['wegtyp_de'],
      'Erlaubter Weg / Route',
    );
    final closure = {
      'type': 'LineString',
      'coordinates': [
        [8.0, 47.05],
        [8.1, 47.05],
      ],
    };
    expect(
      outdoorRelation(closure, [MobilityPoint(47.05, 8.05)]),
      startsWith('In unmittelbarer Nähe'),
    );
    expect(
      outdoorRelation(closure, [
        MobilityPoint(47.0, 8.05),
        MobilityPoint(47.1, 8.05),
      ]),
      startsWith('Geometrische Schneidung'),
    );
    expect(
      outdoorRelation(closure, List.filled(1001, path.first)),
      contains('nicht durchgeführt'),
    );
    final bad = feature('bad')
      ..['geometry'] = {
        'type': 'LineString',
        'coordinates': [
          [8, 47],
          [8, double.nan],
        ],
      };
    expect(
      () => parseOutdoorContext((
        jsonEncode({
          'results': [bad],
        }),
        path,
        now,
      )),
      throwsA(anything),
    );
  });
  test('detail requests are bounded, coalesced and retain the dated snapshot after failures', () async {
    var calls = 0, fail = false;
    final p = OutdoorContextProvider(
      path: [MobilityPoint(47.05, 8.05)],
      layers: [OutdoorLayer.wildlife],
      now: () => now,
      client: MockClient((r) async {
        calls++;
        expect(r.url.queryParameters['limit'], '100');
        expect(r.url.queryParameters['geometryFormat'], 'geojson');
        expect(
          r.url.queryParameters['layers'],
          'all:${OutdoorLayer.wildlife.serviceLayer}',
        );
        return fail
            ? http.Response('down', 503)
            : http.Response(
                jsonEncode({
                  'results': [feature('one')],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );
    addTearDown(p.dispose);
    final first = p.fetch(), second = p.fetch();
    expect(identical(first, second), isTrue);
    await first;
    await second;
    expect(calls, 1);
    final previous = p.status.dataset;
    fail = true;
    await expectLater(
      p.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(p.status.dataset, same(previous));
    expect(p.status.dataset!.persistable, isFalse);
    expect(p.status.dataState, OsintDataState.refreshFailed);
  });
  test('layer settings persist and survive profile map defaults and renderer replacement', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = UserPreferencesRepository(db), globe = GlobeController();
    addTearDown(globe.dispose);
    final peer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    await globe.initializePreferences(repo);
    await globe.setOutdoorLayer(
      OutdoorLayer.hiking,
      visible: true,
      opacity: .45,
    );
    await globe.setOutdoorLayer(
      OutdoorLayer.wildlife,
      visible: true,
      opacity: .7,
    );
    await globe.applyActivityDefaults(
      const ActivityMapDefaults(style: GlobeMapStyle.topographic),
    );
    expect(
      (await repo.getPreferences()).outdoorLayers[OutdoorLayer.hiking]!.visible,
      isTrue,
    );
    final replacement = GlobeController();
    addTearDown(replacement.dispose);
    final newPeer = FakeGlobeRenderer(replacement)
      ..attach()
      ..ready();
    await replacement.initializePreferences(repo);
    final commands = newPeer.commands
        .where(
          (c) =>
              c['type'] == 'set-situational-overlay' &&
              '${c['id']}'.startsWith('outdoor-'),
        )
        .toList();
    expect(
      commands.map((c) => c['id']),
      containsAll(['outdoor-hiking', 'outdoor-wildlife']),
    );
    expect(
      commands.singleWhere((c) => c['id'] == 'outdoor-hiking')['opacity'],
      .45,
    );
    peer.emit({
      'type': 'situational-status',
      'id': 'outdoor-wildlife',
      'state': 'failed',
    });
    expect(globe.situationalStatus('outdoor-wildlife'), 'failed');
    await globe.setOutdoorLayer(OutdoorLayer.wildlife, retry: true);
    expect(peer.commands.last['retry'], isTrue);
    expect(
      () => decodeOutdoorPreferences('{"hiking":{"visible":true,"opacity":3}}'),
      throwsFormatException,
    );
  });
}
