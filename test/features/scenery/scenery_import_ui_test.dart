import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_management_page.dart';

import '../../support/scenery_model_fixture.dart';

void main() {
  testWidgets(
    'model placement commits only after save and preserves metadata',
    (tester) async {
      final model = (await tester.runAsync(prepareTriangle))!;
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [],
            templates: () async => [],
            save: (_, _) async {},
            remove: (_) async {},
            pickImport: () async => ('triangle.gltf', model),
            importModel: (manifest, prepared) async {
              commits++;
              expect(prepared.key, model.key);
              expect(manifest.name, 'triangle');
              expect(manifest.toJson()['anchor']['longitude'], 13.8);
              expect(manifest.assets.single.model, model.metadata);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenery-import')));
      await tester.pumpAndSettle();
      expect(find.text('Place model'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('scenery-longitude')),
        '13.8',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(commits, 1);
    },
  );
  testWidgets(
    'cancelled file selection or placement never commits local files',
    (tester) async {
      final model = (await tester.runAsync(prepareTriangle))!;
      var selected = false, commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [],
            templates: () async => [],
            save: (_, _) async {},
            remove: (_) async {},
            pickImport: () async => selected ? ('triangle.glb', model) : null,
            importModel: (_, _) async {
              commits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenery-import')));
      await tester.pumpAndSettle();
      expect(commits, 0);
      selected = true;
      await tester.tap(find.byKey(const ValueKey('scenery-import')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(commits, 0);
    },
  );
  testWidgets('unsupported import error leaves the picker available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneryManagementPage(
          german: true,
          load: () async => [],
          templates: () async => [],
          save: (_, _) async {},
          remove: (_) async {},
          pickImport: () async => throw const FormatException(
            'Unsupported extension: KHR_draco_mesh_compression',
          ),
          importModel: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scenery-import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('KHR_draco_mesh_compression'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('scenery-import')))
          .onPressed,
      isNotNull,
    );
  });
}
