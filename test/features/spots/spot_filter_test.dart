import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/models/spot_classification.dart';
import 'package:fpvmanager/features/spots/data/spot_photo.dart';
import 'package:fpvmanager/features/spots/data/spot_query.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';

void main() {
  late FpvDatabase database;
  late SpotRepository repository;
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
  });
  tearDown(() => database.close());
  Future<int> spot(
    String name, {
    String? notes,
    String? category,
    List<String> tags = const [],
  }) => repository.createSpot(
    name: name,
    latitude: 47,
    longitude: 8,
    notes: notes,
    classification: SpotClassification(category: category, tags: tags),
  );
  Future<List<int>> matches(SpotFilter filter) async =>
      (await repository.getSpotPage(filter: filter)).items
          .map((item) => item.id)
          .toList();

  test('classification normalizes, deduplicates and validates labels', () {
    final labels = SpotClassification(
      category: '  Alpine   Field ',
      tags: [' Quiet ', 'QUIET', 'Freestyle', ''],
    );
    expect(labels.category, 'Alpine Field');
    expect(labels.categoryKey, 'alpine field');
    expect(labels.tags, ['freestyle', 'quiet']);
    expect(SpotClassification.parseTags('a, B, a, '), ['a', 'b']);
    for (final make in <void Function()>[
      () => SpotClassification(category: 'x' * 41),
      () => SpotClassification(tags: ['x' * 33]),
      () => SpotClassification(tags: List.generate(11, (i) => '$i')),
      () => SpotClassification(tags: ['a,b']),
      () => SpotClassification(category: 'a\nb'),
      () => SpotFilter(query: 'x' * 161),
    ]) {
      expect(make, throwsArgumentError);
    }
  });

  test('search covers all text fields with Unicode, AND terms and literal wildcards', () async {
    final id = await spot(
      'Älpler 100%',
      notes: 'Über dem See _ private',
      category: 'Alpine',
      tags: ['QUIET'],
    );
    await spot('Other', notes: 'Public lake');
    for (final query in [
      'älpler',
      'ÜBER',
      'ALPINE quiet',
      '100%',
      '_',
      "See _",
    ]) {
      expect(await matches(SpotFilter(query: query)), [id], reason: query);
    }
    expect(await matches(SpotFilter(query: "' OR 1=1 --")), isEmpty);
    expect(await matches(SpotFilter(query: 'quiet public')), isEmpty);
  });

  test('favorites, category and all tags combine, and update preserves or clears classification', () async {
    final id = await spot(
      'Target',
      category: 'Alpine',
      tags: ['quiet', 'freestyle'],
    );
    await spot(
      'Not favorite',
      category: 'alpine',
      tags: ['quiet', 'freestyle'],
    );
    await spot('Missing tag', category: 'Alpine', tags: ['quiet']);
    await repository.setFavorite(id: id, isFavorite: true);
    expect(
      await matches(
        SpotFilter(
          category: 'ALPINE',
          favoritesOnly: true,
          tags: ['QUIET', 'freestyle'],
        ),
      ),
      [id],
    );
    await repository.updateSpot(
      id: id,
      name: 'Renamed',
      latitude: 46,
      longitude: 7,
    );
    expect(await repository.getTags(id), ['freestyle', 'quiet']);
    expect((await repository.getSpot(id))!.category, 'Alpine');
    expect(await matches(SpotFilter(query: 'target')), isEmpty);
    await repository.updateSpot(
      id: id,
      name: 'Renamed',
      latitude: 46,
      longitude: 7,
      classification: SpotClassification(),
    );
    expect(await repository.getTags(id), isEmpty);
    expect((await repository.getSpot(id))!.category, isNull);
    expect((await repository.getSpot(id))!.isFavorite, isTrue);
  });

  test(
    'keyset pages neither duplicate nor skip and notes stay bounded',
    () async {
      final ids = [
        for (var i = 0; i < 105; i++) await spot('Spot $i', notes: 'n' * 500),
      ];
      final first = await repository.getSpotPage();
      final second = await repository.getSpotPage(beforeId: first.nextBeforeId);
      final third = await repository.getSpotPage(beforeId: second.nextBeforeId);
      expect(first.items.length, 50);
      expect(second.items.length, 50);
      expect(third.items.length, 5);
      expect(third.hasNext, isFalse);
      expect(third.nextBeforeId, isNull);
      expect(
        [...first.items, ...second.items, ...third.items].map((row) => row.id),
        ids.reversed,
      );
      expect(
        first.items.every((row) => row.notesPreview.length == 120),
        isTrue,
      );
      await spot('Inserted later');
      expect(
        (await repository.getSpotPage(beforeId: first.nextBeforeId)).items
            .map((row) => row.id),
        second.items.map((row) => row.id),
      );
      expect(() => repository.watchSpotPage(limit: 101), throwsArgumentError);
      expect(() => repository.watchSpotPage(beforeId: 0), throwsArgumentError);
    },
  );

  test('reactive page/detail updates and marker suppression preserve coherent snapshots', () async {
    final id = await spot('Live', tags: ['old']);
    final pages = StreamIterator(
      repository.watchSpotPage(filter: SpotFilter(favoritesOnly: true)),
    );
    final details = StreamIterator(repository.watchDetails(id));
    final markers = <List<SpotMapEntry>>[];
    final subscription = repository.watchMapSpots().listen(markers.add);
    addTearDown(() async {
      await pages.cancel();
      await details.cancel();
      await subscription.cancel();
    });
    await pages.moveNext();
    expect(pages.current.items, isEmpty);
    await details.moveNext();
    expect(details.current!.tags, ['old']);
    await repository.setFavorite(id: id, isFavorite: true);
    await pages.moveNext();
    expect(pages.current.items.single.id, id);
    await details.moveNext();
    expect(details.current!.spot.isFavorite, isTrue);
    await repository.updateSpot(
      id: id,
      name: 'Live',
      latitude: 47,
      longitude: 8,
      classification: SpotClassification(category: 'New', tags: ['new']),
    );
    await details.moveNext();
    expect(details.current!.tags, ['new']);
    expect(details.current!.spot.category, 'New');
    // Wait for SQLite's scheduled stream delivery, then check unchanged projections.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(markers, hasLength(1));
    await repository.deleteSpot(id);
    await details.moveNext();
    expect(details.current, isNull);
    expect(await repository.getTags(id), isEmpty);
  });

  test('classification rolls back with failed photo write', () async {
    final id = await spot('Original', category: 'Old', tags: ['old']);
    await database.customStatement(
      "CREATE TRIGGER fail_photo BEFORE INSERT ON spot_photos BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    final jpeg = Uint8List.fromList([255, 216, 255, 217]);
    final photo = PreparedSpotPhoto(
      imageBytes: jpeg,
      thumbnailBytes: jpeg,
      width: 1,
      height: 1,
    );
    await expectLater(
      repository.updateSpot(
        id: id,
        name: 'Changed',
        latitude: 47,
        longitude: 8,
        classification: SpotClassification(category: 'New', tags: ['new']),
        newPhotos: [photo],
      ),
      throwsA(anything),
    );
    expect((await repository.getSpot(id))!.name, 'Original');
    expect((await repository.getSpot(id))!.category, 'Old');
    expect(await repository.getTags(id), ['old']);
  });

  test('suggestions are canonical, filtered and capped', () async {
    for (var i = 0; i < 25; i++) {
      await spot('Spot $i', category: 'Category $i', tags: ['tag$i']);
    }
    await spot('Duplicate', category: 'CATEGORY 1', tags: ['TAG1']);
    expect(await repository.findCategories(''), hasLength(20));
    expect(await repository.findTags(''), hasLength(20));
    expect(await repository.findTags('tag24'), ['tag24']);
    expect(await repository.findCategories('category 24'), ['Category 24']);
    expect(
      await repository.findCategories('CATEGORY 1', limit: 100),
      hasLength(11),
    );
  });

  test('10000 file-backed spots retain bounded pages and lightweight map projection', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('fpv-spot-load-');
    final load = FpvDatabase(
      NativeDatabase(File('${directory.path}/load.sqlite')),
    );
    try {
      await load.batch((batch) {
        for (var i = 1; i <= 10000; i++) {
          batch.insert(
            load.spots,
            SpotsCompanion.insert(
              id: Value(i),
              name: 'Spot $i',
              latitude: 47,
              longitude: 8,
              notes: Value('Long notes $i ${'n' * 1500}'),
              category: Value(i.isEven ? 'Alpine' : 'Field'),
              categoryKey: Value(i.isEven ? 'alpine' : 'field'),
              isFavorite: Value(i % 10 == 0),
              searchText: Value('spot $i alpine quiet'),
            ),
          );
          batch.insert(
            load.spotTags,
            SpotTagsCompanion.insert(spotId: i, tag: 'quiet'),
          );
        }
      });
      final repo = SpotRepository(load);
      final watch = Stopwatch()..start();
      final first = await repo.getSpotPage();
      final firstMs = watch.elapsedMicroseconds / 1000;
      watch.reset();
      final filtered = await repo.getSpotPage(
        filter: SpotFilter(
          query: 'spot',
          category: 'Alpine',
          tags: ['quiet'],
          favoritesOnly: true,
        ),
      );
      final filterMs = watch.elapsedMicroseconds / 1000;
      watch.reset();
      final second = await repo.getSpotPage(
        filter: SpotFilter(
          query: 'spot',
          category: 'Alpine',
          tags: ['quiet'],
          favoritesOnly: true,
        ),
        beforeId: filtered.nextBeforeId,
      );
      final nextMs = watch.elapsedMicroseconds / 1000;
      watch.reset();
      final map = await repo.watchMapSpots().first;
      final mapMs = watch.elapsedMicroseconds / 1000;
      watch.stop();
      expect(first.items, hasLength(50));
      expect(filtered.items, hasLength(50));
      expect(second.items, hasLength(50));
      expect(filtered.items.first.id, 10000);
      expect(second.items.first.id, 9500);
      expect(map, hasLength(10000));
      expect(first.items.first.notesPreview.length, 120);
      // Native query measurements; these do not measure Android/Web rendering FPS.
      // ignore: avoid_print
      print(
        '10000 spots: first=${firstMs.toStringAsFixed(1)}ms filtered=${filterMs.toStringAsFixed(1)}ms next=${nextMs.toStringAsFixed(1)}ms markers=${mapMs.toStringAsFixed(1)}ms',
      );
    } finally {
      await load.close();
      final parent = await directory.parent.resolveSymbolicLinks();
      if (parent == await Directory.systemTemp.resolveSymbolicLinks() &&
          directory.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('fpv-spot-load-')) {
        await directory.delete(recursive: true);
      }
    }
  });
}
