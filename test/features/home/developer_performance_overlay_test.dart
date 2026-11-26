import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/home/developer_performance_overlay.dart';

void main() {
  testWidgets(
    'overlay reports observed FPS and missing/stale metrics honestly',
    (tester) async {
      final samples = ValueNotifier<Map<String, dynamic>?>(null);
      addTearDown(samples.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeveloperPerformanceOverlay(samples: samples)),
        ),
      );
      expect(find.textContaining('Waiting for renderer'), findsOneWidget);
      samples.value = {
        'renderFps': 29.8,
        'frameAgeMs': 20,
        'framePacingMs': {'p95': 44.0},
        'cpuRenderMs': {'p50': 5.0, 'p95': 12.0},
        'flightPhysics': {
          'stepHz': 120,
          'model': 'advanced',
          'droppedSeconds': 0.25,
        },
        'rf': {'quality': 'valid', 'durationMs': 101},
        'terrainState': 'ready',
        'pendingTerrainTiles': 8,
      };
      await tester.pump();
      expect(find.textContaining('FPS 29.8'), findsOneWidget);
      expect(find.textContaining('GPU —/—'), findsOneWidget);
      expect(find.textContaining('drop 0.250 s'), findsOneWidget);
      expect(find.textContaining('pending 8'), findsOneWidget);
      samples.value = {...samples.value!, 'frameAgeMs': 5000};
      await tester.pump();
      expect(find.textContaining('FPS —'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
