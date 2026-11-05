import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/geojson_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/core/osint/osint_dataset_store.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';

const _json = '{"type":"FeatureCollection","features":[],"fixture":true}';
final _source = OsintSource(
  id: 'http-fixture',
  name: 'HTTP fixture',
  publisher: 'Official fixture',
  attribution: '© fixture authority',
  dataUri: Uri.parse('https://example.invalid/uas.geojson'),
  metadataUri: Uri.parse('https://example.invalid/metadata'),
  coordinateReference: 'EPSG:4326',
);

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

class _MemoryStore implements OsintDatasetStore<Map<String, dynamic>> {
  OsintDataset<Map<String, dynamic>>? value;
  int writes = 0;

  @override
  Future<OsintDataset<Map<String, dynamic>>?> read(
    OsintSource source,
    DateTime now,
  ) async => value;

  @override
  Future<void> write(OsintDataset<Map<String, dynamic>> dataset) async {
    writes++;
    value = dataset;
  }

  @override
  Future<void> remove(String providerId) async {
    value = null;
  }

  @override
  Future<void> cleanup(DateTime now) async {}
}

void main() {
  test(
    'headers/body/parse are separate and conditional 304 reuses identical data',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(request.headers.containsKey('If-None-Match'), false);
          return http.Response(_json, 200, headers: {'etag': '"v1"'});
        }
        expect(request.headers['If-None-Match'], '"v1"');
        return http.Response('', 304);
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(source: _source, client: client);
      addTearDown(provider.dispose);
      final first = await provider.fetch();
      final firstMetrics = provider.lastDownloadMetrics!;
      expect(firstMetrics.httpStatusCode, 200);
      expect(firstMetrics.responseBytes, utf8.encode(_json).length);
      expect(firstMetrics.headersTime, greaterThanOrEqualTo(Duration.zero));
      expect(firstMetrics.bodyTime, greaterThanOrEqualTo(Duration.zero));
      expect(firstMetrics.parseTime, greaterThanOrEqualTo(Duration.zero));
      expect(firstMetrics.retryCount, 0);
      final second = await provider.fetch(forceRefresh: true);
      expect(calls, 2);
      expect(second.data, same(first.data));
      expect(second.fetchedAtUtc, first.fetchedAtUtc);
      expect(provider.lastDownloadMetrics!.usedNotModifiedResponse, true);
      expect(provider.lastDownloadMetrics!.responseBytes, 0);
      expect(provider.lastDownloadMetrics!.conditionalRequest, true);
    },
  );

  test(
    'a transparent gzip response must not compare decoded bytes to wire length',
    () async {
      final client = _StreamingClient(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode(_json)),
          200,
          headers: {'content-encoding': 'gzip', 'etag': '"compressed"'},
          contentLength: 12, // Mock of a native/browser *decoded* body stream.
        ),
      );
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(source: _source, client: client);
      addTearDown(provider.dispose);
      final data = await provider.fetch();
      expect(data.data['type'], 'FeatureCollection');
      expect(provider.lastDownloadMetrics!.declaredContentLength, 12);
      expect(provider.lastDownloadMetrics!.responseBytes, greaterThan(12));
      expect(provider.lastDownloadMetrics!.contentEncoding, 'gzip');
    },
  );

  test(
    'short identity response is invalid and cannot replace valid cached data',
    () async {
      var calls = 0;
      final client = _StreamingClient((_) async {
        calls++;
        if (calls == 1) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(_json)),
            200,
            contentLength: utf8.encode(_json).length,
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(_json)),
          200,
          contentLength: utf8.encode(_json).length + 10,
        );
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(source: _source, client: client);
      addTearDown(provider.dispose);
      final valid = await provider.fetch();
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.kind,
            'kind',
            OsintFailureKind.invalidData,
          ),
        ),
      );
      expect(provider.cached, same(valid));
      expect(provider.cached!.source.attribution, '© fixture authority');
      expect(provider.lastDownloadMetrics!.failure, 'invalid-data');
    },
  );

  test('explicit cancellation stops a hanging body and a subsequent fetch recovers', () async {
    final streamCancelled = Completer<void>();
    final started = Completer<void>();
    var calls = 0;
    final client = _StreamingClient((_) async {
      calls++;
      if (calls != 1) {
        return http.StreamedResponse(Stream.value(utf8.encode(_json)), 200);
      }
      final body = StreamController<List<int>>(
        onListen: () => started.complete(),
        onCancel: () => streamCancelled.complete(),
      );
      return http.StreamedResponse(body.stream, 200);
    });
    addTearDown(client.close);
    final provider = GeoJsonOsintProvider(source: _source, client: client);
    addTearDown(provider.dispose);
    final first = provider.fetch(forceRefresh: true);
    await started.future;
    expect(provider.isDownloading, true);
    provider.cancelPendingDownload();
    await expectLater(
      first,
      throwsA(
        isA<OsintProviderException>().having(
          (e) => e.kind,
          'kind',
          OsintFailureKind.cancelled,
        ),
      ),
    );
    await streamCancelled.future.timeout(const Duration(seconds: 1));
    expect(provider.isDownloading, false);
    final data = await provider.fetch();
    expect(data.data['type'], 'FeatureCollection');
    expect(calls, 2);
  });

  test(
    'timeout cancels a stalled stream without applying its partial response',
    () async {
      final cancelled = Completer<void>();
      final client = _StreamingClient((_) async {
        final body = StreamController<List<int>>(
          onCancel: () => cancelled.complete(),
        );
        return http.StreamedResponse(body.stream, 200, contentLength: 999);
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: _source,
        client: client,
        requestTimeout: const Duration(milliseconds: 25),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.fetch(),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.kind,
            'kind',
            OsintFailureKind.timeout,
          ),
        ),
      );
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(provider.cached, isNull);
      expect(provider.lastDownloadMetrics!.failure, 'timeout');
    },
  );

  test(
    'inactivity deadline cancels a stalled stream before total timeout',
    () async {
      final cancelled = Completer<void>();
      final client = _StreamingClient((_) async {
        final stream = StreamController<List<int>>(
          onListen: () {},
          onCancel: () => cancelled.complete(),
        );
        stream.add(utf8.encode('{"type":'));
        return http.StreamedResponse(stream.stream, 200);
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: _source,
        client: client,
        requestTimeout: const Duration(seconds: 2),
        bodyStallTimeout: const Duration(milliseconds: 35),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.kind,
            'kind',
            OsintFailureKind.timeout,
          ),
        ),
      );
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(provider.cached, isNull);
      expect(provider.lastDownloadMetrics!.failure, 'timeout');
    },
  );

  test('progressing stream succeeds beyond its stall interval', () async {
    final bytes = utf8.encode(_json);
    final client = _StreamingClient((_) async {
      final controller = StreamController<List<int>>();
      var offset = 0;
      Timer? timer;
      controller.onListen = () {
        timer = Timer.periodic(const Duration(milliseconds: 9), (t) {
          if (offset >= bytes.length) {
            t.cancel();
            controller.close();
          } else {
            final end = offset + 8 > bytes.length ? bytes.length : offset + 8;
            controller.add(bytes.sublist(offset, end));
            offset = end;
          }
        });
      };
      controller.onCancel = () {
        timer?.cancel();
      };
      return http.StreamedResponse(
        controller.stream,
        200,
        contentLength: bytes.length,
      );
    });
    addTearDown(client.close);
    final provider = GeoJsonOsintProvider(
      source: _source,
      client: client,
      requestTimeout: const Duration(seconds: 2),
      bodyStallTimeout: const Duration(milliseconds: 70),
    );
    addTearDown(provider.dispose);
    final result = await provider.fetch();
    expect(result.data['type'], 'FeatureCollection');
    expect(provider.lastDownloadMetrics!.responseBytes, bytes.length);
  });

  test(
    'coalesces simultaneous download requests and avoids implicit retries',
    () async {
      final firstResponse = Completer<http.StreamedResponse>();
      var calls = 0;
      final client = _StreamingClient((_) {
        calls++;
        return firstResponse.future;
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(source: _source, client: client);
      addTearDown(provider.dispose);
      final first = provider.fetch(forceRefresh: true);
      final second = provider.fetch(forceRefresh: true);
      expect(identical(first, second), true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      firstResponse.complete(
        http.StreamedResponse(Stream.value(utf8.encode(_json)), 200),
      );
      expect((await first).data, same((await second).data));
      expect(provider.lastDownloadMetrics!.retryCount, 0);
    },
  );

  test(
    'truncated refresh retains the disk-backed snapshot and provenance',
    () async {
      final memoryStore = _MemoryStore();
      var attempts = 0;
      final bytes = utf8.encode(_json);
      final client = _StreamingClient((_) async {
        attempts++;
        if (attempts == 1) {
          return http.StreamedResponse(
            Stream.value(bytes),
            200,
            contentLength: bytes.length,
          );
        }
        return http.StreamedResponse(
          Stream.value(bytes.sublist(0, 12)),
          200,
          contentLength: bytes.length,
        );
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(
        source: _source,
        client: client,
        persistentCache: memoryStore,
      );
      addTearDown(provider.dispose);
      final first = await provider.fetch(forceRefresh: true);
      expect(memoryStore.writes, 1);
      expect(memoryStore.value!.data, same(first.data));
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.kind,
            'kind',
            OsintFailureKind.invalidData,
          ),
        ),
      );
      expect(memoryStore.writes, 1);
      expect(memoryStore.value!.data, same(first.data));
      expect(memoryStore.value!.source.attribution, '© fixture authority');
    },
  );

  test(
    'invalid JSON and HTTP failure never remove the last good snapshot',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return switch (calls) {
          1 => http.Response(_json, 200),
          2 => http.Response('not JSON', 200),
          _ => http.Response('', 503),
        };
      });
      addTearDown(client.close);
      final provider = GeoJsonOsintProvider(source: _source, client: client);
      addTearDown(provider.dispose);
      final good = await provider.fetch();
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(isA<OsintProviderException>()),
      );
      expect(provider.cached, same(good));
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.httpStatus,
            'status',
            503,
          ),
        ),
      );
      expect(provider.cached, same(good));
      expect(calls, 3);
    },
  );
}
