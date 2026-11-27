import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/home/developer_benchmark.dart';
import 'package:fpvmanager/features/home/developer_performance_recording.dart';

void main() {
  test(
    'benchmark matrix isolates layers and radio; second pass reverses order',
    () {
      final cases = BenchmarkCase.matrix;
      expect(cases.length, 6);
      expect(cases.first.layers.values.every((value) => value), isTrue);
      expect(cases.first.rf, isTrue);
      for (final entry in [
        (cases[1], 'buildings'),
        (cases[2], 'structures'),
        (cases[3], 'vegetation'),
      ]) {
        expect(entry.$1.layers[entry.$2], isFalse);
        expect(entry.$1.layers.values.where((value) => !value).length, 1);
        expect(entry.$1.rf, isTrue);
      }
      expect(cases[4].layers.values.every((value) => !value), isTrue);
      expect(cases[5].layers, cases.first.layers);
      expect(cases[5].rf, isFalse);
      expect(BenchmarkCase.order(2).toList(), cases.reversed.toList());
    },
  );

  test('structure matrix changes one factor at a time and rotates repeats', () {
    final cases = BenchmarkCase.structureMatrix;
    expect(cases.length, 10);
    final reference = cases.first;
    expect(reference.structureTuning, {
      'sse': 24,
      'cacheMiB': 16,
      'bridgeSupports': true,
    });
    for (final variant in cases.skip(1)) {
      expect(variant.layers, reference.layers);
      expect(variant.rf, isTrue);
      expect(
        [
          variant.sse != reference.sse,
          variant.cacheMiB != reference.cacheMiB,
          variant.bridgeSupports != reference.bridgeSupports,
          variant.gpuTiming != reference.gpuTiming,
        ].where((changed) => changed).length,
        1,
      );
    }
    expect(
      BenchmarkCase.order(2, tuning: true).toList(),
      cases.reversed.toList(),
    );
    expect(BenchmarkCase.order(3, tuning: true).toSet(), cases.toSet());
    expect(BenchmarkCase.order(3, tuning: true).first, cases[5]);
  });

  test('benchmark summary uses quantiles of snapshots, not raw frames', () {
    expect(benchmarkPercentile([], .5), isNull);
    expect(benchmarkPercentile([40, 10, 30, 20], .5), 25);
    expect(benchmarkPercentile([10, 20, 30], .1), 12);
  });

  test('benchmark start diagnostics retain only known safe stages', () {
    expect(
      benchmarkStartFailureStage(
        StateError('Benchmark flight start failed: graphics'),
      ),
      'graphics',
    );
    expect(
      benchmarkStartFailureStage(
        StateError('Benchmark flight start failed: graphics private URL'),
      ),
      isNull,
    );
    expect(benchmarkStartFailureStage(StateError('network URL')), isNull);
    expect(benchmarkStartFailureStage(Exception('graphics')), isNull);
  });

  test('developer mode is required before any benchmark command', () async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    expect(globe.developerMenusEnabled, isFalse);
    expect(globe.beginBenchmark, throwsStateError);
    expect(globe.benchmarkActive, isFalse);
    await expectLater(
      globe.setBenchmarkLayers(BenchmarkCase.matrix.first.layers),
      throwsStateError,
    );
  });

  test(
    'automatic recording labels runs in JSON and CSV without route positions',
    () {
      final recording = DeveloperPerformanceRecording();
      final metadata = <String, Object?>{'kind': 'route-playback-benchmark'};
      recording.start(metadata: metadata);
      recording.add(
        {'renderFps': 30, 'latitude': 46.7},
        {
          'benchmarkCase': 'no-structures',
          'benchmarkRepetition': 1,
          'benchmarkRouteSha256': 'fixture-hash',
        },
      );
      metadata['status'] = 'completed';
      recording.stop();
      final document =
          jsonDecode(utf8.decode(recording.encode(csv: false))) as Map;
      expect(document['benchmark']['status'], 'completed');
      expect(document['samples'][0]['benchmarkCase'], 'no-structures');
      expect(document['samples'][0]['latitude'], isNull);
      expect(
        utf8.decode(recording.encode(csv: true)),
        contains('no-structures'),
      );
      recording.clear();
      recording.start();
      final manual =
          jsonDecode(utf8.decode(recording.encode(csv: false))) as Map;
      expect(manual.containsKey('benchmark'), isFalse);
    },
  );
}
