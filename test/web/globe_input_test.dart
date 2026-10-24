@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:fpvmanager/core/database/fpv_database.dart' show Drone;
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_input_scope.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings_sheet.dart';

class _Drones implements DroneRepository {
  @override
  Future<List<Drone>> getAllDrones() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<web.HTMLIFrameElement> iframe(WidgetTester tester) async {
  // Creating a real HTML platform view uses the browser's event loop, outside
  // the widget test's fake clock. Wait for that response before inspecting it.
  final surfaces = find.byType(PlatformViewSurface);
  for (
    var attempt = 0;
    attempt < 20 && surfaces.evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(surfaces, findsOneWidget);
  final surface = tester.widget<PlatformViewSurface>(surfaces);
  return ui_web.platformViewRegistry.getViewById(surface.controller.viewId)
      as web.HTMLIFrameElement;
}

void main() {
  setUp(() {
    // Widget tests normally ignore engine messages. These tests need the real
    // DOM iframe, while retaining the test font, semantics and URL settings.
    final previous = ui_web.TestEnvironment.instance;
    ui_web.TestEnvironment.setUp(
      ui_web.TestEnvironment(
        forceTestFonts: previous.forceTestFonts,
        disableFontFallbacks: previous.disableFontFallbacks,
        keepSemanticsDisabledOnUpdate: previous.keepSemanticsDisabledOnUpdate,
        defaultToTestUrlStrategy: previous.defaultToTestUrlStrategy,
      ),
    );
    addTearDown(() => ui_web.TestEnvironment.setUp(previous));
  });
  testWidgets(
    'spawn settings and nested dropdown block DOM iframe input without reloading it',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                actions: [
                  TextButton(
                    onPressed: () => showSimulationSettings(
                      context,
                      repository: _Drones(),
                      hasSelection: true,
                    ),
                    child: const Text('Spawn to fly'),
                  ),
                ],
              ),
              body: GlobeView(controller: globe, offline: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frame = await iframe(tester);
      final source = frame.src;
      expect(frame.style.pointerEvents, 'auto');
      expect(frame.tabIndex, 0);
      await tester.tap(find.text('Spawn to fly'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'none');
      expect(frame.tabIndex, -1);
      await tester.tap(
        find.byType(DropdownButtonFormField<SimulationFlightMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acro · Mode 2, rate control').last);
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'none');
      await tester.enterText(
        find.byKey(const ValueKey('simulation-agl')),
        '45',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('simulation-agl')))
            .controller!
            .text,
        '45',
      );
      await tester.tap(find.byTooltip('Close simulation settings'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'auto');
      expect(frame.tabIndex, 0);
      expect(await iframe(tester), same(frame));
      expect(frame.src, source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'popup menu, dialog and drawer restore iframe input after closing',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(MaterialApp(home: _OverlayHarness(globe: globe)));
      await tester.pumpAndSettle();
      final frame = await iframe(tester);
      await tester.tap(find.byTooltip('Map actions'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'none');
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'none');
      await tester.tap(find.text('Close dialog'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'auto');
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'none');
      await tester.tap(find.text('Close drawer'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'auto');
      expect(await iframe(tester), same(frame));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a globe created under an existing modal starts with input disabled',
    (tester) async {
      final globe = GlobeController(), visible = ValueNotifier(false);
      addTearDown(globe.dispose);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                actions: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Dialog'),
                  ),
                ],
              ),
              body: ValueListenableBuilder(
                valueListenable: visible,
                builder: (_, shown, _) => shown
                    ? GlobeView(controller: globe, offline: true)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      visible.value = true;
      await tester.pumpAndSettle();
      final frame = await iframe(tester);
      expect(frame.style.pointerEvents, 'none');
      expect(frame.tabIndex, -1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(frame.style.pointerEvents, 'auto');
      expect(await iframe(tester), same(frame));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

class _OverlayHarness extends StatefulWidget {
  const _OverlayHarness({required this.globe});
  final GlobeController globe;
  @override
  State<_OverlayHarness> createState() => _OverlayHarnessState();
}

class _OverlayHarnessState extends State<_OverlayHarness> {
  bool _drawer = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    onDrawerChanged: (value) => setState(() => _drawer = value),
    drawer: Drawer(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close drawer'),
        ),
      ),
    ),
    appBar: AppBar(
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Map actions',
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'dialog', child: Text('Open dialog')),
          ],
          onSelected: (_) => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close dialog'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    body: GlobeInputScope(
      enabled: !_drawer,
      child: GlobeView(controller: widget.globe, offline: true),
    ),
  );
}
