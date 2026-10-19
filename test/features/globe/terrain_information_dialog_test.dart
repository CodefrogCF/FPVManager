import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/geo/reframe_wgs84_service.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/terrain_information_dialog.dart';

const terrain = TerrainElevation(
  latitude: 46.95108,
  longitude: 7.43863,
  elevation: ReferencedElevation(
    meters: 550,
    reference: VerticalReference.wgs84Ellipsoid,
  ),
  samplingMethod: 'most-detailed',
);
const swiss = SwissHeightResult(
  position: Lv95Coordinate(easting: 2599999.81, northing: 1199999.68),
  besselHeight: ReferencedElevation(
    meters: 500.3778,
    reference: VerticalReference.besselEllipsoid,
  ),
  ln02Height: ReferencedElevation(
    meters: 501.058,
    reference: VerticalReference.ln02,
  ),
);

Future<void> openDialog(
  WidgetTester tester, {
  TerrainElevation value = terrain,
  required SwissHeightConverter converter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TerrainInformationDialog(
                terrain: value,
                convertHeight: converter,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets(
    'ellipsoid, AMSL and AGL stay distinct and conversion is opt-in',
    (tester) async {
      var calls = 0;
      await openDialog(
        tester,
        converter: ({required coordinate, required elevation}) async {
          calls++;
          expect(coordinate.latitude, terrain.latitude);
          expect(coordinate.longitude, terrain.longitude);
          expect(elevation.reference, VerticalReference.wgs84Ellipsoid);
          expect(elevation.meters, 550);
          return swiss;
        },
      );
      expect(calls, 0);
      expect(
        textAt(tester, 'terrain-ellipsoid-height'),
        '550.0 m · WGS84 ellipsoid',
      );
      expect(find.text('AMSL (Swiss LN02): not converted'), findsOneWidget);
      expect(find.byKey(const ValueKey('agl-ellipsoid-height')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('agl-height-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agl-height-input')),
        '120,5',
      );
      await tester.pump();
      expect(
        textAt(tester, 'agl-ellipsoid-height'),
        '670.5 m · WGS84 ellipsoid',
      );
      expect(find.byKey(const ValueKey('agl-ln02-height')), findsNothing);
      await tester.ensureVisible(find.text('Convert to Swiss height (LN02)'));
      await tester.tap(find.text('Convert to Swiss height (LN02)'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        textAt(tester, 'terrain-ln02-height'),
        '501.1 m · AMSL (Swiss LN02)',
      );
      expect(textAt(tester, 'agl-ln02-height'), '621.6 m · AMSL (Swiss LN02)');
      expect(find.text('Converted with swisstopo REFRAME'), findsOneWidget);
      expect(find.text('Easting: 2599999.81 m'), findsOneWidget);
    },
  );

  testWidgets('invalid AGL entries never produce an altitude result', (
    tester,
  ) async {
    await openDialog(
      tester,
      converter: ({required coordinate, required elevation}) async => swiss,
    );
    final field = find.byKey(const ValueKey('agl-height-input'));
    await tester.ensureVisible(field);
    for (final input in ['-1', 'NaN', 'Infinity', 'invalid']) {
      await tester.enterText(field, input);
      await tester.pump();
      expect(
        find.text('Enter a finite height of 0 m or more.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('agl-ellipsoid-height')), findsNothing);
    }
    await tester.enterText(field, '0');
    await tester.pump();
    expect(textAt(tester, 'agl-ellipsoid-height'), '550.0 m · WGS84 ellipsoid');
  });

  testWidgets(
    'failed online conversion preserves the original and can be retried',
    (tester) async {
      var calls = 0;
      await openDialog(
        tester,
        converter: ({required coordinate, required elevation}) async {
          if (++calls == 1) throw StateError('Offline');
          return swiss;
        },
      );
      await tester.ensureVisible(find.text('Convert to Swiss height (LN02)'));
      await tester.tap(find.text('Convert to Swiss height (LN02)'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('height-conversion-error')),
        findsOneWidget,
      );
      expect(
        textAt(tester, 'terrain-ellipsoid-height'),
        '550.0 m · WGS84 ellipsoid',
      );
      expect(find.byKey(const ValueKey('terrain-ln02-height')), findsNothing);
      await tester.ensureVisible(find.text('Convert to Swiss height (LN02)'));
      await tester.tap(find.text('Convert to Swiss height (LN02)'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.byKey(const ValueKey('height-conversion-error')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('terrain-ln02-height')), findsOneWidget);
    },
  );

  testWidgets('outside the Swiss region no conversion is offered or called', (
    tester,
  ) async {
    await openDialog(
      tester,
      value: const TerrainElevation(
        latitude: 40,
        longitude: 8,
        elevation: ReferencedElevation(
          meters: 550,
          reference: VerticalReference.wgs84Ellipsoid,
        ),
        samplingMethod: 'level-12',
      ),
      converter: ({required coordinate, required elevation}) async {
        fail('Unexpected REFRAME request');
      },
    );
    expect(find.text('Convert to Swiss height (LN02)'), findsNothing);
    expect(find.byKey(const ValueKey('terrain-ln02-height')), findsNothing);
    expect(
      find.text(
        'LV95 conversion unavailable outside the supported Swiss region.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing a pending conversion ignores its later result', (
    tester,
  ) async {
    final pending = Completer<SwissHeightResult>();
    await openDialog(
      tester,
      converter: ({required coordinate, required elevation}) => pending.future,
    );
    await tester.ensureVisible(find.text('Convert to Swiss height (LN02)'));
    await tester.tap(find.text('Convert to Swiss height (LN02)'));
    await tester.pump();
    expect(find.text('Converting…'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    pending.complete(swiss);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TerrainInformationDialog), findsNothing);
  });

  testWidgets(
    'small displays and the keyboard keep dialog content scrollable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await openDialog(
        tester,
        converter: ({required coordinate, required elevation}) async => swiss,
      );
      final field = find.byKey(const ValueKey('agl-height-input'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '120');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Close'), findsOneWidget);
    },
  );
}
