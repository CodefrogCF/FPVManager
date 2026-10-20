import 'osint_dataset.dart';

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

class OsintProviderState<T> {
  const OsintProviderState({
    required this.update,
    required this.freshness,
    required this.checkedAtUtc,
    this.dataset,
    this.lastAttemptAtUtc,
    this.error,
    this.servedFromCache = false,
  });

  final OsintUpdateState update;
  final OsintFreshness freshness;
  final DateTime checkedAtUtc;
  final OsintDataset<T>? dataset;
  final DateTime? lastAttemptAtUtc;
  final OsintProviderException? error;
  final bool servedFromCache;
}
