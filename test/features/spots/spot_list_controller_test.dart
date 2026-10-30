import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_query.dart';
import 'package:fpvmanager/features/spots/spot_list_controller.dart';

class PagingRepository implements SpotRepository {
  PagingRepository({this.delegate});
  final SpotRepository? delegate;
  final changes = StreamController<void>.broadcast(sync: true);
  final calls = <({int? cursor, int limit, String query})>[];
  Future<SpotPage> Function(SpotFilter, int?)? handler;
  @override
  Future<SpotPage> getSpotPage({
    SpotFilter? filter,
    int? beforeId,
    int limit = 50,
  }) {
    final f = filter ?? SpotFilter();
    calls.add((cursor: beforeId, limit: limit, query: f.query));
    return handler?.call(f, beforeId) ??
        delegate!.getSpotPage(filter: f, beforeId: beforeId, limit: limit);
  }

  @override
  Stream<void> watchListChanges() =>
      delegate?.watchListChanges() ?? changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected eager operation: ${invocation.memberName}');
}

SpotSummary summary(int id) => SpotSummary(
  id: id,
  name: 'Spot $id',
  latitude: 47,
  longitude: 8,
  isFavorite: false,
  category: null,
  notesPreview: '',
  tags: const [],
);
Future<void> until(bool Function() predicate) async {
  for (var i = 0; i < 500; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('List did not settle');
}

void main() {
  test('10000 file-backed spots load lazily in bounded pages, with no gaps after changes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-continuous-spots-',
    );
    final db = FpvDatabase(
      NativeDatabase(File('${directory.path}/spots.sqlite')),
    );
    final repo = SpotRepository(db),
        paging = PagingRepository(delegate: SpotRepository(db));
    SpotListController? list;
    addTearDown(() async {
      list?.dispose();
      await db.close();
      await paging.changes.close();
      await directory.delete(recursive: true);
    });
    await db.batch((batch) {
      for (var i = 1; i <= 10000; i++) {
        batch.insert(
          db.spots,
          SpotsCompanion.insert(
            id: Value(i),
            name: 'Spot $i',
            latitude: 47,
            longitude: 8,
            notes: const Value('Private long notes'),
            searchText: Value('spot $i'),
          ),
        );
      }
    });
    list = SpotListController(paging);
    final controller = list;
    await until(() => !controller.loading);
    expect(controller.items, hasLength(50));
    expect(paging.calls, hasLength(1));
    for (var i = 0; i < 4; i++) {
      await controller.loadMore();
    }
    expect(controller.items, hasLength(250));
    expect(paging.calls.every((c) => c.limit == 50), true);
    final id = await repo.createSpot(
      name: 'New head',
      latitude: 47,
      longitude: 8,
    );
    await until(
      () => controller.items.first.id == id && !controller.refreshing,
    );
    expect(controller.items.map((s) => s.id).toSet(), hasLength(250));
    await repo.deleteSpot(9990);
    await until(() => !controller.items.any((s) => s.id == 9990));
    while (controller.hasMore) {
      await controller.loadMore();
    }
    expect(controller.items, hasLength(10000));
    expect(controller.items.map((s) => s.id).toSet(), hasLength(10000));
    expect(controller.items.last.id, 1);
    expect(paging.calls.every((c) => c.limit <= 50), true);
  });
  test('superseded filters cannot mix late results and failed next loads retain accessible items', () async {
    final repo = PagingRepository(),
        old = Completer<SpotPage>(),
        fresh = Completer<SpotPage>();
    repo.handler = (filter, cursor) =>
        filter.query == 'new' ? fresh.future : old.future;
    final list = SpotListController(repo);
    addTearDown(() async {
      list.dispose();
      await repo.changes.close();
    });
    list.setFilter(SpotFilter(query: 'new'));
    fresh.complete(
      SpotPage(
        items: List.generate(50, (i) => summary(100 - i)),
        hasNext: true,
      ),
    );
    await until(() => !list.loading);
    old.complete(SpotPage(items: [summary(999)], hasNext: false));
    await Future<void>.delayed(Duration.zero);
    expect(list.items.first.id, 100);
    expect(list.items.any((s) => s.id == 999), false);
    repo.handler = (_, _) async => throw StateError('disk');
    await list.loadMore();
    expect(list.items, hasLength(50));
    expect(list.error, isNotNull);
    repo.handler = (_, _) async =>
        SpotPage(items: [summary(49)], hasNext: false);
    await list.retry();
    expect(list.items, hasLength(51));
    expect(list.error, isNull);
    expect(list.hasMore, false);
  });
}
