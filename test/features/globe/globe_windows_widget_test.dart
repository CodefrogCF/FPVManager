import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view.dart';

void main() {
  testWidgets('Windows widget tests do not start native WebView2', (
    tester,
  ) async {
    if (!Platform.isWindows) return;

    final controller = GlobeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GlobeView(controller: controller)),
      ),
    );

    // A native WebView loading indicator would animate indefinitely in the
    // widget-test runner and make pumpAndSettle() time out.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
