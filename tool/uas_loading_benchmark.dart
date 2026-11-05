// Local-only, reproducible synthetic transport benchmark for Issue #47.
// Usage: dart run tool/uas_loading_benchmark.dart [local_official.geojson]
// No upload or network access. It does NOT measure real WebView or Cesium time.
import 'dart:convert';
import 'dart:io';

import 'package:fpvmanager/features/globe/globe_bridge.dart';

Map<String, dynamic> exampleData() => {
  'type': 'FeatureCollection',
  'features': List.generate(4500, (index) {
    final longitude = 6.1 + (index % 90) * 0.018;
    final latitude = 46.1 + (index ~/ 90) * 0.009;
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [longitude, latitude],
            [longitude + 0.002, latitude],
            [longitude + 0.002, latitude + 0.001],
            [longitude, latitude + 0.001],
            [longitude, latitude],
          ],
        ],
      },
      'properties': {
        'identifier': 'synthetic-$index',
        'name': 'Fixture $index',
      },
    };
  }),
};

Future<void> runBridge(int chunkSize, Map<String, dynamic> collection) async {
  final bridge = GlobeBridge(
    options: GlobeBridgeOptions(
      chunkCharacters: chunkSize,
      datasetTimeout: const Duration(minutes: 3),
    ),
  );
  var sequence = 0;
  var emittedBytes = 0;
  final timer = Stopwatch()..start();
  bridge.attach((message) async {
    emittedBytes += utf8.encode(message).length;
    final frame = jsonDecode(message) as Map<String, dynamic>;
    if (frame['type'] == 'transfer-complete' ||
        frame['type'] == 'set-uas-zones') {
      bridge.receive(
        jsonEncode({
          'source': 'fpvmanager-globe',
          'version': 1,
          'sessionId': 'benchmark',
          'eventSequence': ++sequence,
          'type': 'command-result',
          'requestId': frame['requestId'],
          'commandType': 'set-uas-zones',
          'ok': true,
          'result': <String, dynamic>{},
        }),
      );
    }
  });
  bridge.receive(
    jsonEncode({
      'source': 'fpvmanager-globe',
      'version': 1,
      'sessionId': 'benchmark',
      'eventSequence': ++sequence,
      'type': 'globe-ready',
    }),
  );
  try {
    await bridge.send({
      'type': 'set-uas-zones',
      'visible': true,
      'sourceAttribution': 'benchmark only',
      'geojson': collection,
    }, timeout: const Duration(minutes: 3));
    timer.stop();
    final metrics = bridge.lastTransferMetrics!;
    stdout.writeln(
      'chunk=${chunkSize ~/ 1024} KiB; '
      'frames=${metrics.frameCount}; '
      'transport=${metrics.dispatchTime.inMilliseconds} ms; '
      'roundTrip=${timer.elapsed.inMilliseconds} ms; '
      'encoded=${metrics.characters} chars; '
      'on-wire=$emittedBytes bytes',
    );
  } finally {
    bridge.detach();
  }
}

Future<void> main(List<String> args) async {
  final Map<String, dynamic> dataset;
  if (args.isEmpty) {
    dataset = exampleData();
    stdout.writeln('Using synthetic geometries (not official restrictions).');
  } else {
    final file = File(args.first);
    if (!file.existsSync()) {
      stderr.writeln('GeoJSON file not found: ${file.path}');
      exitCode = 2;
      return;
    }
    final contents = await file.readAsString();
    final timer = Stopwatch()..start();
    final decoded = jsonDecode(contents);
    timer.stop();
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'FeatureCollection' ||
        decoded['features'] is! List) {
      stderr.writeln('Input must be a GeoJSON FeatureCollection.');
      exitCode = 2;
      return;
    }
    dataset = decoded;
    stdout.writeln('Local JSON parse: ${timer.elapsedMilliseconds} ms');
  }
  stdout.writeln('Features: ${(dataset['features'] as List).length}.');
  stdout.writeln(
    'Mock transport only: excludes HTTP, real WebViews and Cesium.',
  );
  for (final size in [32 * 1024, 96 * 1024]) {
    await runBridge(size, dataset);
  }
}
