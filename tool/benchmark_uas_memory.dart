// Local-only memory benchmark. No network, telemetry, or external services.
//
// dart run tool/benchmark_uas_memory.dart --runs=5 --features=1256
// dart run tool/benchmark_uas_memory.dart --file=C:\\path\\to\\uas.geojson --runs=5
// Add --worker to measure native Isolate.run parsing, not browser workers.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fpvmanager/features/airspace/uas_dataset_assessment.dart';

Map<String, dynamic> _syntheticCollection(int count) => {
  'type': 'FeatureCollection',
  'sourceAttribution': 'Synthetic; no official airspace data',
  'features': List.generate(count, (i) {
    final x = 6.0 + (i % 100) * .02;
    final y = 46.0 + (i ~/ 100) * .02;
    final outer = [
      [x, y],
      [x + .015, y],
      [x + .015, y + .015],
      [x, y + .015],
      [x, y],
    ];
    final hole = [
      [x + .004, y + .004],
      [x + .008, y + .004],
      [x + .008, y + .008],
      [x + .004, y + .004],
    ];
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'MultiPolygon',
        'coordinates': [
          [outer, hole],
        ],
      },
      'properties': {
        'identifier': 'synthetic-$i',
        'restriction': 'REQ_AUTHORISATION',
        'permanent': 'YES',
        'upperLimit': 120,
        'lowerLimit': 0,
        'name': 'Synthetic zone $i',
      },
    };
  }),
};

Map<String, dynamic> _parse(Uint8List bytes) {
  final parsed = jsonDecode(utf8.decode(bytes));
  if (parsed is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return parsed;
}

int _rss() => ProcessInfo.currentRss;

Future<void> main(List<String> args) async {
  var runs = 5;
  var count = 1256;
  String? file;
  var worker = false;
  for (final arg in args) {
    if (arg.startsWith('--runs=')) {
      runs = int.parse(arg.substring('--runs='.length));
    } else if (arg.startsWith('--features=')) {
      count = int.parse(arg.substring('--features='.length));
    } else if (arg.startsWith('--file=')) {
      file = arg.substring('--file='.length);
    } else if (arg == '--worker') {
      worker = true;
    } else {
      stderr.writeln(
        'Usage: dart run tool/benchmark_uas_memory.dart '
        '[--file=local.geojson] [--features=1256] [--runs=5] [--worker]',
      );
      exitCode = 64;
      return;
    }
  }
  if (runs < 1 || runs > 20 || count < 1 || count > 100000) {
    stderr.writeln('Supported ranges: runs 1..20, features 1..100000.');
    exitCode = 64;
    return;
  }
  if (file != null && !File(file).existsSync()) {
    stderr.writeln('Local GeoJSON does not exist: $file');
    exitCode = 66;
    return;
  }
  // Keep fixture creation outside measurement. The same byte buffer is parsed
  // independently for each iteration; no mutation or geometry simplification.
  final bytes = file == null
      ? Uint8List.fromList(utf8.encode(jsonEncode(_syntheticCollection(count))))
      : await File(file).readAsBytes();
  if (bytes.length > 64 * 1024 * 1024) {
    stderr.writeln('Input exceeds 64 MiB safety limit.');
    exitCode = 65;
    return;
  }
  stdout.writeln(
    'FPVManager local memory benchmark; source=${file ?? "synthetic"}; '
    'bytes=${bytes.length}; runs=$runs; worker=$worker',
  );
  stdout.writeln(
    'rss_before/after are point-in-time process samples, NOT peak '
    'heap size; use DevTools Memory for GC and allocation profiling.',
  );
  for (var run = 1; run <= runs; run++) {
    final before = _rss();
    final parse = Stopwatch()..start();
    final data = worker
        ? await Isolate.run(() => _parse(bytes))
        : _parse(bytes);
    parse.stop();
    final afterParse = _rss();
    final assess = Stopwatch()..start();
    final assessment = UasDatasetAssessment.inspect(data);
    assess.stop();
    final afterAssess = _rss();
    final encode = Stopwatch()..start();
    final text = jsonEncode(assessment.geoJson);
    encode.stop();
    final afterEncode = _rss();
    if (assessment.renderedFeatureCount < 1 || text.isEmpty) {
      throw const FormatException('Benchmark data did not survive validation');
    }
    stdout.writeln(
      'run=$run parse_ms=${parse.elapsedMilliseconds} '
      'assess_ms=${assess.elapsedMilliseconds} '
      'encode_ms=${encode.elapsedMilliseconds} '
      'features=${assessment.renderedFeatureCount} '
      'skipped=${assessment.skippedFeatureCount} '
      'reuse_source=${identical(assessment.geoJson, data)} '
      'rss_before=$before rss_after_parse=$afterParse '
      'rss_after_assessment=$afterAssess rss_after_encode=$afterEncode',
    );
  }
}
