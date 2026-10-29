import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/road_route_comparison.dart';

import '../../helpers/route_traffic_fixtures.dart';
import '../../helpers/route_traffic_provider.dart';

void main() {
  for (final size in [const Size(360, 780), const Size(780, 360)]) {
    testWidgets(
      'alternatives remain selectable and wrap at $size with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = RouteTrafficProvider(
          trafficState({
            'records': [
              trafficEvent([trafficPart()]),
            ],
          }),
        );
        addTearDown(provider.dispose);
        final routes = [trafficRoute(), trafficRoute(lon: 8.001, seconds: 90)];
        var selected = routes.first, enabled = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.6),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: RoadRouteComparison(
                        routes: routes,
                        selected: selected,
                        enabled: enabled,
                        traffic: provider,
                        now: () => trafficTime,
                        onSelected: (r) => setState(() => selected = r),
                        onEnabled: (v) => setState(() => enabled = v),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // compute runs on a worker outside the fake widget clock.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        expect(
          selected,
          same(routes.first),
        ); // recommendation does not change selection
        expect(find.textContaining('Route 2 · Empfehlung'), findsOneWidget);
        await tester.ensureVisible(find.textContaining('Route 2 · Empfehlung'));
        await tester.tap(find.textContaining('Route 2 · Empfehlung'));
        await tester.pumpAndSettle();
        expect(selected, same(routes.last));
        provider.publish(
          trafficState({
            'records': [
              trafficEvent([trafficPart()]),
            ],
          }, failed: true),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('· Empfehlung'), findsNothing);
        expect(find.textContaining('Route 1 · OSRM-Basis'), findsOneWidget);
        await tester.ensureVisible(
          find.text('Datenstand und Bewertungsregeln'),
        );
        await tester.tap(find.text('Datenstand und Bewertungsregeln'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Aktualisierung fehlgeschlagen'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          const SizedBox.shrink(),
        ); // stops comparison timer
      },
    );
  }
}
