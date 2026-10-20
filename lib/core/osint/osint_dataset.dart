import 'osint_source.dart';

enum OsintFreshness { notLoaded, fresh, stale, clockSkew }

class OsintDataset<T> {
  const OsintDataset({
    required this.source,
    required this.data,
    required this.fetchedAtUtc,
    required this.cacheExpiresAtUtc,
    this.validity,
    this.httpLastModified,
  });

  final OsintSource source;
  String get providerId => source.id;
  Uri get sourceUrl => source.dataUri;
  final T data;

  /// Time when FPVManager successfully fetched the data.
  final DateTime fetchedAtUtc;

  /// Local cache policy, not an official validity or publication timestamp.
  final DateTime cacheExpiresAtUtc;

  final OsintValidityPeriod? validity;

  OsintFreshness freshnessAt(DateTime time) {
    final utc = time.toUtc();
    if (utc.isBefore(fetchedAtUtc)) return OsintFreshness.clockSkew;
    return utc.isBefore(cacheExpiresAtUtc)
        ? OsintFreshness.fresh
        : OsintFreshness.stale;
  }

  /// Optional HTTP Last-Modified header.
  ///
  /// This is not necessarily the official dataset
  /// publication or validity timestamp.
  final String? httpLastModified;
}
