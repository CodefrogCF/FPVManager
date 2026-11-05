import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/uas_map_layers_section.dart';

void main() {
  testWidgets(
    'airspace panel retains source and safety information without performance diagnostics',
    (tester) async {
      final controller = GlobeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UasMapLayersSection(controller: controller),
            ),
          ),
        ),
      );

      expect(find.text('AIRSPACE'), findsOneWidget);
      expect(find.text('DATA SOURCE'), findsOneWidget);
      expect(find.text('Loaded features'), findsOneWidget);
      expect(find.text('Coverage'), findsOneWidget);
      expect(find.text('Cache status'), findsOneWidget);
      expect(find.text('Official validity'), findsOneWidget);
      expect(find.text('LOCAL PERFORMANCE DIAGNOSTICS'), findsNothing);
      expect(find.text('Bridge frames'), findsNothing);
      expect(find.text('Bridge round trip'), findsNothing);
      expect(find.text('Renderer JSON decode'), findsNothing);
      expect(find.text('HTTP transfer'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
