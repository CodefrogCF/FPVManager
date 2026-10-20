import 'dart:async';

import 'package:flutter/foundation.dart';

import 'osint_dataset.dart';
import 'osint_provider.dart';
import 'osint_provider_state.dart';

/// Shared in-memory cache, update/error state and retirement of late responses.
/// Adapters implement transport/normalization and return a complete dataset.
abstract class CachedOsintProvider<T> extends ChangeNotifier
    implements OsintProvider<T> {
  CachedOsintProvider({
    this.cacheDuration = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (cacheDuration.isNegative) {
      throw ArgumentError.value(cacheDuration, 'cacheDuration');
    }
  }

  final Duration cacheDuration;
  final DateTime Function() _now;
  OsintDataset<T>? _cached;
  Future<OsintDataset<T>>? _inFlight;
  OsintUpdateState _update = OsintUpdateState.idle;
  OsintProviderException? _error;
  DateTime? _lastAttempt;
  bool _servedFromCache = false;
  bool _disposed = false;

  DateTime get nowUtc => _now().toUtc();
  OsintDataset<T>? get cached => _cached;
  @override
  String get id => source.id;
  @override
  Uri get sourceUri => source.dataUri;

  @override
  OsintProviderState<T> get status {
    final dataset = _cached;
    final time = nowUtc;
    final freshness = dataset?.freshnessAt(time) ?? OsintFreshness.notLoaded;
    return OsintProviderState(
      update: _update,
      freshness: freshness,
      checkedAtUtc: time,
      dataset: dataset,
      lastAttemptAtUtc: _lastAttempt,
      error: _error,
      servedFromCache: _servedFromCache,
    );
  }

  Future<OsintDataset<T>> download();

  @override
  Future<OsintDataset<T>> fetch({bool forceRefresh = false}) {
    if (_disposed) return Future.error(_disposedError());
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!forceRefresh && status.freshness == OsintFreshness.fresh) {
      final changed = !_servedFromCache;
      _servedFromCache = true;
      // A cache hit does not erase a failed network refresh.
      if (changed) notifyListeners();
      return Future.value(_cached!);
    }
    _update = OsintUpdateState.loading;
    _error = null;
    _servedFromCache = false;
    _lastAttempt = nowUtc;
    // Install the shared future before notifying, including reentrant callers.
    final completer = Completer<OsintDataset<T>>();
    _inFlight = completer.future;
    notifyListeners();
    unawaited(_performDownload(completer));
    return completer.future;
  }

  Future<void> _performDownload(Completer<OsintDataset<T>> completer) async {
    try {
      if (_disposed) throw _disposedError();
      final dataset = await download();
      if (_disposed) throw _disposedError();
      if (dataset.providerId != id ||
          dataset.sourceUrl != sourceUri ||
          !dataset.fetchedAtUtc.isUtc ||
          !dataset.cacheExpiresAtUtc.isUtc ||
          dataset.cacheExpiresAtUtc.isBefore(dataset.fetchedAtUtc)) {
        throw const FormatException('Invalid provider dataset metadata');
      }
      _cached = dataset;
      _update = OsintUpdateState.ready;
      completer.complete(dataset);
    } catch (error, stack) {
      final failure = _disposed
          ? _disposedError()
          : switch (error) {
              OsintProviderException failure => failure,
              TimeoutException() => OsintProviderException(
                providerId: id,
                kind: OsintFailureKind.timeout,
                message: 'Data request timed out',
              ),
              FormatException() => OsintProviderException(
                providerId: id,
                kind: OsintFailureKind.invalidData,
                message: 'Invalid source data or metadata',
              ),
              _ => OsintProviderException(
                providerId: id,
                kind: OsintFailureKind.unknown,
                message: 'Data update failed',
              ),
            };
      if (!_disposed) {
        _update = OsintUpdateState.failed;
        _error = failure;
      }
      completer.completeError(failure, stack);
    } finally {
      _inFlight = null;
      if (!_disposed) notifyListeners();
    }
  }

  OsintProviderException _disposedError() => OsintProviderException(
    providerId: id,
    kind: OsintFailureKind.disposed,
    message: 'Provider is disposed',
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _update = OsintUpdateState.disposed;
    super.dispose();
  }
}
