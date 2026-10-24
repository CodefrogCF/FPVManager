import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/preflight/checklist.dart';
import 'package:fpvmanager/features/preflight/preflight_screen.dart';

void main() {
  testWidgets(
    'narrow screen creates a template and an unchecked independent checklist',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: PreflightScreen(database: db),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New template'));
      await tester.pumpAndSettle();
      expect(find.text('Checklist template'), findsOneWidget);
      await tester.tap(find.text('Save locally'));
      await tester.pumpAndSettle();
      final rows = await db.select(db.preflightChecklists).get();
      expect(rows.single.isTemplate, isTrue);
      expect(decodeChecklist(rows.single.itemsJson).length, 7);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start with all items unchecked'));
      await tester.pumpAndSettle();
      expect((await db.select(db.preflightChecklists).get()).length, 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Telemetry'));
      await tester.pumpAndSettle();
      expect(find.text('Import telemetry CSV'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
