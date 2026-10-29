import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/tmc_repository.dart';
import 'package:fpvmanager/features/mobility/tmc_section.dart';
import 'package:fpvmanager/features/mobility/traffic_snapshot.dart';

import '../../helpers/tmc_fixture.dart';
import '../../helpers/route_traffic_fixtures.dart';
import '../../helpers/route_traffic_provider.dart';

void main() {
  for (final size in [const Size(360, 780), const Size(780, 360)]) {
    testWidgets(
      'TMC controls fit $size and follow the required version without silently selecting a newer table',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = RouteTrafficProvider(
          trafficState(parseTrafficSnapshot(tmcXml(version: '7.3'))),
        );
        final repo = TmcRepository();
        addTearDown(provider.dispose);
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.4),
                ),
                child: SingleChildScrollView(
                  child: TmcSection(repository: repo, provider: provider),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('TMC-Ortsdaten'));
        await tester.pumpAndSettle();
        expect(find.text('Tabelle 7.3 laden'), findsOneWidget);
        provider.publish(
          trafficState(parseTrafficSnapshot(tmcXml(version: '7.4'))),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tabelle 7.4 laden'), findsOneWidget);
        expect(find.byKey(const ValueKey('tmcVersion-7.4')), findsOneWidget);
        provider.publish(
          trafficState(parseTrafficSnapshot(tmcXml(version: '7.6'))),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Tabelle 7.6 laden'),
              )
              .onPressed,
          isNull,
        );
        final import = find.text('TMC-ZIP importieren');
        await tester.ensureVisible(import);
        expect(import, findsOneWidget);
        expect(find.textContaining('GeoPackage'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
