import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/destination_search.dart';

String get _body => jsonEncode({
  'results': [
    {
      'attrs': {
        'label': '<b>Bahnhof</b> Bern &amp; Umgebung',
        'lat': 46.949,
        'lon': 7.439,
      },
    },
  ],
});

void main() {
  test(
    'Swiss address search is bounded and returns WGS84 text-only destinations',
    () async {
      var requests = 0;
      final service = DestinationSearch(
        client: MockClient((r) async {
          requests++;
          expect(r.url.host, 'api3.geo.admin.ch');
          expect(r.url.queryParameters['searchText'], 'Bahnhof Bern');
          expect(r.url.queryParameters['sr'], '4326');
          expect(r.url.queryParameters['limit'], '10');
          expect(r.url.queryParameters.containsKey('bbox'), isFalse);
          return http.Response(_body, 200);
        }),
      );
      addTearDown(service.dispose);
      for (final value in [
        'ab',
        'a' * 201,
        List.filled(11, 'Wort').join(' '),
      ]) {
        await expectLater(service.search(value), throwsFormatException);
      }
      expect(requests, 0);
      final result = (await service.search('  Bahnhof   Bern  ')).single;
      expect(result.name, 'Bahnhof Bern & Umgebung');
      expect(result.point.latitude, 46.949);
      expect(result.point.longitude, 7.439);
      expect(requests, 1);
    },
  );
  test('malformed coordinates and oversized responses are rejected', () async {
    final service = DestinationSearch(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'results': [
              {
                'attrs': {'label': 'Bad', 'lat': 123, 'lon': 8},
              },
            ],
          }),
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(service.search('Bern'), throwsFormatException);
    final large = DestinationSearch(
      client: MockClient((_) async => http.Response(' ' * (257 * 1024), 200)),
    );
    addTearDown(large.dispose);
    await expectLater(large.search('Bern'), throwsFormatException);
  });
  testWidgets(
    'typing stays local; submitting and selecting supplies the destination',
    (tester) async {
      var requests = 0;
      RoadDestination? selected;
      final service = DestinationSearch(
        client: MockClient((_) async {
          requests++;
          return http.Response(_body, 200);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoadDestinationSearch(
              search: service,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('destinationSearch')),
        'Bahnhof Bern',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 0);
      await tester.tap(find.text('Ziel suchen'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.tap(find.text('Bahnhof Bern & Umgebung'));
      expect(selected?.point.longitude, 7.439);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
