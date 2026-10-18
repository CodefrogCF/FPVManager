import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/main.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';

void main() {
  testWidgets('FPVManager displays the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FPVManagerApp());

    expect(find.text('FPVManager'), findsOneWidget);

    expect(find.byType(GlobeView), findsOneWidget);

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
