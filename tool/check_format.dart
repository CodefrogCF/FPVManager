import 'dart:io';

/// Run from the repository root. Generated Drift sources keep generator output.
void main() {
  final files = <String>[];
  for (final root in ['lib', 'test', 'tool', 'integration_test']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.endsWith('.dart') &&
          !path.endsWith('.g.dart') &&
          !path.startsWith('test/generated_migrations/')) {
        files.add(entity.path);
      }
    }
  }
  files.sort();

  final result = Process.runSync(Platform.resolvedExecutable, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...files,
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
