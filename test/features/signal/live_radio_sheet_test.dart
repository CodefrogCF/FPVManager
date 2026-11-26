import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/signal/live_radio_sheet.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

void main() {
  testWidgets(
    'live radio configuration fits small and landscape screens and chooses a saved transmitter',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final spots = SpotRepository(db);
      await spots.createSpot(
        name: 'Hill transmitter',
        latitude: 47.1,
        longitude: 8.2,
      );
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showLiveRadioSettings(c, globe, spots: spots),
                child: const Text('Configure'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      final enabled = find.widgetWithText(
        SwitchListTile,
        'Enable live radio preview',
      );
      expect(tester.widget<SwitchListTile>(enabled).value, true);
      final origin = find.byType(DropdownButtonFormField<bool>);
      await tester.ensureVisible(origin);
      await tester.tap(origin);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixed spot / coordinates').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved spot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hill transmitter'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Latitude · WGS84'),
            )
            .controller!
            .text,
        '47.1',
      );
      for (final size in [
        const Size(800, 360),
        const Size(320, 480),
        const Size(320, 640),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final frequency = find.widgetWithText(
        TextField,
        'Frequency · MHz (10–100000)',
      );
      await tester.ensureVisible(frequency);
      await tester.enterText(frequency, '0');
      final apply = find.text('Apply radio preview');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(globe.liveRadio.settings.enabled, true);
      await tester.ensureVisible(frequency);
      await tester.enterText(frequency, '868');
      final antenna = find.widgetWithText(
        TextField,
        'Transmitter antenna · m AGL (0.1–100)',
      );
      await tester.ensureVisible(antenna);
      await tester.enterText(antenna, '3,5');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(globe.liveRadio.settings.enabled, true);
      expect(globe.liveRadio.settings.useSpawn, false);
      expect(globe.liveRadio.settings.signal.pilot.longitude, 8.2);
      expect(globe.liveRadio.settings.signal.frequencyMhz, 868);
      expect(globe.liveRadio.settings.signal.antennaHeight, 3.5);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('closing draft settings does not change the enabled preview', (
    tester,
  ) async {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showLiveRadioSettings(c, globe),
              child: const Text('Configure'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Enable live radio preview'),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(globe.liveRadio.settings.enabled, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'ground station marker and sightline options remain independently configurable',
    (tester) async {
      final globe = GlobeController();
      addTearDown(globe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLiveRadioSettings(context, globe),
                child: const Text('Configure'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      final marker = find.widgetWithText(
        SwitchListTile,
        'Show ground station marker',
      );
      final path = find.widgetWithText(
        SwitchListTile,
        'Show live line of sight',
      );
      expect(tester.widget<SwitchListTile>(marker).value, true);
      expect(tester.widget<SwitchListTile>(path).value, true);
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      await tester.ensureVisible(path);
      await tester.tap(path);
      await tester.pumpAndSettle();
      final apply = find.text('Apply radio preview');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(globe.liveRadio.settings.showGroundStationMarker, false);
      expect(globe.liveRadio.settings.showSignalPath, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('RF diagnostics are opt-in and fit a narrow settings sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final globe = GlobeController();
    addTearDown(globe.dispose);
    await globe.setDeveloperMenusEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLiveRadioSettings(context, globe),
              child: const Text('Configure'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Live RF diagnostics');
    await tester.ensureVisible(toggle);
    expect(globe.liveRadio.diagnosticsEnabled, false);
    expect(find.textContaining('Active/queued'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(globe.liveRadio.diagnosticsEnabled, true);
    expect(find.textContaining('Active/queued'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
