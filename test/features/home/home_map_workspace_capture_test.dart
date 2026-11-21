import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/home/home_map_workspace.dart';

void main() {
  testWidgets(
    'clean capture hides all Flutter overlays and keeps a restore hotspot',
    (tester) async {
      var restores = 0;
      Widget app(bool capture) => MaterialApp(
        home: Scaffold(
          body: HomeMapWorkspace(
            globe: const Text('3D globe'),
            navigation: const Text('Navigation menu'),
            actions: const Text('Map actions'),
            selection: const Text('Selection overlay'),
            sidePanel: const Text('Desktop panel'),
            captureMode: capture,
            onExitCapture: () => restores++,
          ),
        ),
      );
      await tester.pumpWidget(app(false));
      expect(find.text('Navigation menu'), findsOneWidget);
      expect(find.text('Map actions'), findsOneWidget);
      expect(find.text('Selection overlay'), findsOneWidget);
      expect(find.text('Desktop panel'), findsOneWidget);
      await tester.pumpWidget(app(true));
      expect(find.text('3D globe'), findsOneWidget);
      for (final text in [
        'Navigation menu',
        'Map actions',
        'Selection overlay',
        'Desktop panel',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(
        find.byKey(const ValueKey('capture-mode-restore-hotspot')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('capture-mode-restore-hotspot')),
      );
      expect(restores, 1);
    },
  );
}
