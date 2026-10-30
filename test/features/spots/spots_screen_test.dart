import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/models/spot_classification.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/spots_screen.dart';

void main() {
  late FpvDatabase database;
  late SpotRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
  });
  tearDown(() => database.close());
  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SpotsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<int> spot(
    String name, {
    String? category,
    List<String> tags = const [],
  }) => repository.createSpot(
    name: name,
    latitude: 47,
    longitude: 8,
    notes: 'Full private description',
    classification: SpotClassification(category: category, tags: tags),
  );

  testWidgets(
    'search debounces, combines filters, and favorite removal updates empty state',
    (tester) async {
      final id = await spot(
        'Alpine target',
        category: 'Alpine',
        tags: ['quiet', 'freestyle'],
      );
      await spot('Field other', category: 'Field', tags: ['quiet']);
      await repository.setFavorite(id: id, isFavorite: true);
      await open(tester);
      await tester.enterText(field('Search spots'), 'target');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Field other'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Field other'), findsNothing);
      await tester.tap(find.text('Categories / tags'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Category'), 'Alpine');
      await tester.enterText(field('Tags'), 'quiet, freestyle');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Alpine target'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove favorite'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No spots found.'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Field other'), findsOneWidget);
      expect(find.text('Alpine target'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'continuous list loads automatically and a new search resets the loaded result',
    (tester) async {
      await database.batch((batch) {
        for (var i = 1; i <= 115; i++) {
          batch.insert(
            database.spots,
            SpotsCompanion.insert(
              id: Value(i),
              name: 'Spot $i',
              latitude: 47,
              longitude: 8,
              searchText: Value('spot $i'),
            ),
          );
        }
      });
      await open(tester);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Spot 115'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Spot 5'),
        500,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('continuous-spot-list')),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      expect(find.text('Spot 5'), findsOneWidget);
      await tester.enterText(field('Search spots'), '115');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Spot 115'), findsOneWidget);
      expect(find.text('Spot 5'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('list opens live details and editing preserves tags', (
    tester,
  ) async {
    final id = await spot('Detailed spot', category: 'Alpine', tags: ['quiet']);
    await open(tester);
    await tester.tap(find.text('Detailed spot'));
    await tester.pumpAndSettle();
    expect(find.text('Spot details'), findsOneWidget);
    expect(find.text('Full private description'), findsOneWidget);
    expect(find.text('Category: Alpine'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Tags')).controller!.text, 'quiet');
    await tester.enterText(field('Spot name'), 'Renamed spot');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed spot'), findsOneWidget);
    expect(await repository.getTags(id), ['quiet']);
    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pumpAndSettle();
    expect((await repository.getSpot(id))!.isFavorite, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'many filters remain reachable with a small screen and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await tester.tap(find.text('Categories / tags'));
      await tester.pumpAndSettle();
      await tester.enterText(
        field('Tags'),
        List.generate(10, (i) => 'long tag number $i').join(', '),
      );
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Show on map returns selected spot through list route', (
    tester,
  ) async {
    final id = await spot('Map target');
    Spot? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<Spot>(
                  MaterialPageRoute(
                    builder: (_) => SpotsScreen(repository: repository),
                  ),
                );
              },
              child: const Text('Open spots'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open spots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show on map'));
    await tester.pumpAndSettle();
    expect(selected?.id, id);
    expect(find.text('Open spots'), findsOneWidget);
  });
}
