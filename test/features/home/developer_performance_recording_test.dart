import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/home/developer_performance_recording.dart';

void main() {
  test('recording is explicit, bounded and exports only selected metrics', () {
    final recording = DeveloperPerformanceRecording();
    final sample = <String, dynamic>{
      'renderFps': 60,
      'rf': {'errorDetail': 'private URL', 'samples': 27},
      'layerStats': {
        'buildings': {'pending': 4},
      },
      'mainThreadLongTasks': {'supported': true, 'count': 2},
      'sceneCommands': {'count': 15},
      'bridgeSupports': {'groundHits': 5, 'groundMisses': 1},
      'bridgeCommands': {'completed': 3},
      'sceneTileLoading': {'queued': 4},
      'terrainRequests': {
        'render': {'rootCacheHits': 2},
      },
      'latitude': 52,
      'renderer': {'renderer': '=formula'},
    };
    recording.add(sample, {});
    expect(recording.count, 0);
    recording.start();
    for (var i = 0; i <= DeveloperPerformanceRecording.maxSamples; i++) {
      recording.add(sample, {});
    }
    expect(recording.active, isFalse);
    expect(recording.count, DeveloperPerformanceRecording.maxSamples);
    final json = utf8.decode(recording.encode(csv: false));
    expect(json, contains('layerStats.buildings.pending'));
    expect(json, contains('mainThreadLongTasks.count'));
    expect(json, contains('bridgeSupports.groundHits'));
    expect(json, contains('bridgeCommands.completed'));
    expect(json, contains('sceneCommands.count'));
    expect(json, contains('sceneTileLoading.queued'));
    expect(json, contains('terrainRequests.render.rootCacheHits'));
    expect(json, isNot(contains('private URL')));
    expect(json, isNot(contains('latitude')));
    expect(utf8.decode(recording.encode(csv: true)), contains("'=formula"));
    recording.clear();
    expect(recording.count, 0);
  });

  test('benchmark limit is independent of manual recording', () {
    final recording = DeveloperPerformanceRecording(
      sampleLimit: DeveloperPerformanceRecording.maxBenchmarkSamples,
    );
    recording.start();
    for (var i = 0; i < 1501; i++) {
      recording.add(
        {
          'bridgeSupports': {'deckHits': 4, 'benchmarkSuppressed': false},
          'gpuRenderMs': {'enabled': false},
          'layerStats': {
            'structures': {
              'memoryAdjustedScreenSpaceError': 40,
              'headerBytes': 8,
            },
          },
        },
        {'benchmarkStructuresSse': 24},
      );
    }
    expect(recording.count, 1500);
    expect(recording.active, isFalse);
    expect(DeveloperPerformanceRecording().sampleLimit, 600);
    final csv = utf8.decode(recording.encode(csv: true));
    expect(csv, contains('bridgeSupports.deckHits'));
    expect(csv, contains('gpuRenderMs.enabled'));
    expect(
      csv,
      contains('layerStats.structures.memoryAdjustedScreenSpaceError'),
    );
  });

  test('large benchmark exports remain within the performance byte limit', () {
    final recording = DeveloperPerformanceRecording(
      sampleLimit: DeveloperPerformanceRecording.maxBenchmarkSamples,
    );
    recording.start();
    final snapshot = <String, dynamic>{
      'layerStats': {
        'structures': {
          for (var i = 0; i < 100; i++)
            'syntheticLongDiagnosticMetricForExportSize$i': 12345.6789,
        },
      },
    };
    for (var i = 0; i < 1500; i++) {
      recording.add(snapshot, {'benchmarkRun': i ~/ 27 + 1});
    }
    final bytes = recording.encodeForExport(csv: false);
    expect(bytes.length, greaterThan(4 * 1024 * 1024));
    expect(
      bytes.length,
      lessThanOrEqualTo(DeveloperPerformanceRecording.maxExportBytes),
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(decoded['samples'], hasLength(1500));
    expect(recording.encodeForExport(csv: true), isNotEmpty);
  });

  test('oversized performance export is still rejected', () {
    final recording = DeveloperPerformanceRecording();
    recording.start();
    recording.add({}, {
      'syntheticOversizedMetadata': ''.padRight(
        DeveloperPerformanceRecording.maxExportBytes + 1,
        'x',
      ),
    });
    expect(() => recording.encodeForExport(csv: false), throwsStateError);
  });
}
