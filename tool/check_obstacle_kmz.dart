import 'dart:io';

import 'package:fpvmanager/features/obstacles/kmz_obstacle_importer.dart';

/// Offline validation of a downloaded official full KMZ, without saving a cache.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/check_obstacle_kmz.dart <full.kmz>');
    exitCode = 64;
    return;
  }
  var vertices = 0;
  var progress = -1;
  final result = await const KmzObstacleImporter().import(
    await File(arguments.single).readAsBytes(),
    onProgress: (fraction) {
      final step = (fraction * 10).floor();
      if (step != progress) {
        progress = step;
        stdout.writeln('Import ${step * 10}%');
      }
    },
    onBatch: (batch) async {
      for (final f in batch) {
        for (final p in f.parts) {
          vertices += p.coordinates.length;
        }
      }
    },
  );
  stdout.writeln(
    '${result.count} objects, ${result.skipped} unsupported, $vertices vertices',
  );
  stdout.writeln(result.metadata);
}
