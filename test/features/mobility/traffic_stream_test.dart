import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';

import 'mobility_test.dart' show datex;

Stream<List<int>> chunks(List<int> bytes, int size) async* {
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, (i + size).clamp(0, bytes.length));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('streamed national snapshot exceeds the former byte/record limits; failed replacement retains data and recovers', () async {
    final template = datex(comment: List.filled(1200, 'ä').join());
    final start = template.indexOf('<situationRecord '),
        end =
            template.indexOf('</situationRecord>') +
            '</situationRecord>'.length;
    final record = template.substring(start, end);
    final large =
        '${template.substring(0, start)}${List.generate(2400, (i) => record.replaceFirst('id="road-1"', 'id="road-$i"')).join()}${template.substring(end)}';
    final bytes = utf8.encode(large);
    expect(bytes.length, greaterThan(4 * 1024 * 1024));
    var invalid = false, now = DateTime.utc(2026, 10, 25);
    final provider = SituationalProvider(
      kind: SituationalKind.traffic,
      center: MobilityPoint(47, 8),
      readTrafficKey: () async => 'fixture-key',
      now: () => now,
      client: MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          chunks(invalid ? bytes.sublist(0, bytes.length - 30) : bytes, 16381),
          200,
        ),
      ),
    );
    addTearDown(provider.dispose);
    final first = await provider.fetch();
    expect(first.data['features'], hasLength(2400));
    expect(first.data['omitted'], 0);
    expect(first.data['publishedAtUtc'], '2026-10-24T10:00:00.000Z');
    expect(first.data['features'].first['detail'], contains('ääää'));
    invalid = true;
    now = now.add(const Duration(seconds: 16));
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(isA<OsintProviderException>()),
    );
    expect(identical(provider.cached, first), true);
    expect(provider.status.dataState, OsintDataState.refreshFailed);
    invalid = false;
    now = now.add(const Duration(seconds: 16));
    final recovered = await provider.fetch(forceRefresh: true);
    expect(recovered.data['features'], hasLength(2400));
    expect(provider.status.update, OsintUpdateState.ready);
  });
  test('split UTF8 and latest revocations normalize identically; unsafe or incomplete streams never yield a snapshot', () async {
    final input = datex(comment: 'Bauarbeiten Zürich');
    expect(
      await parseTrafficStream(chunks(utf8.encode(input), 1)),
      parseTrafficSnapshot(input),
    );
    for (final invalid in [
      '<!DOCTYPE x SYSTEM "https://example.invalid/external"><d2LogicalModel/>',
      '<!DOCTYPE x [<!ENTITY bomb "expanded">]><d2LogicalModel/>',
      '<soap><Fault>rejected</Fault></soap>',
      input.substring(0, input.length - 10),
      datex(comment: List.filled(256 * 1024, 'x').join()),
      '<d2LogicalModel>${List.filled(65, '<nested>').join()}',
    ]) {
      await expectLater(
        parseTrafficStream(chunks(utf8.encode(invalid), 137)),
        throwsA(isA<FormatException>()),
      );
    }
    final revoked = datex(comment: 'Aufgehoben: Bauarbeiten')
        .replaceFirst('09:59:00Z', '10:00:00Z');
    final a = revoked.indexOf('<situationRecord '),
        b = revoked.indexOf('</situationRecord>') + '</situationRecord>'.length;
    final merged = input.replaceFirst(
      '<situation>',
      '<situation>${revoked.substring(a, b)}',
    );
    expect(
      (await parseTrafficStream(chunks(utf8.encode(merged), 31)))['features'],
      isEmpty,
    );
  });
  test('transport rejects declared and chunked oversize responses and keeps smaller defaults for other APIs', () async {
    for (final declared in [true, false]) {
      var bytesRead = 0;
      Stream<List<int>> body() async* {
        final chunk = List.filled(65536, 32);
        for (var i = 0; i < 520; i++) {
          bytesRead += chunk.length;
          yield chunk;
        }
      }

      final transport = MobilityHttp(
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            body(),
            200,
            contentLength: declared ? trafficMaxResponseBytes + 1 : null,
          ),
        ),
      );
      addTearDown(transport.dispose);
      await expectLater(
        transport.read(
          Uri.https('example.invalid', '/'),
          maxBytes: trafficMaxResponseBytes,
          consume: (stream) => stream.drain<void>(),
        ),
        throwsFormatException,
      );
      expect(bytesRead, declared ? 0 : trafficMaxResponseBytes + 65536);
    }
    final other = MobilityHttp(
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          const Stream.empty(),
          200,
          contentLength: 4 * 1024 * 1024 + 1,
        ),
      ),
    );
    addTearDown(other.dispose);
    await expectLater(
      other.text(Uri.https('example.invalid', '/')),
      throwsFormatException,
    );
  });
  test('an incomplete XML token stops the transfer well before the snapshot byte limit', () async {
    var received = 0;
    Stream<List<int>> source() async* {
      yield utf8.encode('<d2LogicalModel attribute="');
      for (var i = 0; i < 64; i++) {
        received += 16384;
        yield List.filled(16384, 65);
      }
    }

    await expectLater(parseTrafficStream(source()), throwsFormatException);
    expect(received, lessThan(300 * 1024));
  });
  test('excessive record counts are rejected without publishing a partial dataset', () async {
    final input =
        '<d2LogicalModel>${List.filled(20001, '<situationRecord id="same"/>').join()}</d2LogicalModel>';
    await expectLater(
      parseTrafficStream(chunks(utf8.encode(input), 16384)),
      throwsFormatException,
    );
  });
}
