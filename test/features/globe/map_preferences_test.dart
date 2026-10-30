import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/airspace/data/swiss_uas_provider.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/map_layers_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_globe_renderer.dart';

class ControlledPreferences implements UserPreferencesRepository {
  ControlledPreferences(this.delegate);
  final UserPreferencesRepository delegate;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool failReads = false;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<UserPreferences> getPreferences() async {
    await readGate?.future;
    if (failReads) throw StateError('Synthetic read failure');
    return delegate.getPreferences();
  }

  @override
  Future<void> savePreferences(UserPreferences preferences) async {
    writes++;
    await writeGate?.future;
    if (failWrites) throw StateError('Synthetic write failure');
    await delegate.savePreferences(preferences);
  }

  @override
  Future<void> resetPreferences() => delegate.resetPreferences();
  @override
  Stream<UserPreferences> watchPreferences() => delegate.watchPreferences();
}

void main() {
  late FpvDatabase database;
  late UserPreferencesRepository repository;
  late ControlledPreferences controlled;
  late GlobeController controller;
  late FakeGlobeRenderer renderer;
  late MockClient client;

  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = UserPreferencesRepository(database);
    controlled = ControlledPreferences(repository);
    client = MockClient(
      (_) async =>
          http.Response('{"type":"FeatureCollection","features":[]}', 200),
    );
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
  });

  tearDown(() async {
    controller.dispose();
    client.close();
    await controller.preferencesSettled;
    await database.close();
  });

  test('touch visibility persists, renderer quick settings save locally and reload restores the requested value', () async {
    await controller.initializePreferences(repository);
    await controller.setTouchControlsVisible(false);
    expect((await repository.getPreferences()).touchControlsVisible, false);
    renderer.sessionId = 'touch-reload';
    renderer.sequence = 0;
    renderer.emit({'type': 'renderer-loading'});
    renderer.ready();
    await Future<void>.delayed(Duration.zero);
    expect(
      renderer.commands
          .where((c) => c['type'] == 'set-touch-controls')
          .last['visible'],
      false,
    );
    renderer.emit({'type': 'touch-controls-changed', 'visible': true});
    await Future<void>.delayed(Duration.zero);
    await controller.preferencesSettled;
    expect((await repository.getPreferences()).touchControlsVisible, true);
    await controller.setTouchControlsVisible(false);
    await controller.resetPreferences();
    expect(controller.touchControlsVisible, true);
  });

  test('roads persist independently across restart, style changes, reload and reset', () async {
    await controller.initializePreferences(repository);
    await controller.setRoadsOverlay(visible: true, opacity: .6);
    await controller.setMapStyle(GlobeMapStyle.topographic);
    expect(controller.roadsVisible, isTrue);
    expect(controller.situationalVisible('roads'), isTrue);
    controller.dispose();
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
    await controller.initializePreferences(repository);
    expect(controller.roadsVisible, isTrue);
    expect(controller.roadsOpacity, .6);
    renderer.commands.clear();
    renderer.sessionId = 'roads-reload';
    renderer.sequence = 0;
    renderer.emit({'type': 'renderer-loading'});
    renderer.ready();
    await Future<void>.delayed(Duration.zero);
    expect(
      renderer.commands.where((c) => c['id'] == 'roads').single['opacity'],
      .6,
    );
    await controller.resetPreferences();
    expect(controller.roadsVisible, isFalse);
    expect(controller.situationalVisible('roads'), isFalse);
    expect(
      renderer.commands.where((c) => c['id'] == 'roads').last['visible'],
      isFalse,
    );
  });

  test(
    'rejected road commands do not persist or replay an unconfirmed choice',
    () async {
      await controller.initializePreferences(controlled);
      renderer.autoAcknowledge = false;
      final change = controller.setRoadsOverlay(visible: true);
      final result = expectLater(change, throwsStateError);
      renderer.acknowledge(renderer.commands.last, error: 'Synthetic failure');
      await result;
      expect(controlled.writes, 0);
      expect(controller.roadsVisible, isFalse);
      expect(controller.situationalVisible('roads'), isFalse);
    },
  );

  test(
    'restores preferences and order without writing defaults or snapshots',
    () async {
      await repository.savePreferences(
        const UserPreferences(
          mapStyle: GlobeMapStyle.relief,
          uasZonesVisible: true,
          uasZonesFillOpacity: .65,
          savedSpotsVisible: false,
          overlayOrder: [GlobeOverlay.savedSpots, GlobeOverlay.uasZones],
        ),
      );
      await controller.initializePreferences(controlled);
      expect(controlled.writes, 0);
      expect(controller.savedSpotsVisible, isFalse);
      expect(controller.overlayOrder.first, GlobeOverlay.savedSpots);
      expect(
        renderer.commands.firstWhere(
          (c) => c['type'] == 'set-map-style',
        )['style'],
        'relief',
      );
      expect(
        renderer.commands.firstWhere(
          (c) => c['type'] == 'set-uas-opacity',
        )['opacity'],
        .65,
      );
      expect(
        renderer.commands.firstWhere(
          (c) => c['type'] == 'set-spots-visible',
        )['visible'],
        isFalse,
      );
      expect(
        renderer.commands.firstWhere(
          (c) => c['type'] == 'set-overlay-order',
        )['order'],
        ['savedSpots', 'uasZones'],
      );
      renderer.commands.clear();
      renderer.sessionId = 'reload';
      renderer.sequence = 0;
      renderer.emit({'type': 'renderer-loading'});
      renderer.ready();
      await Future<void>.delayed(Duration.zero);
      expect(
        renderer.commands.where((c) => c['type'] == 'set-overlay-order'),
        hasLength(1),
      );
      expect(controlled.writes, 0);
    },
  );

  test('UI changes persist together and survive a new controller', () async {
    await controller.initializePreferences(controlled);
    expect(await database.select(database.appSettings).get(), isEmpty);
    await controller.setMapStyle(GlobeMapStyle.topographic);
    await controller.setUasZonesVisible(true);
    await controller.setUasZonesFillOpacity(.55);
    await controller.setSavedSpotsVisible(false);
    await controller.setOverlayOrder([
      GlobeOverlay.savedSpots,
      GlobeOverlay.uasZones,
    ]);
    controller.dispose();
    controller = GlobeController(uasProvider: SwissUasProvider(client: client));
    renderer = FakeGlobeRenderer(controller)..attach();
    renderer.ready();
    await controller.initializePreferences(repository);
    final stored = await repository.getPreferences();
    expect(stored.mapStyle, GlobeMapStyle.topographic);
    expect(stored.uasZonesVisible, isTrue);
    expect(stored.uasZonesFillOpacity, .55);
    expect(controller.savedSpotsVisible, isFalse);
    expect(controller.overlayOrder, stored.overlayOrder);
  });

  test('serializes writes and keeps the last rapid UI change', () async {
    await controller.initializePreferences(controlled);
    controlled.writeGate = Completer<void>();
    final first = controller.setMapStyle(GlobeMapStyle.relief);
    await Future<void>.delayed(Duration.zero);
    final second = controller.setSavedSpotsVisible(false);
    await Future<void>.delayed(Duration.zero);
    expect(controlled.writes, 1);
    controlled.writeGate!.complete();
    await Future.wait([first, second]);
    final stored = await repository.getPreferences();
    expect(stored.mapStyle, GlobeMapStyle.relief);
    expect(stored.savedSpotsVisible, isFalse);
  });

  test('failed renderer commands never become stored choices', () async {
    await controller.initializePreferences(controlled);
    renderer.autoAcknowledge = false;
    final change = controller.setMapStyle(GlobeMapStyle.relief);
    final result = expectLater(change, throwsStateError);
    renderer.acknowledge(
      renderer.commands.last,
      error: 'Synthetic renderer failure',
    );
    await result;
    expect(controlled.writes, 0);
    renderer.autoAcknowledge = true;
    await controller.setSavedSpotsVisible(false);
    await controller.preferencesSettled;
    expect(
      (await repository.getPreferences()).mapStyle,
      GlobeMapStyle.satellite,
    );
  });

  test(
    'a superseded UAS download cannot overwrite the later disabled choice',
    () async {
      controller.dispose();
      client.close();
      final response = Completer<http.Response>();
      client = MockClient((_) => response.future);
      controller = GlobeController(
        uasProvider: SwissUasProvider(client: client),
      );
      renderer = FakeGlobeRenderer(controller)..attach();
      renderer.ready();
      await controller.initializePreferences(controlled);
      final enabling = controller.setUasZonesVisible(true);
      await controller.setUasZonesVisible(false);
      response.complete(
        http.Response('{"type":"FeatureCollection","features":[]}', 200),
      );
      await enabling;
      expect((await repository.getPreferences()).uasZonesVisible, isFalse);
      expect(
        renderer.commands.where((command) => command['geojson'] != null),
        isEmpty,
      );
    },
  );

  test(
    'hidden spots clear selection and reject stale renderer picks',
    () async {
      await controller.initializePreferences(controlled);
      await controller.setSpotMarkers([
        const SpotMapMarker(id: 1, name: 'Fixture', latitude: 47, longitude: 8),
      ]);
      renderer.emit({'type': 'spot-selected', 'id': 1});
      expect(controller.selectedSpotId, 1);
      await controller.setSavedSpotsVisible(false);
      renderer.emit({'type': 'spot-selected', 'id': 1});
      expect(controller.selectedSpotId, isNull);
      await controller.setSavedSpotsVisible(true);
      renderer.emit({'type': 'spot-selected', 'id': 1});
      expect(controller.selectedSpotId, 1);
    },
  );

  testWidgets(
    'load failure disables controls and explicit reset preserves unrelated settings',
    (tester) async {
      await database
          .into(database.appSettings)
          .insert(AppSettingsCompanion.insert(key: 'unrelated', value: 'keep'));
      controlled.failReads = true;
      await controller.initializePreferences(controlled);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapLayersSheet(controller: controller)),
        ),
      );
      expect(
        find.textContaining('Unable to load map preferences'),
        findsOneWidget,
      );
      final spots = find.widgetWithText(SwitchListTile, 'Show saved spots');
      expect(tester.widget<SwitchListTile>(spots).onChanged, isNull);
      expect(controlled.writes, 0);
      controlled.failReads = false;
      await tester.tap(find.text('Reset map preferences'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(spots).onChanged, isNotNull);
      expect(
        (await database.select(database.appSettings).get()).single.key,
        'unrelated',
      );
    },
  );

  testWidgets(
    'save failure is visible and Retry saves the current UI snapshot',
    (tester) async {
      await controller.initializePreferences(controlled);
      controlled.failWrites = true;
      await controller.setSavedSpotsVisible(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapLayersSheet(controller: controller)),
        ),
      );
      expect(find.textContaining('Map changes are not saved'), findsOneWidget);
      expect(controller.savedSpotsVisible, isFalse);
      expect((await repository.getPreferences()).savedSpotsVisible, isTrue);
      controlled.failWrites = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Map changes are not saved'), findsNothing);
      expect((await repository.getPreferences()).savedSpotsVisible, isFalse);
    },
  );

  testWidgets(
    'loading gates controls; compact layer order and visibility controls work',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      controlled.readGate = Completer<void>();
      final loading = controller.initializePreferences(controlled);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapLayersSheet(controller: controller)),
        ),
      );
      expect(find.text('Loading saved map preferences...'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<GlobeMapStyle>>(
              find.byType(SegmentedButton<GlobeMapStyle>),
            )
            .onSelectionChanged,
        isNull,
      );
      controlled.readGate!.complete();
      await loading;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Bring UAS zones forward'));
      await tester.tap(find.byTooltip('Bring UAS zones forward'));
      await tester.pumpAndSettle();
      expect(
        (await repository.getPreferences()).overlayOrder.last,
        GlobeOverlay.uasZones,
      );
      final spots = find.widgetWithText(SwitchListTile, 'Show saved spots');
      await tester.ensureVisible(spots);
      await tester.tap(spots);
      await tester.pumpAndSettle();
      expect((await repository.getPreferences()).savedSpotsVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
