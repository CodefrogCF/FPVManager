import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';
import 'package:fpvmanager/features/offline/offline_regions_section.dart';

class MemoryMaps implements OfflineMapStorage {
  @override
  bool get rendererReady => true;
  @override
  Future<List<OfflineRegion>> regions() async => [];
  @override
  Future<List<OfflineTileInfo>> tiles() async => [];
  @override
  Future<void> setRegions(List<OfflineRegion> regions) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'offline selection supports radius and assets, with country selection only on Web',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineRegionsSection(
                storage: MemoryMaps(),
                cachedMaps: false,
                onCachedMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add offline region'));
      await tester.tap(find.text('Add offline region'));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).max, 25);
      expect(find.text('Mittelpunkt auf Globe markieren'), findsOneWidget);
      if (kIsWeb) {
        final country = find.byKey(const Key('offline-whole-switzerland'));
        await tester.ensureVisible(country);
        await tester.tap(country);
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Gesamte Schweiz offline vorbereiten',
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      } else {
        expect(
          find.byKey(const Key('offline-whole-switzerland')),
          findsNothing,
        );
      }
      for (final title in ['Topografische Karte', '3D-Gelände']) {
        final checkbox = find.widgetWithText(CheckboxListTile, title);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      final start = find.widgetWithText(
        FilledButton,
        kIsWeb
            ? 'Gesamte Schweiz offline vorbereiten'
            : 'Bereich offline vorbereiten',
      );
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      final satellite = find.widgetWithText(
        CheckboxListTile,
        'Satellitenbilder · SWISSIMAGE 2 m',
      );
      await tester.ensureVisible(satellite);
      await tester.tap(satellite);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
