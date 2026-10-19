class OsintDataset<T> {
  const OsintDataset({
    required this.providerId,
    required this.sourceUrl,
    required this.data,
    required this.fetchedAtUtc,
    this.httpLastModified,
  });

  final String providerId;
  final Uri sourceUrl;
  final T data;

  /// Time when FPVManager successfully fetched the data.
  final DateTime fetchedAtUtc;

  /// Optional HTTP Last-Modified header.
  ///
  /// This is not necessarily the official dataset
  /// publication or validity timestamp.
  final String? httpLastModified;
}
