import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Explicit, local-only recording of bounded profiler snapshots. No positions,
/// source URLs, raw provider errors or credentials are retained.
class DeveloperPerformanceRecording {
  static const maxSamples = 600;
  final _samples = <Map<String, Object?>>[];
  bool active = false;
  int get count => _samples.length;
  DateTime? _started;
  Map<String, Object?>? _metadata;

  void start({Map<String, Object?>? metadata}) {
    _metadata = metadata;
    _samples.clear();
    _started = DateTime.now().toUtc();
    active = true;
  }

  void stop() => active = false;

  void clear() {
    stop();
    _samples.clear();
    _started = null;
    _metadata = null;
  }

  void add(Map<String, dynamic> snapshot, Map<String, Object?> settings) {
    if (!active) return;
    final row = <String, Object?>{
      'elapsedMs': DateTime.now().toUtc().difference(_started!).inMilliseconds,
      ...settings,
    };
    void flatten(String prefix, Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          if (const {'id', 'errorDetail', 'loadSamples'}.contains(key)) {
            continue;
          }
          flatten('$prefix.$key', entry.value);
        }
      } else if (value is num && value.isFinite || value is bool) {
        row[prefix] = value;
      } else if (value is String &&
          const {
            'renderer.vendor',
            'renderer.renderer',
            'renderer.chromiumVersion',
            'terrainProvider',
            'terrainState',
            'flightPhysics.model',
            'rf.quality',
            'rf.provider',
            'rf.error',
            'layerStats.buildings.state',
            'layerStats.vegetation.state',
            'layerStats.structures.state',
          }.contains(prefix)) {
        row[prefix] = value.length <= 200 ? value : value.substring(0, 200);
      }
    }

    for (final key in const [
      'renderFps',
      'frameAgeMs',
      'continuous',
      'frames',
      'framePacingMs',
      'cpuRenderMs',
      'gpuRenderMs',
      'cpuUpdateMs',
      'cpuSceneMs',
      'animationCadence',
      'canvas',
      'renderer',
      'physicsStep',
      'flightPhysics',
      'terrainProvider',
      'terrainState',
      'terrainStreaming',
      'terrainRequests',
      'pendingTerrainTiles',
      'terrainWarning',
      'renderSamples',
      'intervalSamples',
      'layerStats',
      'tilesets',
      'scenery',
      'rf',
      'over33Ms',
      'over100Ms',
    ]) {
      flatten(key, snapshot[key]);
    }
    _samples.add(row);
    if (count >= maxSamples) stop();
  }

  Uint8List encode({required bool csv}) {
    if (!csv) {
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'application': 'FPVManager',
            'startedUtc': _started?.toIso8601String(),
            if (_metadata != null) 'benchmark': _metadata,
            'samples': _samples,
          }),
        ),
      );
    }
    final columns = _samples.expand((row) => row.keys).toSet().toList();
    String cell(Object? value) {
      var s = value?.toString() ?? '';
      // Treat strings as data, not spreadsheet formulas.
      if (value is String && RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    return Uint8List.fromList(
      utf8.encode(
        [
          columns.map(cell).join(','),
          for (final row in _samples)
            columns.map((key) => cell(row[key])).join(','),
        ].join('\r\n'),
      ),
    );
  }

  Future<bool> save({required bool csv}) async {
    final bytes = encode(csv: csv);
    if (bytes.length > 4 * 1024 * 1024) {
      throw StateError('Diagnostic export exceeds 4 MiB');
    }
    final name =
        'fpv-performance-${_started!.millisecondsSinceEpoch}.${csv ? 'csv' : 'json'}';
    final mime = csv ? 'text/csv' : 'application/json';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await const MethodChannel('com.codefrog.fpvmanager/route_files')
              .invokeMethod<bool>('savePerformance', {
                'name': name,
                'mimeType': mime,
                'bytes': bytes,
              }) ??
          false;
    }
    final file = XFile.fromData(bytes, name: name, mimeType: mime);
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }
}
