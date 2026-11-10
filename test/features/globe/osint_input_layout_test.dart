import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/theme/app_theme.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_floating_surface.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_section.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_sites_section.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_section.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final section in ['mobile', 'prevention', 'imagery']) {
        testWidgets(
          'OSINT $section first expansion at width $width, text $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final globe = GlobeController();
            addTearDown(globe.dispose);
            final child = switch (section) {
              'mobile' => MobileSitesSection(globe: globe),
              'prevention' => WildfirePreventionSection(globe: globe),
              _ => DatedImagerySection(globe: globe),
            };
            final title = switch (section) {
              'mobile' => 'BAKOM Mobilfunk-Basisstationen',
              'prevention' => 'Kantonale Waldbrand-Präventionsmassnahmen',
              _ => 'Datierte Satelliten- & Rapid-Mapping-Bilder',
            };
            final fields = switch (section) {
              'mobile' => ['mobile_sites_lat', 'mobile_sites_lon'],
              'prevention' => ['fire_prevention_lat', 'fire_prevention_lon'],
              _ => ['dated_lat', 'dated_lon'],
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showMapPanel<void>(
                        context,
                        nonModal: false,
                        builder: (_) => MapLayersSheet(
                          controller: globe,
                          initialTab: MapLayerTab.situational,
                          situationalControls: child,
                        ),
                      ),
                      child: const Text('Open map settings'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open map settings'));
            await tester.pumpAndSettle();
            await tester.tap(find.text(title));
            for (final duration in [
              Duration.zero,
              const Duration(milliseconds: 16),
              const Duration(milliseconds: 80),
              const Duration(milliseconds: 200),
            ]) {
              await tester.pump(duration);
              expect(tester.takeException(), isNull);
              expect(find.byType(ErrorWidget), findsNothing);
            }
            for (final key in fields) {
              final field = find.byKey(ValueKey(key));
              expect(tester.getSize(field).height, lessThan(125));
              expect(tester.getSize(field).width, greaterThan(80));
            }
            final latitude = find.byKey(ValueKey(fields.first));
            await tester.ensureVisible(latitude);
            await tester.enterText(latitude, '46.7');
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text(title));
            await tester.tap(find.text(title));
            await tester.pumpAndSettle();
            await tester.tap(find.text(title));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
            expect(tester.widget<TextField>(latitude).controller!.text, '46.7');
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
