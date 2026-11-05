import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_bridge.dart';

void main() {
  late GlobeBridge bridge;
  late List<Map<String, dynamic>> frames;
  var sequence = 0;
  String envelope(Map<String, dynamic> data, {String session = 'page-1'}) =>
      jsonEncode({
        'source': 'fpvmanager-globe',
        'version': 1,
        'sessionId': session,
        'eventSequence': ++sequence,
        ...data,
      });
  void ready([String session = 'page-1']) =>
      bridge.receive(envelope({'type': 'globe-ready'}, session: session));
  void answer(
    Map<String, dynamic> command, {
    Map<String, dynamic> result = const {},
  }) => bridge.receive(
    envelope({
      'type': 'command-result',
      'commandType': command['type'],
      'requestId': command['requestId'],
      'ok': true,
      'result': result,
    }),
  );

  setUp(() {
    sequence = 0;
    frames = [];
    bridge = GlobeBridge(
      options: const GlobeBridgeOptions(
        commandTimeout: Duration(milliseconds: 100),
        transportTimeout: Duration(milliseconds: 30),
      ),
    );
    bridge.attach(
      (message) async =>
          frames.add(jsonDecode(message) as Map<String, dynamic>),
    );
    ready();
  });
  tearDown(() => bridge.detach());

  test(
    'concurrent commands finish only on their matching acknowledgements',
    () async {
      final first = bridge.send({'type': 'reset-camera'});
      final second = bridge.send({'type': 'fly-to'});
      final a = frames[0], b = frames[1];
      expect(a['requestId'], isNot(b['requestId']));
      answer(b, result: {'value': 2});
      expect(await second, {'value': 2});
      answer(a, result: {'value': 1});
      expect(await first, {'value': 1});
      answer(a); // Duplicate result cannot complete or affect a newer request.
    },
  );

  test(
    'wrong session, version, command type and malformed results are rejected',
    () async {
      final result = bridge.send({'type': 'reset-camera'});
      final command = frames.single;
      for (final override in [
        {'version': 2},
        {'commandType': 'fly-to'},
        {'ok': 'true'},
        {'result': 7},
      ]) {
        bridge.receive(
          envelope({
            'type': 'command-result',
            'commandType': 'reset-camera',
            'requestId': command['requestId'],
            'ok': true,
            'result': <String, dynamic>{},
            ...override,
          }),
        );
      }
      bridge.receive(
        envelope({
          'type': 'command-result',
          'commandType': 'reset-camera',
          'requestId': command['requestId'],
          'ok': true,
          'result': <String, dynamic>{},
        }, session: 'old-page'),
      );
      answer(command);
      expect(await result, isEmpty);
    },
  );

  test(
    'timeouts cancel the renderer request and late results are ignored',
    () async {
      final future = bridge.send({
        'type': 'reset-camera',
      }, timeout: const Duration(milliseconds: 10));
      final command = frames.single;
      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(frames.last['type'], 'cancel-command');
      answer(command);
    },
  );

  test('renderer errors propagate to the calling operation', () async {
    final future = bridge.send({'type': 'set-map-style'});
    final command = frames.single;
    final check = expectLater(future, throwsA(isA<StateError>()));
    bridge.receive(
      envelope({
        'type': 'command-result',
        'commandType': command['type'],
        'requestId': command['requestId'],
        'ok': false,
        'error': 'Unsupported style',
      }),
    );
    await check;
  });

  test(
    'reload cancels old requests and rejects old ready and status events',
    () async {
      final future = bridge.send({'type': 'reset-camera'});
      final check = expectLater(future, throwsStateError);
      ready('page-2');
      await check;
      expect(bridge.session, 'page-2');
      expect(bridge.receive(envelope({'type': 'globe-ready'})), isNull);
      expect(bridge.receive(envelope({'type': 'uas-zones-status'})), isNull);
      expect(bridge.session, 'page-2');
    },
  );

  test(
    'detach releases requests and ignores all subsequent renderer messages',
    () async {
      final future = bridge.send({'type': 'reset-camera'});
      final check = expectLater(future, throwsStateError);
      bridge.detach();
      await check;
      expect(bridge.receive(envelope({'type': 'globe-ready'})), isNull);
      await expectLater(
        bridge.send({'type': 'reset-camera'}),
        throwsStateError,
      );
    },
  );

  test('large commands use indexed, length-delimited chunks', () async {
    bridge.detach();
    bridge = GlobeBridge(
      options: const GlobeBridgeOptions(
        chunkCharacters: 128,
        maxCommandCharacters: 2048,
        maxFrameCharacters: 2048,
      ),
    );
    bridge.attach((message) async {
      final data = jsonDecode(message) as Map<String, dynamic>;
      frames.add(data);
      if (data['type'] == 'transfer-complete') {
        final start = frames.first;
        answer({'type': start['commandType'], 'requestId': start['requestId']});
      }
    });
    ready();
    await bridge.send({'type': 'set-spot-markers', 'data': 'é' * 500});
    expect(frames.first['type'], 'transfer-start');
    final chunks = frames
        .where((frame) => frame['type'] == 'transfer-chunk')
        .toList();
    expect(
      chunks.map((frame) => frame['index']),
      List.generate(chunks.length, (i) => i),
    );
    final joined = chunks.map((frame) => frame['data'] as String).join();
    expect(joined.length, frames.first['length']);
    expect((jsonDecode(joined) as Map)['data'], 'é' * 500);
    await expectLater(
      bridge.send({'type': 'large', 'data': 'x' * 2200}),
      throwsArgumentError,
    );
  });

  test(
    'transport failures and hung sends do not leave requests waiting',
    () async {
      bridge.attach((_) => Future<void>.error(StateError('Transport failed')));
      ready('page-error');
      await expectLater(
        bridge.send({'type': 'reset-camera'}),
        throwsStateError,
      );
      bridge.attach((_) => Completer<void>().future);
      ready('page-hung');
      await expectLater(
        bridge.send({'type': 'reset-camera'}),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'negotiated native gzip reduces frames without changing GeoJSON',
    () async {
      bridge.detach();
      final observed = <Map<String, dynamic>>[];
      bridge = GlobeBridge(
        options: const GlobeBridgeOptions(minCompressedCharacters: 1024),
      );
      bridge.attach((raw) async {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        observed.add(data);
        if (data['type'] == 'transfer-complete') {
          final start = observed.first;
          final chunks = observed.where(
            (event) => event['type'] == 'transfer-chunk',
          );
          final base64Payload = chunks
              .map((event) => event['data'] as String)
              .join();
          final original = utf8.decode(
            gzip.decode(base64Decode(base64Payload)),
          );
          final decoded = jsonDecode(original) as Map<String, dynamic>;
          expect(decoded['geojson'], isNotNull);
          expect(decoded['sourceAttribution'], 'Swiss authority / ©');
          expect(start['originalBytes'], utf8.encode(original).length);
          expect(start['originalLength'], original.length);
          answer({
            'type': start['commandType'],
            'requestId': start['requestId'],
          });
        }
      });
      bridge.receive(
        envelope({
          'type': 'globe-ready',
          'transport': {'gzipBase64': true},
        }),
      );
      final geojson = {
        'type': 'FeatureCollection',
        'features': List.generate(
          12000,
          (index) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [8.1, 47.1],
            },
            'properties': {'name': 'Swiss UAS $index'},
          },
        ),
      };
      await bridge.send({
        'type': 'set-uas-zones',
        'geojson': geojson,
        'sourceAttribution': 'Swiss authority / ©',
      });
      expect(observed.first['encoding'], 'gzip-base64');
      expect(bridge.lastTransferMetrics?.transport, 'gzip-base64');
      expect(bridge.lastTransferMetrics!.frameCount, lessThan(20));
      expect(
        bridge.lastTransferMetrics!.payloadCharacters,
        lessThan(bridge.lastTransferMetrics!.characters ~/ 2),
      );
    },
  );

  test(
    'no advertised support retains the legacy JSON frame protocol',
    () async {
      bridge.detach();
      final sent = <Map<String, dynamic>>[];
      bridge = GlobeBridge(
        options: const GlobeBridgeOptions(
          chunkCharacters: 1024,
          minCompressedCharacters: 1024,
        ),
      );
      bridge.attach((raw) async {
        final frame = jsonDecode(raw) as Map<String, dynamic>;
        sent.add(frame);
        if (frame['type'] == 'transfer-complete') {
          answer({'type': 'set-uas-zones', 'requestId': frame['requestId']});
        }
      });
      ready();
      await bridge.send({'type': 'set-uas-zones', 'data': '1234' * 2000});
      expect(sent.first['encoding'], isNull);
      expect(bridge.lastTransferMetrics?.transport, 'json');
    },
  );

  test('cancelling while compression runs does not emit late frames', () async {
    bridge.detach();
    final sent = <Map<String, dynamic>>[];
    bridge = GlobeBridge(
      options: const GlobeBridgeOptions(minCompressedCharacters: 1024),
    );
    bridge.attach(
      (raw) async => sent.add(jsonDecode(raw) as Map<String, dynamic>),
    );
    bridge.receive(
      envelope({
        'type': 'globe-ready',
        'transport': {'gzipBase64': true},
      }),
    );
    final future = bridge.send({
      'type': 'set-uas-zones',
      'data': 'A' * 2000000,
    });
    final expectFailure = expectLater(future, throwsStateError);
    bridge.detach();
    await expectFailure;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent.where((value) => value['type'] == 'transfer-start'), isEmpty);
  });

  test('transfer credit limits in-flight Web postMessage chunks', () async {
    bridge.detach();
    final sent = <Map<String, dynamic>>[];
    var inWindow = 0;
    bridge = GlobeBridge(
      options: const GlobeBridgeOptions(
        chunkCharacters: 256,
        maxFrameCharacters: 2048,
      ),
    );
    bridge.attach((raw) async {
      final frame = jsonDecode(raw) as Map<String, dynamic>;
      sent.add(frame);
      if (frame['type'] == 'transfer-chunk') {
        inWindow++;
        expect(inWindow, lessThanOrEqualTo(8));
        if (inWindow == 8) {
          inWindow = 0;
          bridge.receive(
            envelope({
              'type': 'transfer-credit',
              'requestId': frame['requestId'],
              'nextIndex': (frame['index'] as int) + 9,
            }),
          );
        }
      }
      if (frame['type'] == 'transfer-complete') {
        answer({'type': 'set-uas-zones', 'requestId': frame['requestId']});
      }
    });
    bridge.receive(
      envelope({
        'type': 'globe-ready',
        'transport': {'transferCredits': true},
      }),
    );
    await bridge.send({'type': 'set-uas-zones', 'data': 'x' * 20000});
    expect(sent.first['flowControl'], isTrue);
    expect(bridge.lastTransferMetrics!.transport, 'json');
  });

  test('rejects duplicate and oversize incoming events', () {
    final event = envelope({'type': 'point-selected'});
    expect(bridge.receive(event), isNotNull);
    expect(bridge.receive(event), isNull);
    expect(bridge.receive('x' * (128 * 1024 + 1)), isNull);
    expect(bridge.receive('[1,2,3]'), isNull);
    expect(bridge.receive('{'), isNull);
  });
  test('default UAS-sized frames are bounded after JSON escaping', () async {
    bridge.detach();
    final sent = <String>[];
    bridge = GlobeBridge();
    bridge.attach((raw) async {
      sent.add(raw);
      final frame = jsonDecode(raw) as Map<String, dynamic>;
      if (frame['type'] == 'transfer-complete') {
        bridge.receive(
          envelope({
            'type': 'command-result',
            'requestId': frame['requestId'],
            'commandType': 'set-uas-zones',
            'ok': true,
            'result': <String, dynamic>{},
          }),
        );
      }
    });
    ready('page-1');
    // Escaped punctuation, Unicode and JSON-special control characters.
    final difficult = List<String>.filled(30000, '"\n\t\\🎮').join();
    await bridge.send({'type': 'set-uas-zones', 'data': difficult});
    expect(sent.every((frame) => frame.length <= 128 * 1024), isTrue);
    final frames = sent.map((raw) => jsonDecode(raw) as Map<String, dynamic>);
    final pieces = frames
        .where((value) => value['type'] == 'transfer-chunk')
        .toList();
    expect(pieces.length, greaterThan(1));
    final combined = pieces.map((value) => value['data'] as String).join();
    expect((jsonDecode(combined) as Map)['data'], difficult);
    final metric = bridge.lastTransferMetrics!;
    expect(metric.frameCount, sent.length);
    expect(metric.dispatchTime, greaterThanOrEqualTo(Duration.zero));
    expect(metric.characters, greaterThan(150000));
  });
}
