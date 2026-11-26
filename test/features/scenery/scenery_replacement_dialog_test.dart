import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_replacement_dialog.dart';
import 'package:fpvmanager/features/scenery/scenery_management_page.dart';
import 'package:fpvmanager/features/scenery/scenery_replacement.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

import '../../support/scenery_fixture.dart';

void main() {
  for (final copying in [false, true]) {
    testWidgets(
      copying
          ? 'template copies drop geographic replacement settings'
          : 'numeric placement edits disable saved replacement switches',
      (tester) async {
        final config = emptySceneryReplacement();
        config['buildings'] = {
          'enabled': true,
          'regions': [
            [
              [13.7999, 52.3999],
              [13.8001, 52.3999],
              [13.8001, 52.4001],
              [13.7999, 52.4001],
            ],
          ],
          'features': [],
        };
        final base = configureSceneryReplacement(sceneryFixture(), config);
        SceneryManifest? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: SceneryManagementPage(
              load: () async => copying ? [] : [base],
              templates: () async => [base],
              save: (m, _) async => saved = m,
              remove: (_) async {},
              german: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(copying ? 'New scenery' : 'Synthetic site'));
        await tester.pumpAndSettle();
        if (!copying) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('scenery-longitude')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('scenery-longitude')),
            '13.8002',
          );
        }
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);
        if (copying) {
          expect(saved!.toJson().containsKey('replacement'), false);
        } else {
          expect(saved!.toJson()['replacement']['buildings']['enabled'], false);
          expect(
            saved!.toJson()['replacement']['buildings']['regions'],
            config['buildings']['regions'],
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'replacement dialog configures independent masks and cancels without committing',
    (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => SceneryReplacementDialog(
                      existing: sceneryFixture(),
                      german: false,
                    ),
                  );
                },
                child: const Text('Configure'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 20 m region at anchor'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Replace base buildings'));
      await tester.tap(find.text('Replace base buildings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!['buildings']['enabled'], true);
      expect(result!['buildings']['regions'], hasLength(1));
      expect(result!['terrain']['enabled'], false);
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid region input retains the editable dialog and shows an error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryReplacementDialog(
            existing: sceneryFixture(),
            german: false,
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Building polygons'),
        '[[[0,0]]]',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3–64 vertices'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
