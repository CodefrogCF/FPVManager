import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/offline/base_map_cache_preference.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets('FPVManager displays the home screen', (
    WidgetTester tester,
  ) async {
    final database = FpvDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await BaseMapCachePreference(database).write(true);
    await tester.pumpWidget(
      FPVManagerApp(preferencesRepository: UserPreferencesRepository(database)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'FPVManager',
    );
    expect(find.byType(FPVHomeScreen), findsOneWidget);
    expect(find.byTooltip('Navigationsmenü öffnen'), findsOneWidget);
    expect(find.byTooltip('Kartenstatus'), findsOneWidget);
    expect(find.byTooltip('Kartenaktionen'), findsOneWidget);
    expect(find.byType(GlobeView), findsOneWidget);
    expect(tester.widget<GlobeView>(find.byType(GlobeView)).cachedMaps, isTrue);

    expect(find.byType(Scaffold), findsOneWidget);
    await tester.tap(find.byTooltip('Navigationsmenü öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('FPVManager'), findsOneWidget);
    expect(find.text('Gespeicherte Orte'), findsOneWidget);
    expect(find.text('Flugrouten'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
