import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_collision_dialog.dart';
import 'package:fpvmanager/features/scenery/scenery_collision_import.dart';

import '../../support/scenery_collision_fixture.dart';
import '../../support/scenery_fixture.dart';

void main() {
  late PreparedSceneryCollision mesh;
  setUpAll(() async {
    mesh = await collisionRoom().collider();
  });
  testWidgets(
    'generation adds an independent mesh and confirms sidedness without changing source metadata',
    (tester) async {
      SceneryCollisionSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<SceneryCollisionSelection>(
                    context: context,
                    builder: (_) => SceneryCollisionDialog(
                      existing: sceneryFixture(),
                      german: false,
                      generate: (_, _) async => mesh,
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
      await tester.ensureVisible(find.text('Generate from visual model'));
      await tester.tap(find.text('Generate from visual model'));
      await tester.pumpAndSettle();
      expect(find.textContaining(mesh.key), findsOneWidget);
      await tester.ensureVisible(find.text('Double sided'));
      await tester.tap(find.text('Double sided'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front (triangle normals)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.$2.single.key, mesh.key);
      expect(result!.$1.toJson()['collision']['sidedness'], 'front');
      expect(result!.$1.toJson()['collision']['assetIds'], hasLength(2));
      expect(
        result!.$1.toJson()['source'],
        sceneryFixture().toJson()['source'],
      );
    },
  );
  testWidgets(
    'cancel discards pending geometry and ignores late generation completion',
    (tester) async {
      final gate = Completer<PreparedSceneryCollision>();
      SceneryCollisionSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<SceneryCollisionSelection>(
                    context: context,
                    builder: (_) => SceneryCollisionDialog(
                      existing: sceneryFixture(),
                      german: false,
                      generate: (_, _) => gate.future,
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
      await tester.ensureVisible(find.text('Generate from visual model'));
      await tester.tap(find.text('Generate from visual model'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      gate.complete(mesh);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
