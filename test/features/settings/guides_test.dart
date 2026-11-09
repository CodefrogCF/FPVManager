import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/features/help/guide_topics.dart';
import 'package:fpvmanager/features/simulation/simulation_settings_sheet.dart';

class Drones implements DroneRepository {
  @override
  Future<List<Drone>> getAllDrones() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('bundled guides cover required topics and retain honest source and simulation limits', () {
    expect(guideArticles.keys.toSet(), GuideTopic.values.toSet());
    expect(
      guideArticles[GuideTopic.airspace]!.sections.map((s) => s.text).join(),
      contains('keine Flugfreigabe'),
    );
    expect(
      guideArticles[GuideTopic.coordinates]!.sections.map((s) => s.text).join(),
      contains('unbekannt'),
    );
    expect(
      guideArticles[GuideTopic.offline]!.sections.map((s) => s.text).join(),
      contains('kein'),
    );
  });
  testWidgets(
    'contextual help returns to the unchanged simulation draft and configure-only does not spawn',
    (tester) async {
      Object? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showSimulationSettings(
                    context,
                    repository: Drones(),
                    hasSelection: false,
                    configureOnly: true,
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
      await tester.enterText(
        find.byKey(const ValueKey('simulation-agl')),
        '45',
      );
      await tester.ensureVisible(find.text('Hilfe & Hinweise'));
      await tester.tap(find.text('Hilfe & Hinweise'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Kurzhilfe: Steuerung und Simulation'),
      );
      await tester.tap(find.text('Kurzhilfe: Steuerung und Simulation'));
      await tester.pumpAndSettle();
      expect(find.text('Sticks'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('simulation-agl')))
            .controller!
            .text,
        '45',
      );
      expect(result, isNull);
      await tester.ensureVisible(find.text('Übernehmen'));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(find.text('Flug starten'), findsNothing);
    },
  );
}
