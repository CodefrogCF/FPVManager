import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_management_page.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

import '../../support/scenery_fixture.dart';

void main() {
  testWidgets(
    'cancelled edit leaves stored scenery unchanged; confirmed edit persists',
    (tester) async {
      var stored = sceneryFixture();
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [stored],
            templates: () async => [sceneryFixture()],
            save: (SceneryManifest m, bool create) async {
              expect(create, false);
              stored = m;
              saves++;
            },
            remove: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic site'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scenery-name')),
        'Edited',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(stored.name, 'Synthetic site');
      await tester.tap(find.text('Synthetic site'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scenery-name')),
        'Edited',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(stored.name, 'Edited');
    },
  );
  testWidgets(
    'new definition reuses attribution but starts disabled without replacement patches',
    (tester) async {
      SceneryManifest? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [],
            templates: () async => [sceneryFixture()],
            save: (m, create) async {
              expect(create, true);
              saved = m;
            },
            remove: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New scenery'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scenery-name')),
        'New site',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'New site');
      expect(saved?.enabled, false);
      expect(saved?.toJson()['source'], sceneryFixture().toJson()['source']);
      expect((saved?.toJson()['collision'] as Map)['enabled'], false);
    },
  );
  testWidgets('removal requires confirmation and refreshes the list', (
    tester,
  ) async {
    final items = [sceneryFixture()];
    var removes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SceneryManagementPage(
          german: false,
          load: () async => List.of(items),
          templates: () async => [sceneryFixture()],
          save: (_, _) async {},
          remove: (id) async {
            removes++;
            items.removeWhere((m) => m.id == id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removes, 0);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removes, 1);
    expect(find.text('Synthetic site'), findsNothing);
  });
}
