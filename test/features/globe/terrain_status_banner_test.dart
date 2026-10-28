import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/globe/terrain_status_banner.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';
import 'package:drift/native.dart';

import '../../helpers/fake_globe_renderer.dart';
import '../../helpers/map_action_menu.dart';

void main() {
  testWidgets(
    'outage banner rebuilds, disables heights and retries without replacing the map',
    (tester) async {
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        MaterialApp(
          home: FPVHomeScreen(
            spotRepository: SpotRepository(database),
            preferencesRepository: UserPreferencesRepository(database),
          ),
        ),
      );
      final controller = tester
          .widget<GlobeView>(find.byType(GlobeView))
          .controller;
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      await tester.pumpAndSettle();
      final map = tester.element(find.byType(GlobeView));
      renderer.emit({
        'type': 'point-selected',
        'latitude': 46.7,
        'longitude': 8.4,
        'altitude': 500,
        'heightReference': 'wgs84Ellipsoid',
      });
      await tester.pump();
      var terrainAction = await openMapActionMenu(
        tester,
        'Query terrain elevation',
      );
      expect(
        tester.widget<PopupMenuItem<dynamic>>(terrainAction).enabled,
        isTrue,
      );
      await closeMapActionMenu(tester);
      renderer.emit({'type': 'terrain-resource-warning', 'active': true});
      await tester.pump();
      await tester.tap(find.byTooltip('Map status'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Loaded 3D terrain remains visible'),
        findsOneWidget,
      );
      expect(controller.terrainAvailable, isTrue);
      expect(tester.element(find.byType(GlobeView)), same(map));
      expect(controller.selectedPoint, isNotNull);
      await tester.tap(find.byTooltip('Close map status'));
      await tester.pumpAndSettle();
      renderer.emit({'type': 'terrain-resource-warning', 'active': false});
      await tester.pump();
      expect(
        find.textContaining('Loaded 3D terrain remains visible'),
        findsNothing,
      );
      renderer.emit({
        'type': 'terrain-status',
        'state': 'unavailable',
        'reason': 'tileFailed',
      });
      await tester.pump();
      await tester.tap(find.byTooltip('Map status'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3D terrain unavailable.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close map status'));
      await tester.pumpAndSettle();
      terrainAction = await openMapActionMenu(
        tester,
        'Query terrain elevation',
      );
      expect(
        tester.widget<PopupMenuItem<dynamic>>(terrainAction).enabled,
        isFalse,
      );
      await closeMapActionMenu(tester);
      expect(tester.element(find.byType(GlobeView)), same(map));
      renderer.autoAcknowledge = false;
      await tester.tap(find.byTooltip('Map status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry terrain'));
      await tester.pump();
      expect(renderer.commands.last['type'], 'retry-terrain');
      renderer.emit({
        'type': 'terrain-status',
        'state': 'loading',
        'reason': null,
      });
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry terrain'),
            )
            .onPressed,
        isNull,
      );
      renderer.emit({
        'type': 'terrain-status',
        'state': 'ready',
        'reason': null,
      });
      renderer.acknowledge(renderer.commands.last);
      await tester.pumpAndSettle();
      expect(find.text('Retry terrain'), findsNothing);
      expect(find.text('3D globe ready'), findsOneWidget);
      expect(tester.element(find.byType(GlobeView)), same(map));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'terrain message and retry remain reachable at 320 pixels and larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FpvDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: FPVHomeScreen(
            spotRepository: SpotRepository(database),
            preferencesRepository: UserPreferencesRepository(database),
          ),
        ),
      );
      final controller = tester
          .widget<GlobeView>(find.byType(GlobeView))
          .controller;
      final renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      renderer.emit({
        'type': 'terrain-status',
        'state': 'offline',
        'reason': 'networkOffline',
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Map status'));
      await tester.pumpAndSettle();
      expect(find.byType(TerrainStatusBanner), findsOneWidget);
      expect(find.textContaining('Offline: flat map'), findsOneWidget);
      expect(
        tester.getRect(find.text('Retry terrain')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
