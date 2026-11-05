import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_floating_surface.dart';
import 'package:fpvmanager/features/home/home_map_workspace.dart';
import 'package:fpvmanager/features/home/home_navigation_drawer.dart';
import 'package:fpvmanager/features/home/map_action_menu.dart';

void main() {
  testWidgets('non-modal map panel passes outside taps to the map', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var globeTaps = 0;
    var panelTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => globeTaps++,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: TextButton(
                    onPressed: () => showMapPanel<void>(
                      context,
                      nonModal: true,
                      builder: (panelContext) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => panelTaps++,
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(panelContext),
                              child: const Text('Close panel'),
                            ),
                            const Text('Windows map panel'),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('Open panel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    expect(find.text('Windows map panel'), findsOneWidget);
    final panel = tester.getRect(
      find.byKey(const ValueKey('floating-map-panel')),
    );
    expect(panel.left, greaterThan(500));

    await tester.tapAt(const Offset(450, 400));
    await tester.pump();
    expect(globeTaps, 1);

    await tester.tapAt(Offset(panel.center.dx, panel.center.dy));
    await tester.pump();
    expect(panelTaps, 1);
    expect(globeTaps, 1);

    await tester.tap(find.text('Close panel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('floating-map-panel')), findsNothing);
    await tester.tapAt(const Offset(450, 400));
    expect(globeTaps, 2);

    // Desktop sheets stay docked on the right even when resized to a narrow
    // portrait window, leaving a visible map strip on the left.
    tester.view.physicalSize = const Size(500, 720);
    await tester.pump();
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    final narrowPanel = tester.getRect(
      find.byKey(const ValueKey('floating-map-panel')),
    );
    expect(narrowPanel.width, lessThanOrEqualTo(360));
    expect(narrowPanel.left, greaterThan(70));
    await tester.tapAt(const Offset(40, 400));
    expect(globeTaps, 3);
    await tester.tap(find.text('Close panel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'desktop drawer is bounded at different sizes and keeps visible map interactive',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var mapTaps = 0;
      var mapDrags = 0;
      var panelTaps = 0;
      for (final size in [
        const Size(1280, 720),
        const Size(800, 500),
        const Size(430, 730),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeMapWorkspace(
                globe: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => mapTaps++,
                  onPanUpdate: (_) => mapDrags++,
                  child: const SizedBox.expand(),
                ),
                navigation: const SizedBox(width: 48, height: 48),
                actions: const SizedBox(width: 48, height: 48),
                selection: const SizedBox.shrink(),
                sidePanel: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => panelTaps++,
                  child: const ColoredBox(color: Colors.black26),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final panel = tester.getRect(
          find.byKey(const ValueKey('desktop-navigation-panel')),
        );
        expect(panel.left, 8);
        expect(panel.width, lessThanOrEqualTo(320));
        expect(panel.right, lessThan(size.width - 64));
        final oldMapTaps = mapTaps;
        final oldPanelTaps = panelTaps;
        await tester.tapAt(Offset(size.width - 20, size.height / 2));
        expect(mapTaps, oldMapTaps + 1);
        expect(panelTaps, oldPanelTaps);
        final beforeDrag = mapDrags;
        await tester.dragFrom(
          Offset(size.width - 20, size.height / 2),
          const Offset(-40, 0),
        );
        await tester.pump();
        expect(mapDrags, greaterThan(beforeDrag));
        await tester.tapAt(Offset(panel.center.dx, panel.center.dy));
        expect(panelTaps, oldPanelTaps + 1);
        expect(mapTaps, oldMapTaps + 1);
      }
    },
  );

  testWidgets('desktop navigation entries close only their bounded panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closes = 0;
    var opened = 0;
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeMapWorkspace(
            globe: const SizedBox.expand(),
            navigation: const SizedBox(width: 48, height: 48),
            actions: const SizedBox(width: 48, height: 48),
            selection: const SizedBox.shrink(),
            sidePanel: HomeNavigationDrawer(
              onClose: () => closes++,
              onSpots: () async {
                opened++;
              },
              onRoutes: noop,
              onWeather: noop,
              onDrones: noop,
              onBatteries: noop,
              onRadio: noop,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('FPV Spots'));
    await tester.pump();
    expect(closes, 1);
    expect(opened, 1);
    expect(find.byType(HomeMapWorkspace), findsOneWidget);
    await tester.tap(find.byTooltip('Close navigation menu'));
    expect(closes, 2);
  });

  testWidgets('desktop MapAnchor does not consume clicks outside its menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GlobeController();
    addTearDown(controller.dispose);
    var mapTaps = 0;
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => mapTaps++,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: MapActionMenu(
                  controller: controller,
                  desktopMenu: true,
                  compact: true,
                  groundButtonBuilder: () => const SizedBox.shrink(),
                  onHome: noop,
                  onCoordinates: noop,
                  onTerrain: noop,
                  onLayers: noop,
                  onWeather: noop,
                  onSimulation: noop,
                  onRecordingReview: noop,
                  onExitNavigation: noop,
                  onSettings: noop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Map actions'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuAnchor), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
    await tester.tapAt(const Offset(320, 400));
    await tester.pumpAndSettle();
    expect(mapTaps, 1);
    expect(find.text('Einstellungen'), findsNothing);
  });
}
