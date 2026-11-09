import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/main.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';

void main() {
  testWidgets('FPVManager displays the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FPVManagerApp());

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'FPVManager',
    );
    expect(find.byType(FPVHomeScreen), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.byTooltip('Map status'), findsOneWidget);
    expect(find.byTooltip('Kartenaktionen'), findsOneWidget);
    expect(find.byType(GlobeView), findsOneWidget);

    expect(find.byType(Scaffold), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('FPVManager'), findsOneWidget);
    expect(find.text('Gespeicherte Orte'), findsOneWidget);
    expect(find.text('Flugrouten'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
