import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/mobility_preferences.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_client.dart';
import 'package:fpvmanager/features/mobility/ojp/public_transport_section.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import 'ojp_parser_test.dart' show ojpFixture;

void main() {
  testWidgets(
    'a saved spot is routed to its exact coordinates, not the parking point',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final spots = SpotRepository(db);
      final id = await spots.createSpot(
        name: 'Spot Ziel',
        latitude: 46.765,
        longitude: 7.654,
      );
      final prefs = MobilityPreferences(db);
      await prefs.saveAccess(id, SpotAccess(parking: MobilityPoint(46.0, 7.0)));
      final globe = GlobeController();
      addTearDown(globe.dispose);
      var requests = 0;
      final client = OjpTripClient(
        readKey: () async => 'test-key',
        httpClient: MockClient((request) async {
          requests++;
          expect(
            request.body,
            contains('<siri:Longitude>7.654</siri:Longitude>'),
          );
          expect(
            request.body,
            contains('<siri:Latitude>46.765</siri:Latitude>'),
          );
          expect(
            request.body,
            isNot(contains('<siri:Latitude>46.0</siri:Latitude>')),
          );
          return http.Response.bytes(
            utf8.encode(ojpFixture),
            200,
            headers: {'content-type': 'application/xml; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicTransportSection(
                spots: spots,
                preferences: prefs,
                globe: globe,
                client: client,
                initialSpotId: id,
                initialOrigin: MobilityPoint(47.0, 8.0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final consent = find.text(
        'Start, Ziel und Reisezeit für die Abfrage an opentransportdata.swiss senden.',
      );
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      final search = find.text('ÖV-Verbindungen suchen');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.textContaining('OJP-Abfrageergebnis'), findsOneWidget);
    },
  );
}
