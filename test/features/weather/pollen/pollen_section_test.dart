import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_section.dart';
import 'package:fpvmanager/features/weather/pollen/pollen_service.dart';

import 'pollen_service_test.dart' show MemoryPollenCache, assetUrl;
import 'pollen_parser_test.dart' show hourly, stationMetadata;

void main() {
  testWidgets('no location does not initiate a request', (tester) async {
    var calls = 0;
    final transport = MobilityHttp(
      client: MockClient((_) async {
        calls++;
        return http.Response('bad', 503);
      }),
    );
    final service = PollenService(
      cache: MemoryPollenCache(),
      transport: transport,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PollenSection(
            latitude: null,
            longitude: null,
            service: service,
          ),
        ),
      ),
    );
    expect(find.textContaining('Choose a saved flying spot'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    await service.dispose();
    transport.dispose();
  });

  testWidgets('station selection displays method, missing and source data', (
    tester,
  ) async {
    final transport = MobilityHttp(
      client: MockClient((request) async {
        if (request.url.path.endsWith('_meta_stations.csv')) {
          return http.Response(stationMetadata, 200);
        }
        if (request.url.path.endsWith('/pzh')) {
          return http.Response(
            jsonEncode({
              'properties': {'updated': '2026-11-03T12:22:00Z'},
              'assets': {
                'h_now': {'href': assetUrl.toString()},
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('_h_now.csv')) {
          return http.Response(hourly, 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    final clock = DateTime.utc(2026, 11, 3, 12, 40);
    final service = PollenService(
      cache: MemoryPollenCache(),
      transport: transport,
      now: () => clock,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PollenSection(
              latitude: 47.40,
              longitude: 8.55,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Find monitoring stations'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zürich (0 km)'), findsOneWidget);
    final button = find.text('Load hourly observations');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('Latest station observation:'), findsOneWidget);
    expect(
      find.textContaining('Beech / Buche: missing / unknown'),
      findsOneWidget,
    );
    expect(find.textContaining('Birch / Birke: 0 No/m³'), findsOneWidget);
    expect(
      find.textContaining('historical manual measurements'),
      findsOneWidget,
    );
    expect(find.textContaining('Source: MeteoSwiss'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.dispose();
    transport.dispose();
  });
}
