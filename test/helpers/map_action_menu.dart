import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Finder> openMapActionMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Map actions'));
  await tester.pumpAndSettle();
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  );
}

Future<void> selectMapAction(WidgetTester tester, String label) async {
  final item = await openMapActionMenu(tester, label);
  expect(tester.widget<PopupMenuItem<dynamic>>(item).enabled, isTrue);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> closeMapActionMenu(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
