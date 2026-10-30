import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/home/globe_search.dart';
import 'package:fpvmanager/features/home/coordinates_dialog.dart';
import 'package:fpvmanager/features/mobility/destination_search.dart';

String response(String label) => jsonEncode({
  'results': [
    {
      'attrs': {'label': label, 'lat': 46.95, 'lon': 7.44},
    },
  ],
});

void main() {
  test('WGS84 pairs and supported LV95 formats are local and unambiguous', () {
    for (final input in [
      '46.7, 8.4',
      'WGS84: 46.7 8.4',
      '46,7; 8,4',
      '46.7 / 8.4',
    ]) {
      final result = parseGlobeCoordinates(input)!;
      expect(result.point.latitude, 46.7);
      expect(result.point.longitude, 8.4);
      expect(result.name, startsWith('WGS84'));
    }
    for (final input in [
      'LV95: 2600000 / 1200000',
      '2 600 000 / 1 200 000',
      "2’600’000 1’200’000",
      '2600000, 1200000',
    ]) {
      final result = parseGlobeCoordinates(input)!;
      expect(result.name, startsWith('LV95'));
      expect(result.point.latitude, closeTo(46.95108, .0001));
    }
    for (final input in [
      '91, 8',
      '47, 181',
      '46,7,8,4',
      'LV95: 0 / 0',
      'WGS84: NaN, 8',
    ]) {
      expect(
        () => parseGlobeCoordinates(input),
        throwsFormatException,
        reason: input,
      );
    }
    expect(parseGlobeCoordinates('Bahnhofstrasse 1 Zürich'), isNull);
  });

  test('local/invalid coordinates never reach geocoding and identical requests coalesce', () async {
    var requests = 0;
    final gate = Completer<http.Response>();
    final service = DestinationSearch(
      client: MockClient((_) {
        requests++;
        return gate.future;
      }),
    );
    final search = GlobeSearch(destinations: service);
    addTearDown(search.dispose);
    addTearDown(service.dispose);
    expect(await search.search('46.7,8.4'), hasLength(1));
    await expectLater(search.search('91,8'), throwsFormatException);
    expect(requests, 0);
    final a = search.search('Bern'), b = search.search('  Bern  ');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    gate.complete(http.Response(response('Bern, Bahnhofplatz'), 200));
    expect((await a).single.name, 'Bern, Bahnhofplatz');
    expect((await b).single.name, 'Bern, Bahnhofplatz');
  });

  testWidgets(
    'typing is local; late responses cannot replace a newer query, results require explicit selection',
    (tester) async {
      final pending = <String, Completer<http.Response>>{};
      final service = DestinationSearch(
        client: MockClient(
          (request) =>
              (pending[request.url.queryParameters['searchText']!] =
                      Completer<http.Response>())
                  .future,
        ),
      );
      final search = GlobeSearch(destinations: service);
      addTearDown(search.dispose);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CoordinatesDialog(search: search)),
        ),
      );
      final input = find.byKey(const ValueKey('globeSearch'));
      await tester.enterText(input, 'Bern');
      await tester.pump();
      expect(pending, isEmpty);
      await tester.tap(find.text('Suchen'));
      await tester.pump();
      await tester.enterText(input, 'Zürich');
      await tester.pump();
      await tester.tap(find.text('Suchen'));
      await tester.pump();
      pending['Zürich']!.complete(
        http.Response(
          response('Zürich, Bahnhofstrasse'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zürich, Bahnhofstrasse'), findsOneWidget);
      pending['Bern']!.complete(
        http.Response(response('Bern, Bahnhofplatz'), 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bern, Bahnhofplatz'), findsNothing);
      expect(find.text('Zürich, Bahnhofstrasse'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'coordinate results and offline errors fit narrow, landscape and keyboard-constrained screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = DestinationSearch(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final search = GlobeSearch(destinations: service);
      addTearDown(search.dispose);
      addTearDown(service.dispose);
      for (final size in [const Size(320, 640), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CoordinatesDialog(key: ValueKey(size), search: search),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('globeSearch')),
          '46.7,8.4',
        );
        await tester.tap(find.text('Suchen'));
        await tester.pumpAndSettle();
        expect(find.textContaining('WGS84 · 46.700000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const ValueKey('globeSearch')),
          'Bern',
        );
        await tester.tap(find.text('Suchen'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Onlinesuche nicht verfügbar'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
