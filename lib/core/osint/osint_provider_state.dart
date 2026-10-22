import 'osint_dataset.dart';
import 'osint_source.dart';

export 'osint_dataset.dart' show OsintFreshness;

enum OsintFailureKind { network, timeout, http, invalidData, disposed, unknown }

class OsintProviderException implements Exception {
  const OsintProviderException({
    required this.providerId,
    required this.kind,
    required this.message,
    this.httpStatus,
  });

  final String providerId;
  final OsintFailureKind kind;
  final String message;
  final int? httpStatus;

  @override
  String toString() => message;
}

enum OsintUpdateState { idle, loading, ready, failed, disposed }

/// Dataset availability and last update outcome. `fresh` only describes the
/// local cache policy; it never certifies coverage or permission to fly.
enum OsintDataState {
  fresh,
  stale,
  expired,
  unavailable,
  refreshFailed,
  clockSkew,
}

extension OsintDataStateLabel on OsintDataState {
  String get label => switch (this) {
    OsintDataState.fresh => 'Cached · within local lifetime',
    OsintDataState.stale => 'Stale cached data · refresh required',
    OsintDataState.expired => 'Declared validity expired',
    OsintDataState.unavailable => 'Data unavailable',
    OsintDataState.refreshFailed => 'Latest refresh failed',
    OsintDataState.clockSkew => 'Device clock precedes last source check',
  };
}

class OsintProviderState<T> {
  const OsintProviderState({
    required this.update,
    required this.freshness,
    required this.checkedAtUtc,
    this.dataset,
    this.lastAttemptAtUtc,
    this.error,
    this.servedFromCache = false,
    this.cacheError,
  });

  final OsintUpdateState update;
  final OsintFreshness freshness;
  final DateTime checkedAtUtc;
  final OsintDataset<T>? dataset;
  final DateTime? lastAttemptAtUtc;
  final OsintProviderException? error;
  final bool servedFromCache;
  final String? cacheError;

  OsintDataState get dataState {
    if (error != null) return OsintDataState.refreshFailed;
    if (dataset == null) return OsintDataState.unavailable;
    if (freshness == OsintFreshness.clockSkew) return OsintDataState.clockSkew;
    if (dataset!.validity?.at(checkedAtUtc) == OsintValidity.expired) {
      return OsintDataState.expired;
    }
    return freshness == OsintFreshness.fresh
        ? OsintDataState.fresh
        : OsintDataState.stale;
  }
}
