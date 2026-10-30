import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/navigation_location.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/mobility/road_navigation.dart';
import 'package:fpvmanager/features/mobility/road_navigation_screen.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

import '../../helpers/fake_globe_renderer.dart';
import 'road_navigation_test.dart' show exampleRoute;

class _Location implements NavigationLocationSource {
  final source = StreamController<NavigationFix>.broadcast(sync: true);
  @override
  Stream<NavigationFix> watch() => source.stream;
}

void main() {
  testWidgets(
    'navigation shows turn and progress, pauses on background, resumes, and releases native resources on exit',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      const channel = MethodChannel('com.codefrog.fpvmanager/road_navigation');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'speak' ? true : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final gps = _Location(),
          router = RoadRouter(),
          nav = RoadNavigation(
            route: exampleRoute(),
            router: router,
            locations: gps,
          );
      addTearDown(() async {
        nav.dispose();
        router.dispose();
        await gps.source.close();
      });
      FakeGlobeRenderer? peer;
      final settings = GlobeController();
      addTearDown(settings.dispose);
      await settings.setSceneEnvironment(buildings: true);
      await settings.setNavigationEnvironment(
        buildings: NavigationEnvironmentMode.disabled,
        vegetation: NavigationEnvironmentMode.enabled,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RoadNavigationScreen(
            settingsController: settings,
            navigation: nav,
            initialMapStyle: GlobeMapStyle.topographic,
            initialRoadsVisible: true,
            initialRoadsOpacity: .7,
            mapBuilder: (controller) {
              peer ??= FakeGlobeRenderer(controller)
                ..attach()
                ..ready();
              return const ColoredBox(color: Colors.grey);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        peer!.commands.where((c) => c['type'] == 'set-map-style').last['style'],
        'topographic',
      );
      expect(
        peer!.commands.where((c) => c['id'] == 'roads').last['opacity'],
        .7,
      );
      final environment = peer!.commands.lastWhere(
        (c) => c['type'] == 'set-navigation-environment',
      );
      expect(environment['buildings'], false);
      expect(environment['vegetation'], true);
      expect(environment['active'], true);
      expect(
        peer!.commands.lastWhere(
          (c) => c['type'] == 'set-road-navigation',
        )['active'],
        true,
      );
      nav.pause();
      await tester.pump();
      expect(
        peer!.commands.lastWhere(
          (c) => c['type'] == 'set-road-navigation',
        )['active'],
        false,
      );
      nav.start();
      // Stream cancellation can complete outside the widget test's fake clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(
        peer!.commands.lastWhere(
          (c) => c['type'] == 'set-road-navigation',
        )['active'],
        true,
      );
      expect(
        peer!.commands.lastWhere(
          (c) => c['type'] == 'set-scene-environment',
        )['buildings'],
        true,
      );
      await tester.tap(find.byTooltip('Kartendarstellung'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('navigation-roads-toggle')));
      await tester.pumpAndSettle();
      expect(
        peer!.commands.where((c) => c['id'] == 'roads').last['visible'],
        false,
      );
      await tester.tap(find.byTooltip('Kartendarstellung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3D-Umgebung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ein').first);
      await tester.pumpAndSettle();
      expect(settings.navigationBuildings, NavigationEnvironmentMode.enabled);
      expect(settings.buildings3dVisible, true);
      expect(settings.vegetation3dVisible, false);
      expect(
        peer!.commands.lastWhere(
          (c) => c['type'] == 'set-navigation-environment',
        )['buildings'],
        true,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        gps.source.hasListener,
        true,
        reason: 'GPS subscription after pause/resume',
      );
      gps.source.add(
        NavigationFix(
          point: MobilityPoint(47.0002, 8),
          accuracyMeters: 5,
          timeUtc: DateTime.now().toUtc(),
          speedMetersPerSecond: 10,
          headingDegrees: 90,
          headingAccuracyDegrees: 5,
        ),
      );
      await tester.pump();
      expect(
        nav.reliable,
        true,
        reason: 'GPS reliability: ${nav.error}; fix=${nav.fix?.timeUtc}',
      );
      expect(find.text('links abbiegen'), findsOneWidget);
      expect(find.text('36 km/h'), findsOneWidget);
      expect(find.textContaining('Ankunft'), findsOneWidget);
      Map<String, dynamic> camera() =>
          peer!.commands.lastWhere((c) => c['type'] == 'set-road-navigation');
      expect((camera()['position'] as Map)['heading'], 90);
      await tester.tap(find.byTooltip('Näher heranzoomen'));
      await tester.pump();
      expect(camera()['cameraDistanceMeters'], 400);
      expect(camera()['follow'], true);
      peer!.emit({'type': 'road-navigation-follow', 'follow': false});
      await tester.pump();
      expect(find.byTooltip('Standort folgen'), findsOneWidget);
      expect(find.byTooltip('Näher heranzoomen'), findsNothing);
      peer!.emit({'type': 'road-navigation-follow', 'follow': true});
      await tester.pump();
      gps.source.add(
        NavigationFix(
          point: MobilityPoint(47.0003, 8),
          accuracyMeters: 5,
          timeUtc: DateTime.now().toUtc(),
          speedMetersPerSecond: 10,
        ),
      );
      await tester.pump();
      expect(camera()['cameraDistanceMeters'], 400);
      expect(camera()['follow'], true);
      tester.view.physicalSize = const Size(900, 420);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        calls.any((c) => c.method == 'keepAwake' && c.arguments == true),
        isTrue,
      );
      await tester.tap(find.byTooltip('Offline-Sprachausgabe einschalten'));
      await tester.pump();
      expect(calls.any((c) => c.method == 'speak'), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(nav.active, isFalse);
      expect(gps.source.hasListener, isFalse);
      expect(
        calls.lastWhere((c) => c.method == 'keepAwake').arguments,
        isFalse,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(nav.active, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(gps.source.hasListener, isFalse);
      expect(calls.any((c) => c.method == 'stopVoice'), isTrue);
      expect(
        calls.lastWhere((c) => c.method == 'keepAwake').arguments,
        isFalse,
      );
    },
  );
}
