import '../../../core/osint/osint_dataset.dart';

/// Source: MeteoSwiss, automatic pollen network (hourly station averages).
enum PollenTaxon {
  alder('kaalnu', 'Alder / Erle'),
  ash('kafrax', 'Ash / Esche'),
  birch('kabetu', 'Birch / Birke'),
  beech('kafagu', 'Beech / Buche'),
  hazel('kacory', 'Hazel / Hasel'),
  oak('kaquer', 'Oak / Eiche'),
  grasses('khpoac', 'Grasses / Gräser');

  const PollenTaxon(this.parameterPrefix, this.label);
  final String parameterPrefix;
  final String label;
  String get hourlyCode => '${parameterPrefix}h0';
  static PollenTaxon? fromHourlyCode(String code) {
    for (final type in values) {
      if (type.hourlyCode == code.toLowerCase()) {
        return type;
      }
    }
    return null;
  }
}

enum PollenMeasurementMethod { automatic, manual }

/// Manual historical daily samples must not be joined to automatic hourly data.
PollenMeasurementMethod pollenMethodAt(DateTime utc) =>
    utc.toUtc().isBefore(DateTime.utc(2023))
    ? PollenMeasurementMethod.manual
    : PollenMeasurementMethod.automatic;

class PollenStation {
  const PollenStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.canton,
    this.heightMeters,
    this.detailsUrl,
  });
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? canton;
  final double? heightMeters;
  final Uri? detailsUrl;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'canton': canton,
    'heightMeters': heightMeters,
    'detailsUrl': detailsUrl?.toString(),
  };

  factory PollenStation.fromJson(Map<String, dynamic> json) => PollenStation(
    id: json['id'] as String,
    name: json['name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    canton: json['canton'] as String?,
    heightMeters: (json['heightMeters'] as num?)?.toDouble(),
    detailsUrl: json['detailsUrl'] == null
        ? null
        : Uri.tryParse(json['detailsUrl'] as String),
  );
}

class PollenSample {
  const PollenSample({
    required this.timeUtc,
    required this.values,
    this.method = PollenMeasurementMethod.automatic,
  });
  final DateTime timeUtc;
  // Null = no observation; zero is a valid measurement.
  final Map<PollenTaxon, double?> values;
  final PollenMeasurementMethod method;

  Map<String, Object?> toJson() => {
    'timeUtc': timeUtc.toUtc().toIso8601String(),
    'method': method.name,
    'values': {
      for (final taxon in PollenTaxon.values) taxon.name: values[taxon],
    },
  };

  factory PollenSample.fromJson(Map<String, dynamic> json) {
    final raw = json['values'] as Map<String, dynamic>;
    return PollenSample(
      timeUtc: DateTime.parse(json['timeUtc'] as String).toUtc(),
      method: PollenMeasurementMethod.values.byName(json['method'] as String),
      values: {
        for (final taxon in PollenTaxon.values)
          taxon: (raw[taxon.name] as num?)?.toDouble(),
      },
    );
  }
}

class PollenSnapshot {
  const PollenSnapshot({
    required this.station,
    required this.samples,
    required this.fetchedUtc,
    required this.assetUrl,
    this.publishedUtc,
    this.fromCache = false,
    this.refreshFailed = false,
    this.unknownParameters = const [],
  });
  final PollenStation station;
  final List<PollenSample> samples; // Up to 24 hours, newest first.
  final DateTime fetchedUtc;
  final DateTime? publishedUtc;
  final Uri assetUrl;
  final bool fromCache;
  final bool refreshFailed;
  final List<String> unknownParameters;

  DateTime? get latestObservedUtc =>
      samples.isEmpty ? null : samples.first.timeUtc;
  static const cacheLifetime = Duration(minutes: 20);
  static const observationLifetime = Duration(hours: 2);

  OsintFreshness freshnessAt(DateTime time) {
    final now = time.toUtc();
    final latest = latestObservedUtc;
    if (now.isBefore(fetchedUtc) || (latest != null && now.isBefore(latest))) {
      return OsintFreshness.clockSkew;
    }
    if (refreshFailed ||
        latest == null ||
        now.difference(fetchedUtc) > cacheLifetime ||
        now.difference(latest) > observationLifetime) {
      return OsintFreshness.stale;
    }
    return OsintFreshness.fresh;
  }

  PollenSnapshot cached({bool failed = false}) => PollenSnapshot(
    station: station,
    samples: samples,
    fetchedUtc: fetchedUtc,
    assetUrl: assetUrl,
    publishedUtc: publishedUtc,
    fromCache: true,
    refreshFailed: failed || refreshFailed,
    unknownParameters: unknownParameters,
  );

  Map<String, Object?> toJson() => {
    'station': station.toJson(),
    'samples': samples.map((s) => s.toJson()).toList(),
    'fetchedUtc': fetchedUtc.toUtc().toIso8601String(),
    'publishedUtc': publishedUtc?.toUtc().toIso8601String(),
    'assetUrl': assetUrl.toString(),
    'unknownParameters': unknownParameters,
  };

  factory PollenSnapshot.fromJson(Map<String, dynamic> json) => PollenSnapshot(
    station: PollenStation.fromJson(json['station'] as Map<String, dynamic>),
    samples: (json['samples'] as List<dynamic>)
        .map((e) => PollenSample.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    fetchedUtc: DateTime.parse(json['fetchedUtc'] as String).toUtc(),
    publishedUtc: json['publishedUtc'] == null
        ? null
        : DateTime.parse(json['publishedUtc'] as String).toUtc(),
    assetUrl: Uri.parse(json['assetUrl'] as String),
    unknownParameters: (json['unknownParameters'] as List<dynamic>? ?? [])
        .cast<String>(),
  );
}
