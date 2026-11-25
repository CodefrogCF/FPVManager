import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_management_page.dart';
import 'package:fpvmanager/features/scenery/scenery_manifest.dart';

import '../../support/scenery_tileset_fixture.dart';

void main() {
  testWidgets(
    'editing a remote provider preserves other visual and collision assets',
    (tester) async {
      final doc = sceneryTilesetFixture().toJson();
      doc['assets'].add({
        'id': 'local',
        'role': 'visual',
        'provider': 'bundled',
        'format': 'glb',
        'uri': 'synthetic.glb',
      });
      doc['assets'].add({
        'id': 'walls',
        'role': 'collision',
        'provider': 'bundled',
        'format': 'fpc',
        'uri': 'synthetic.fpc',
      });
      doc['collision'] = {
        'enabled': true,
        'assetIds': ['walls'],
        'sidedness': 'double',
      };
      SceneryManifest? saved;
      final existing = SceneryManifest.fromJson(doc);
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [existing],
            templates: () async => [],
            save: (m, create) async {
              expect(create, false);
              saved = m;
            },
            remove: (_) async {},
            probeTileset: (_, _) async => tilesetMetadata(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic tileset'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tileset-save')));
      await tester.pumpAndSettle();
      expect(
        saved!.assets.map((a) => a.id),
        containsAll(['visual', 'local', 'walls']),
      );
      expect(saved!.toJson()['collision'], existing.toJson()['collision']);
    },
  );
  testWidgets(
    'new provider is validated before save and preserves default georeferencing',
    (tester) async {
      SceneryManifest? saved;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [],
            templates: () async => [],
            save: (m, create) async {
              expect(create, true);
              saved = m;
            },
            remove: (_) async {},
            probeTileset: (url, policy) async {
              calls++;
              expect(url, 'https://provider.example/root.json');
              expect(policy, 'no-store');
              return tilesetMetadata();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenery-add-tileset')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tileset-url')),
        'https://provider.example/root.json',
      );
      await tester.tap(find.byKey(const ValueKey('tileset-save')));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Check the current URL'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tileset-check')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.byKey(const ValueKey('tileset-save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.assets.single.tileset!['correction']['scale'], 1);
      expect(saved!.toJson()['anchor']['longitude'], 13.8);
      expect(saved!.toJson()['rotation']['headingDeg'], 0);
    },
  );
  testWidgets(
    'failed provider checks remain actionable and cancellation commits nothing',
    (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [],
            templates: () async => [],
            save: (_, _) async {
              saves++;
            },
            remove: (_) async {},
            probeTileset: (_, _) async => throw StateError(
              'NETWORK_OR_CORS: Check provider CORS permission',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenery-add-tileset')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tileset-url')),
        'https://provider.example/root.json',
      );
      await tester.tap(find.byKey(const ValueKey('tileset-check')));
      await tester.pumpAndSettle();
      expect(find.textContaining('NETWORK_OR_CORS'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    },
  );
  testWidgets(
    'changing the URL invalidates old validation; disposal ignores a late response',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SceneryManagementPage(
            german: false,
            load: () async => [sceneryTilesetFixture()],
            templates: () async => [],
            save: (_, _) async {
              saves++;
            },
            remove: (_) async {},
            probeTileset: (_, _) => pending.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic tileset'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tileset-url')),
        'https://provider.example/new.json',
      );
      await tester.tap(find.byKey(const ValueKey('tileset-save')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.tap(find.byKey(const ValueKey('tileset-check')));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      pending.complete(tilesetMetadata());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(saves, 0);
    },
  );
}
