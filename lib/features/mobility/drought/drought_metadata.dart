import 'dart:convert';

import '../../../core/osint/osint_provider_state.dart';

const swissEoVhiCollection = 'ch.swisstopo.swisseo_vhi_v100';
const droughtWarningLayer = 'ch.bafu.trockenheitswarnkarte';
const droughtIndexLayer = 'ch.bafu.trockenheitsindex';

/// The source defines CDI steps as relative *weeks*, not absolute dates.
/// Positive steps are forecast products, never measurements or legal orders.
enum DroughtTimeStep {
  previous(0, 'Vorwoche · rückblickender Index', false),
  current(1, 'Aktuelle Woche · kombinierter Index', false),
  next(2, 'Nächste Woche · Prognose', true),
  inTwoWeeks(3, 'In 2 Wochen · Prognose', true),
  inThreeWeeks(4, 'In 3 Wochen · Prognose', true);

  const DroughtTimeStep(this.value, this.label, this.isForecast);
  final int value;
  final String label;
  final bool isForecast;
}

/// STAC observation and publication timestamps are separate from the
/// moment a device downloaded metadata; none is inferred from the other.
class DroughtVhiMetadata {
  const DroughtVhiMetadata({
    required this.fetchedUtc,
    required this.collection,
    this.observedUtc,
    this.publishedUtc,
    this.periodStartUtc,
    this.periodEndUtc,
    this.fromCache = false,
    this.refreshFailed = false,
    this.incompletePage = false,
  });

  final DateTime fetchedUtc;
  final String collection;
  final DateTime? observedUtc, publishedUtc, periodStartUtc, periodEndUtc;
  final bool fromCache, refreshFailed, incompletePage;

  /// Observation age is checked independently from the local HTTP age.
  OsintDataState state(DateTime now) {
    final utc = now.toUtc();
    if (refreshFailed) {
      return OsintDataState.refreshFailed;
    }
    if (utc.isBefore(fetchedUtc)) {
      return OsintDataState.clockSkew;
    }
    if (observedUtc == null || observedUtc!.isAfter(utc)) {
      return OsintDataState.unavailable;
    }
    if (utc.difference(observedUtc!) > const Duration(days: 10) ||
        utc.difference(fetchedUtc) > const Duration(hours: 12)) {
      return OsintDataState.stale;
    }
    return OsintDataState.fresh;
  }

  DroughtVhiMetadata asCached({bool failed = false}) => DroughtVhiMetadata(
    fetchedUtc: fetchedUtc,
    collection: collection,
    observedUtc: observedUtc,
    publishedUtc: publishedUtc,
    periodStartUtc: periodStartUtc,
    periodEndUtc: periodEndUtc,
    fromCache: true,
    refreshFailed: failed,
    incompletePage: incompletePage,
  );

  Map<String, Object?> toJson() => {
    'collection': collection,
    'fetchedUtc': fetchedUtc.toIso8601String(),
    'observedUtc': observedUtc?.toIso8601String(),
    'publishedUtc': publishedUtc?.toIso8601String(),
    'periodStartUtc': periodStartUtc?.toIso8601String(),
    'periodEndUtc': periodEndUtc?.toIso8601String(),
    'incompletePage': incompletePage,
  };

  String encode() => jsonEncode(toJson());

  factory DroughtVhiMetadata.decode(String value) {
    if (value.length > 12000) {
      throw const FormatException('Cache too large');
    }
    final data = jsonDecode(value);
    if (data is! Map ||
        data['collection'] != swissEoVhiCollection ||
        data['fetchedUtc'] is! String) {
      throw const FormatException('Invalid saved VHI metadata');
    }
    final fetched = DateTime.tryParse(data['fetchedUtc'] as String)?.toUtc();
    if (fetched == null) {
      throw const FormatException('Invalid saved fetch time');
    }
    return DroughtVhiMetadata(
      collection: swissEoVhiCollection,
      fetchedUtc: fetched,
      observedUtc: _date(data['observedUtc']),
      publishedUtc: _date(data['publishedUtc']),
      periodStartUtc: _date(data['periodStartUtc']),
      periodEndUtc: _date(data['periodEndUtc']),
      incompletePage: data['incompletePage'] == true,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String || value.length > 64) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// Only STAC's item properties describe an observation. Collection 'updated',
/// HTTP Last-Modified and fetchedUtc must not masquerade as observation dates.
/// Never decode raster values or fabricate data coverage from a STAC page.
DroughtVhiMetadata parseDroughtVhiStac(
  String collectionJson,
  String itemsJson, {
  required DateTime fetchedUtc,
}) {
  if (collectionJson.length > 100000 || itemsJson.length > 600000) {
    throw const FormatException('STAC metadata exceeds size limit');
  }
  final collection = jsonDecode(collectionJson);
  final page = jsonDecode(itemsJson);
  if (collection is! Map ||
      collection['id'] != swissEoVhiCollection ||
      page is! Map ||
      page['features'] is! List) {
    throw const FormatException('Unrecognized swissEO VHI STAC response');
  }
  final features = page['features'] as List;
  if (features.length > 12) {
    throw const FormatException('Too many STAC items');
  }
  DateTime? observed, published, first, last;
  for (final item in features) {
    if (item is! Map ||
        item['collection'] != swissEoVhiCollection ||
        item['properties'] is! Map) {
      continue;
    }
    final props = item['properties'] as Map;
    final start = _date(props['start_datetime']);
    final end = _date(props['end_datetime']);
    final stamp = _date(props['datetime']) ?? end;
    if (stamp == null) {
      continue;
    }
    if (observed == null || stamp.isAfter(observed)) {
      observed = stamp;
      published = _date(props['updated']) ?? _date(props['created']);
      first = start;
      last = end;
    }
  }
  return DroughtVhiMetadata(
    collection: swissEoVhiCollection,
    fetchedUtc: fetchedUtc.toUtc(),
    observedUtc: observed,
    publishedUtc: published,
    periodStartUtc: first,
    periodEndUtc: last,
    incompletePage:
        features.length == 12 ||
        page['links'] is List &&
            (page['links'] as List).any((e) => e is Map && e['rel'] == 'next'),
  );
}
