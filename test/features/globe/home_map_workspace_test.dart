import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/globe/globe_page_path.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test('floating chrome composes with offline/cache URLs without changing other maps', () {
    expect(globePagePath(), 'globe.html');
    expect(
      globePagePath(cachedMaps: true, floatingControls: true),
      'globe.html?cachedMaps=1&chrome=floating',
    );
    expect(
      globePagePath(offline: true, cachedMaps: true, floatingControls: true),
      'globe.html?offline=1&chrome=floating',
    );
  });
  testWidgets(
    'full-size globe survives selection, portrait/landscape rotation, panels and large text',
    (tester) async {
      if (const bool.fromEnvironment('UI_CAPTURE')) {
        await tester.runAsync(() async {
          final font = const String.fromEnvironment('UI_FONT_PATH');
          if (font.isNotEmpty) {
            final bytes = ByteData.sublistView(await File(font).readAsBytes());
            for (final family in ['Roboto', 'Ahem']) {
              await (FontLoader(family)..addFont(Future.value(bytes))).load();
            }
          }
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final spots = SpotRepository(database);
      final id = await spots.createSpot(
        name: 'Mountain ridge launch point',
        latitude: 46.7,
        longitude: 8.4,
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: FPVHomeScreen(
              spotRepository: spots,
              flightPlanRepository: FlightPlanRepository(database),
              preferencesRepository: UserPreferencesRepository(database),
            ),
          ),
        ),
      );
      final globe = tester.element(find.byType(GlobeView));
      final peer =
          FakeGlobeRenderer(
              tester.widget<GlobeView>(find.byType(GlobeView)).controller,
            )
            ..attach()
            ..ready();
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(GlobeView)), const Size(360, 800));
      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).floatingControls,
        true,
      );
      peer.emit({'type': 'spot-selected', 'id': id});
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(GlobeView)), const Size(360, 800));
      for (final size in [
        const Size(360, 800),
        const Size(800, 360),
        const Size(320, 480),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(GlobeView)), same(globe));
        expect(tester.getSize(find.byType(GlobeView)), size);
        final selection = tester.getRect(
          find.byKey(const ValueKey('map-selection-overlay')),
        );
        expect(selection.right, lessThanOrEqualTo(size.width));
        expect(selection.bottom, lessThanOrEqualTo(size.height - 50));
        expect(find.text('Fly to Spot').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('More spot actions'));
        await tester.pumpAndSettle();
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Check airspace'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        if (size.width > size.height) {
          expect(selection.left, greaterThan(size.width / 2));
          expect(selection.top, greaterThanOrEqualTo(120));
        }
        if (const bool.fromEnvironment('UI_CAPTURE')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '.dart_tool/ui-${size.width.toInt()}x${size.height.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byTooltip('Map layers'));
        await tester.pumpAndSettle();
        expect(find.byType(MapLayersSheet), findsOneWidget);
        final panel = tester.getRect(
          find.byKey(const ValueKey('floating-map-panel')),
        );
        if (size.width > size.height) {
          expect(panel.left, greaterThan(size.width / 2));
        }
        expect(panel.bottom, lessThanOrEqualTo(size.height - 12));
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
