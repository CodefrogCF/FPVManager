// Local-only network diagnostic for issue #115. No dependencies, telemetry,
// proxies or uploads. Run via: dart run tool/benchmark_uas_http.dart
//
// The DNS/TCP/TLS connection probes are *separate* measurements, not a trace
// of the HTTP socket: HttpClient can reuse connections and hides these phases.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _dataset = Uri.https(
  'data.geo.admin.ch',
  '/ch.bazl.einschraenkungen-drohnen/einschraenkungen-drohnen/'
      'einschraenkungen-drohnen_4326.geojson',
);

Future<void> main(List<String> args) async {
  if (args.any((arg) => !const ['--identity', '--skip-probes'].contains(arg))) {
    stderr.writeln(
      'Usage: dart run tool/benchmark_uas_http.dart '
      '[--identity] [--skip-probes]',
    );
    exitCode = 64;
    return;
  }
  final compressed = !args.contains('--identity');
  final probes = !args.contains('--skip-probes');
  print('FPVManager #115 diagnostic (local only)');
  print('UTC: ${DateTime.now().toUtc().toIso8601String()}');
  print('Host: ${_dataset.host}; request: ${compressed ? "gzip" : "identity"}');
  print('Connection probes are independent of the following HTTP request.');
  if (probes) {
    try {
      final timer = Stopwatch()..start();
      final addresses = await InternetAddress.lookup(_dataset.host)
          .timeout(const Duration(seconds: 15));
      print(
        'dns_ms=${timer.elapsedMilliseconds} addresses=${addresses.length}',
      );
      if (addresses.isEmpty) throw StateError('DNS returned no addresses');
      timer.reset();
      final socket = await Socket.connect(
        addresses.first,
        443,
        timeout: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 15));
      print('tcp_probe_ms=${timer.elapsedMilliseconds}');
      timer.reset();
      final secure = await SecureSocket.secure(
        socket,
        host: _dataset.host,
      ).timeout(const Duration(seconds: 15));
      print('tls_probe_ms=${timer.elapsedMilliseconds}');
      secure.destroy();
    } catch (error) {
      print('connection_probe_failed=${error.runtimeType}');
    }
  }

  // Disable auto-uncompress ONLY for this diagnostic, to observe on-wire
  // bytes and measure decompression separately. Production uses the default
  // automatic gzip handling.
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);
  try {
    String? validator;
    for (var i = 0; i < 2; i++) {
      final timer = Stopwatch()..start();
      final request = await client.getUrl(_dataset);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/geo+json, application/json',
      );
      request.headers.set(
        HttpHeaders.acceptEncodingHeader,
        compressed ? 'gzip' : 'identity',
      );
      if (validator != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, validator);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 50),
      );
      final headersMs = timer.elapsedMilliseconds;
      final status = response.statusCode;
      final encoding = response.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      print(
        'run=${i + 1} status=$status headers_ms=$headersMs '
        'encoding=${encoding ?? "identity"} '
        'declared_wire_bytes=${response.contentLength}',
      );
      if (status == HttpStatus.notModified) {
        await response.drain<void>();
        print(
          'not_modified=true reused_previous_dataset=true '
          'total_ms=${timer.elapsedMilliseconds}',
        );
        continue;
      }
      if (status != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Unexpected HTTP $status');
      }
      final bytes = BytesBuilder(copy: false);
      const maxBytes = 60 * 1024 * 1024;
      await for (final chunk in response.timeout(const Duration(seconds: 50))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException(
            'Response exceeded diagnostic size limit',
          );
        }
        bytes.add(chunk);
      }
      final bodyMs = timer.elapsedMilliseconds - headersMs;
      if (response.contentLength >= 0 &&
          bytes.length != response.contentLength) {
        throw const FormatException('Incomplete wire response');
      }
      final wireBytes = bytes.length;
      final parseTimer = Stopwatch()..start();
      final decodedBytes = (encoding == 'gzip')
          ? gzip.decode(bytes.takeBytes())
          : bytes.takeBytes();
      if (decodedBytes.length > maxBytes) {
        throw const FormatException(
          'Decoded response exceeded diagnostic limit',
        );
      }
      final decoded = jsonDecode(utf8.decode(decodedBytes));
      if (decoded is! Map ||
          decoded['type'] != 'FeatureCollection' ||
          decoded['features'] is! List) {
        throw const FormatException('Invalid dataset GeoJSON');
      }
      final parseMs = parseTimer.elapsedMilliseconds;
      print(
        'wire_bytes=$wireBytes decoded_bytes=${decodedBytes.length} '
        'body_ms=$bodyMs decode_parse_ms=$parseMs '
        'total_ms=${timer.elapsedMilliseconds} '
        'feature_count=${(decoded['features'] as List).length} retries=0',
      );
      validator = response.headers.value(HttpHeaders.etagHeader);
      if (validator == null) {
        print('note=no-etag; second request will be a full download');
      }
    }
  } catch (error) {
    stderr.writeln('Diagnostic failed: ${error.runtimeType}');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
