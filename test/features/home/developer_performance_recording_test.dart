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
}
