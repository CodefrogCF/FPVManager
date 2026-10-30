import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/spot_query.dart';
import 'data/spot_repository.dart';

/// Keeps only visited summaries. Every database query stays at 50 rows; photo
/// BLOBs and the full-library projection are never loaded by this controller.
class SpotListController extends ChangeNotifier {
  SpotListController(this.repository) {
    _changes = repository.watchListChanges().listen(
      (_) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          const Duration(milliseconds: 80),
          () => unawaited(refresh()),
        );
      },
      onError: (Object _) {
        if (!_disposed) {
          error = 'Unable to observe spot changes. Refresh to retry.';
          notifyListeners();
        }
      },
    );
    unawaited(refresh());
  }
  static const pageSize = 50;
  final SpotRepository repository;
  late final StreamSubscription<void> _changes;
  Timer? _refreshTimer;
  SpotFilter _filter = SpotFilter();
  List<SpotSummary> items = const [];
  bool loading = false, refreshing = false, hasMore = true;
  String? error;
  bool _failedMore = false, _disposed = false;
  int _generation = 0;

  void setFilter(SpotFilter filter) {
    _filter = filter;
    _refreshTimer?.cancel();
    unawaited(refresh(reset: true));
  }

  Future<void> refresh({bool reset = false}) async {
    if (_disposed) return;
    final generation = ++_generation,
        target = reset ? pageSize : items.length.clamp(pageSize, 100000);
    if (reset) items = const [];
    error = null;
    _failedMore = false;
    loading = items.isEmpty;
    refreshing = !loading;
    notifyListeners();
    final next = <SpotSummary>[];
    try {
      int? cursor;
      bool more;
      do {
        final page = await repository.getSpotPage(
          filter: _filter,
          beforeId: cursor,
          limit: pageSize,
        );
        if (_disposed || generation != _generation) return;
        next.addAll(page.items);
        more = page.hasNext;
        final nextCursor = page.nextBeforeId;
        if (more && (nextCursor == null || nextCursor == cursor)) {
          throw StateError('Invalid spot cursor');
        }
        cursor = nextCursor;
      } while (more && next.length < target);
      items = List.unmodifiable(
        {for (final spot in next) spot.id: spot}.values,
      );
      hasMore = more;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Unable to load spots. Previously loaded spots remain available.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || loading || refreshing || !hasMore || error != null) return;
    final generation = _generation;
    loading = true;
    notifyListeners();
    try {
      final page = await repository.getSpotPage(
        filter: _filter,
        beforeId: items.lastOrNull?.id,
        limit: pageSize,
      );
      if (_disposed || generation != _generation) return;
      final combined = {for (final spot in items) spot.id: spot};
      for (final spot in page.items) {
        combined[spot.id] = spot;
      }
      if (page.hasNext &&
          (page.items.isEmpty || combined.length == items.length)) {
        throw StateError('Invalid next page');
      }
      items = List.unmodifiable(combined.values);
      hasMore = page.hasNext;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _failedMore = true;
        error = 'Unable to load more spots.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() {
    final more = _failedMore;
    error = null;
    return more ? loadMore() : refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    unawaited(_changes.cancel());
    super.dispose();
  }
}
