import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view_windows.dart';
import 'package:fpvmanager/features/home/home_screen.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/spots_screen.dart';

// Exercise the real Windows renderer and route lifecycle with a deterministic
// map-selection event. OS pointer injection is not supported by WidgetTester.
class _SelectionController extends GlobeController {
  String? session;
  int sequence = 0;

  @override
  void handleEvent(String message) {
    final event = jsonDecode(message) as Map<String, dynamic>;
    session = event['sessionId'] as String?;
    sequence = event['eventSequence'] as int? ?? sequence;
    super.handleEvent(message);
  }

  void selectPoint() => handleEvent(
    jsonEncode({
      'source': 'fpvmanager-globe',
      'version': 1,
      'sessionId': session,
      'eventSequence': sequence + 1,
      'type': 'point-selected',
      'latitude': 46.7,
      'longitude': 8.4,
      'altitude': 1000,
      'heightReference': 'wgs84Ellipsoid',
    }),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows places route survives a selected map point and repeated returns',
    (tester) async {
      final database = FpvDatabase(NativeDatabase.memory());
      final controller = _SelectionController();
      final spots = SpotRepository(database);
      await spots.createSpot(
        name: 'Windows route fixture',
        latitude: 46.7,
        longitude: 8.4,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: FPVHomeScreen(
            globeController: controller,
            spotRepository: spots,
            preferencesRepository: UserPreferencesRepository(database),
          ),
        ),
      );
      Future<void> until(bool Function() predicate) async {
        final clock = Stopwatch()..start();
        while (!predicate()) {
          expect(clock.elapsed, lessThan(const Duration(seconds: 60)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      try {
        await until(() => controller.isReady);
        expect(find.byType(GlobeViewWindows), findsOneWidget);
        final map = tester.element(find.byType(GlobeViewWindows));
        for (var attempt = 0; attempt < 3; attempt++) {
          debugPrint('Windows places: selecting point, cycle $attempt');
          controller.selectPoint();
          await tester.pump(const Duration(milliseconds: 100));
          await until(() => controller.selectedPoint != null);
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Gespeicherte Orte'));
          debugPrint('Windows places: opening list, cycle $attempt');
          await until(() => find.byType(SpotsScreen).evaluate().isNotEmpty);
          await until(
            () => find.text('Windows route fixture').evaluate().isNotEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          debugPrint('Windows places: returning to globe, cycle $attempt');
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.element(find.byType(GlobeViewWindows)), same(map));
          expect(controller.isReady, isTrue);
          expect(tester.takeException(), isNull);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        controller.dispose();
        await database.close();
      }
    },
    skip: kIsWeb || defaultTargetPlatform != TargetPlatform.windows,
  );
}
