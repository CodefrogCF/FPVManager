import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/features/globe/globe_input_scope.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/main.dart';

void main() {
  testWidgets('home drawer suspends globe input and preserves the map widget', (
    tester,
  ) async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      MaterialApp(
        home: FPVHomeScreen(
          spotRepository: SpotRepository(db),
          preferencesRepository: UserPreferencesRepository(db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final map = tester.element(find.byType(GlobeView));
    expect(
      tester.widget<GlobeInputScope>(find.byType(GlobeInputScope)).enabled,
      isTrue,
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlobeInputScope>(find.byType(GlobeInputScope)).enabled,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlobeInputScope>(find.byType(GlobeInputScope)).enabled,
      isTrue,
    );
    expect(tester.element(find.byType(GlobeView)), same(map));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
