import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_client.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_models.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

import 'ojp_parser_test.dart' show ojpFixture;

final query = OjpTripQuery(
  origin: MobilityPoint(47, 8),
  destination: MobilityPoint(46, 7),
  timeUtc: DateTime.utc(2026, 11, 3, 13),
  mode: OjpTimeMode.departure,
);

void main() {
  test(
    'OJP 2.0 POST has correct endpoint, Bearer and coordinate/time',
    () async {
      final client = OjpTripClient(
        readKey: () async => 'secret-v2',
        httpClient: MockClient((request) async {
          expect(request.url, OjpTripClient.endpoint);
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer secret-v2');
          expect(
            request.headers['Content-Type'],
            startsWith('application/xml'),
          );
          expect(request.body, contains('version="2.0"'));
          expect(
            request.body,
            contains('<siri:Longitude>8.0</siri:Longitude>'),
          );
          expect(request.body, contains('<siri:Latitude>46.0</siri:Latitude>'));
          expect(request.body, contains('<Origin>'));
          expect(
            request.body,
            contains('<DepArrTime>2026-11-03T13:00:00Z</DepArrTime>'),
          );
          return http.Response.bytes(
            utf8.encode(ojpFixture),
            200,
            headers: {'content-type': 'application/xml; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.dispose);
      final snapshot = await client.search(
        query,
        originName: 'A',
        destinationName: 'B',
      );
      expect(snapshot.journeys, hasLength(1));
      expect(snapshot.destinationName, 'B');
      final roundTrip = OjpJourneySnapshot.fromJson(snapshot.toJson());
      expect(roundTrip.journeys.single.legs[1].line, 'IC 8');
      expect(roundTrip.fetchedAtUtc, snapshot.fetchedAtUtc);
    },
  );

  test('arrival request puts time under Destination, never Origin', () {
    final xml = buildOjpTripXml(
      OjpTripQuery(
        origin: query.origin,
        destination: query.destination,
        timeUtc: query.timeUtc,
        mode: OjpTimeMode.arrival,
      ),
      timestamp: DateTime.utc(2026, 11, 3, 10),
    );
    final beforeDestination = xml.split('<Destination>').first;
    expect(beforeDestination, isNot(contains('<DepArrTime>')));
    expect(
      xml.split('<Destination>').last,
      contains('<DepArrTime>2026-11-03T13:00:00Z</DepArrTime>'),
    );
  });

  test('in-flight and recently repeated queries count once', () async {
    var requests = 0;
    final pending = Completer<http.Response>();
    final client = OjpTripClient(
      readKey: () async => 'secret-v2',
      httpClient: MockClient((_) async {
        requests++;
        return pending.future;
      }),
    );
    addTearDown(client.dispose);
    final first = client.search(query, originName: 'A', destinationName: 'B');
    final second = client.search(query, originName: 'A', destinationName: 'B');
    pending.complete(
      http.Response.bytes(
        utf8.encode(ojpFixture),
        200,
        headers: {'content-type': 'application/xml; charset=utf-8'},
      ),
    );
    final results = await Future.wait([first, second]);
    expect(identical(results.first, results.last), true);
    await client.search(query, originName: 'A', destinationName: 'B');
    expect(requests, 1);
  });

  test('missing credential and authentication errors are explicit', () async {
    final missing = OjpTripClient(
      readKey: () async => null,
      httpClient: MockClient((_) async => http.Response('', 200)),
    );
    addTearDown(missing.dispose);
    await expectLater(
      missing.search(query, originName: 'A', destinationName: 'B'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('key missing'),
        ),
      ),
    );

    final failed = OjpTripClient(
      readKey: () async => 'secret-v2',
      httpClient: MockClient((_) async => http.Response('private error', 401)),
    );
    addTearDown(failed.dispose);
    await expectLater(
      failed.search(query, originName: 'A', destinationName: 'B'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('authentication failed'),
        ),
      ),
    );
  });

  test('429 blocks repeated requests and local quota is enforced', () async {
    var calls = 0;
    final budget = OjpRequestLimit(now: () => DateTime.utc(2026, 11, 3, 12));
    final client = OjpTripClient(
      readKey: () async => 'secret-v2',
      budget: budget,
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('', 429);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      client.search(query, originName: 'A', destinationName: 'B'),
      throwsFormatException,
    );
    await expectLater(
      client.search(query, originName: 'A', destinationName: 'B'),
      throwsFormatException,
    );
    expect(calls, 1);
  });

  test('no journeys is valid empty result', () async {
    final client = OjpTripClient(
      readKey: () async => 'secret-v2',
      httpClient: MockClient(
        (_) async => http.Response('<OJP><OJPResponse/></OJP>', 200),
      ),
    );
    addTearDown(client.dispose);
    final result = await client.search(
      query,
      originName: 'A',
      destinationName: 'B',
    );
    expect(result.journeys, isEmpty);
  });
}
