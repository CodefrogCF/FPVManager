import 'dart:async';

import 'package:flutter/foundation.dart';

import 'osint_dataset.dart';
import 'osint_dataset_store.dart';
import 'osint_provider.dart';
import 'osint_provider_state.dart';

/// Shared in-memory cache, update/error state and retirement of late responses.
/// Adapters implement transport/normalization and return a complete dataset.
abstract class CachedOsintProvider<T> extends ChangeNotifier
    implements OsintProvider<T> {
  CachedOsintProvider({
    this.cacheDuration = const Duration(hours: 1),
    DateTime Function()? now,
    this.persistentCache,
  }) : _now = now ?? DateTime.now {
    if (cacheDuration.isNegative) {
      throw ArgumentError.value(cacheDuration, 'cacheDuration');
    }
  }

  final Duration cacheDuration;
  final OsintDatasetStore<T>? persistentCache;
  final DateTime Function() _now;
  OsintDataset<T>? _cached;
  Future<OsintDataset<T>>? _inFlight;
  OsintUpdateState _update = OsintUpdateState.idle;
  OsintProviderException? _error;
  DateTime? _lastAttempt;
  bool _servedFromCache = false;
  bool _disposed = false;
  Future<void>? _cacheLoad;
  String? _cacheError;
  bool _clearing = false;

  DateTime get nowUtc => _now().toUtc();
  OsintDataset<T>? get cached => _cached;
  bool get isClearing => _clearing;
  Future<void> get settled async {
    try {
      await _inFlight;
    } catch (_) {
      /* Disposal also drains failed updates. */
    }
    try {
      await _cacheLoad;
    } catch (_) {
      /* Cache failures are reported separately. */
    }
  }

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
      cacheError: _cacheError,
    );
  }

  Future<OsintDataset<T>> download();

  /// Adapters can reject unusable content before it replaces a disk snapshot.
  void validateData(T data) {}

  /// Only adapters that have verified a genuine not-modified response may
  /// skip revalidating/re-encoding the same large payload. Default: no.
  bool reusesCachedPayload(
    OsintDataset<T>? previous,
    OsintDataset<T> current,
  ) => false;

  Future<void> loadCached() => _cacheLoad ??= _readPersistentCache();

  Future<void> _readPersistentCache() async {
    if (persistentCache == null || _disposed) return;
    try {
      final dataset = await persistentCache!.read(source, nowUtc);
      if (_disposed) return;
      if (dataset != null) {
        _validate(dataset);
        validateData(dataset.data);
        _cached = dataset;
        _servedFromCache = true;
        _update = OsintUpdateState.ready;
      }
    } catch (_) {
      try {
        await persistentCache!.remove(id);
      } catch (_) {
        /* Disk errors stay non-fatal. */
      }
      if (!_disposed) {
        _cacheError = 'Local cache unavailable or invalid; download again.';
      }
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> clearCache() async {
    if (_disposed || _clearing) return;
    _clearing = true;
    notifyListeners();
    try {
      await _cacheLoad;
      try {
        await _inFlight;
      } catch (_) {
        /* The old snapshot can still be cleared. */
      }
      if (_disposed) return;
      await persistentCache?.remove(id);
      _cached = null;
      _cacheLoad = null;
      _cacheError = null;
      _error = null;
      _update = OsintUpdateState.idle;
      _servedFromCache = false;
    } finally {
      _clearing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _validate(OsintDataset<T> dataset) {
    final checked = dataset.lastCheckedAtUtc ?? dataset.fetchedAtUtc;
    if (dataset.providerId != id ||
        dataset.sourceUrl != sourceUri ||
        !dataset.fetchedAtUtc.isUtc ||
        !checked.isUtc ||
        !dataset.cacheExpiresAtUtc.isUtc ||
        checked.isBefore(dataset.fetchedAtUtc) ||
        dataset.cacheExpiresAtUtc.isBefore(checked) ||
        dataset.publishedAtUtc != null && !dataset.publishedAtUtc!.isUtc) {
      throw const FormatException('Invalid provider dataset metadata');
    }
  }

  @override
  Future<OsintDataset<T>> fetch({bool forceRefresh = false}) {
    if (_disposed) return Future.error(_disposedError());
    if (_clearing) return Future.error(StateError('Cache is being cleared'));
    final pending = _inFlight;
    if (pending != null) return pending;
    if ((persistentCache == null || _cacheLoad != null) &&
        !forceRefresh &&
        status.freshness == OsintFreshness.fresh) {
      final changed = !_servedFromCache;
      _servedFromCache = true;
      // A cache hit does not erase a failed network refresh.
      if (changed) notifyListeners();
      return Future.value(_cached!);
    }
    // Install the shared future before notifying, including reentrant callers.
    final completer = Completer<OsintDataset<T>>();
    _inFlight = completer.future;
    unawaited(_performDownload(completer, forceRefresh));
    return completer.future;
  }

  Future<void> _performDownload(
    Completer<OsintDataset<T>> completer,
    bool forceRefresh,
  ) async {
    try {
      if (_disposed) throw _disposedError();
      if (persistentCache != null) await loadCached();
      if (_disposed) throw _disposedError();
      if (!forceRefresh && status.freshness == OsintFreshness.fresh) {
        _servedFromCache = true;
        completer.complete(_cached!);
        return;
      }
      _update = OsintUpdateState.loading;
      _error = null;
      _servedFromCache = false;
      _lastAttempt = nowUtc;
      notifyListeners();
      final dataset = await download();
      if (_disposed) throw _disposedError();
      _validate(dataset);
      final old = _cached;
      final samePayload = reusesCachedPayload(old, dataset);
      if (!samePayload) validateData(dataset.data);
      if (persistentCache != null) {
        try {
          final store = persistentCache!;
          if (samePayload &&
              old != null &&
              store is OsintMetadataRefreshStore<T>) {
            // HTTP 304 only updates timestamps/validators, not ~14 MB of
            // GeoJSON. A small atomic overlay avoids re-encoding and hashing.
            await (store as OsintMetadataRefreshStore<T>).updateRevalidation(
              old,
              dataset,
            );
          } else {
            await store.write(dataset);
          }
          _cacheError = null;
        } catch (_) {
          _cacheError = 'Data downloaded, but the local cache could not be saved or cleared.';
        }
      }
      if (_disposed) throw _disposedError();
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
                message: 'Invalid source data or metadata: ${error.message}',
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
      // An ordinary load can use an explicitly marked old snapshot offline.
      // A manual refresh still reports its failure to the caller.
      if (!_disposed && !forceRefresh && _cached != null) {
        _servedFromCache = true;
        completer.complete(_cached!);
      } else {
        completer.completeError(failure, stack);
      }
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
