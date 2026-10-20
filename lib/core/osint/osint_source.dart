/// Identity and rights supplied by an adapter, independent of the map UI.
class OsintSource {
  const OsintSource({
    required this.id,
    required this.name,
    required this.publisher,
    required this.dataUri,
    required this.metadataUri,
    this.licenseName,
    this.licenseUri,
    this.attribution,
    this.coordinateReference,
  });

  final String id;
  final String name;
  final String publisher;
  final Uri dataUri;
  final Uri metadataUri;

  /// Null means that the adapter has no verified licence declaration.
  final String? licenseName;
  final Uri? licenseUri;
  final String? attribution;
  final String? coordinateReference;
}

enum OsintValidity { unknown, notYetValid, withinPeriod, expired }

/// Official applicability only; never inferred from download or HTTP timestamps.
class OsintValidityPeriod {
  OsintValidityPeriod({DateTime? from, DateTime? until})
    : fromUtc = from?.toUtc(),
      untilUtc = until?.toUtc() {
    if (fromUtc != null && untilUtc != null && !untilUtc!.isAfter(fromUtc!)) {
      throw ArgumentError('Validity end must be after its start');
    }
  }

  final DateTime? fromUtc;
  final DateTime? untilUtc;

  OsintValidity at(DateTime time) {
    final utc = time.toUtc();
    if (fromUtc != null && utc.isBefore(fromUtc!)) {
      return OsintValidity.notYetValid;
    }
    if (untilUtc != null && !utc.isBefore(untilUtc!)) {
      return OsintValidity.expired;
    }
    return fromUtc == null && untilUtc == null
        ? OsintValidity.unknown
        : OsintValidity.withinPeriod;
  }
}
