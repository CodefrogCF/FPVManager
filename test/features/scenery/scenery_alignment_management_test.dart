import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_management_page.dart';

import '../../support/scenery_fixture.dart';

void main() {
  testWidgets(
    'alignment closes management after start; a rejected start keeps an actionable error',
    (tester) async {
      String? selected;
      bool? result;
      var reject = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SceneryManagementPage(
                        load: () async => [sceneryFixture()],
                        templates: () async => [],
                        save: (_, _) async {},
                        remove: (_) async {},
                        german: false,
                        align: (id) async {
                          selected = id;
                          if (reject) throw StateError('Stop navigation first');
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Manage'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Align on globe'));
      await tester.pumpAndSettle();
      expect(selected, 'synthetic-site');
      expect(result, true);
      expect(find.byType(SceneryManagementPage), findsNothing);
      reject = true;
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select and align on globe'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.byType(SceneryManagementPage), findsOneWidget);
      expect(find.textContaining('Stop navigation first'), findsOneWidget);
    },
  );
}
