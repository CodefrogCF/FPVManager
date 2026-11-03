import 'dart:convert';

enum PreventionCategory {
  none,
  caution,
  conditionalBan,
  forestBan,
  outdoorBan,
  unknown,
}

/// Classification is based ONLY on an official measure title, never fire danger.
PreventionCategory preventionCategory(
  String? officialTitle,
) => switch (officialTitle?.trim()) {
  'Keine Massnahmen in Kraft' => PreventionCategory.none,
  'Mahnung zu sorgfältigem Umgang mit Feuer im Wald und in Waldesnähe/im Freien' =>
    PreventionCategory.caution,
  'Bedingtes Feuerverbot im Wald und in Waldesnähe/im Freien' =>
    PreventionCategory.conditionalBan,
  'Absolutes Feuerverbot im Wald und in Waldesnähe' =>
    PreventionCategory.forestBan,
  'Absolutes Feuerverbot im Freien' => PreventionCategory.outdoorBan,
  _ => PreventionCategory.unknown,
};

String preventionCategoryLabel(PreventionCategory category) =>
    switch (category) {
      PreventionCategory.none => 'Keine Massnahmen laut Quelle',
      PreventionCategory.caution => 'Mahnung',
      PreventionCategory.conditionalBan => 'Bedingtes Feuerverbot',
      PreventionCategory.forestBan =>
        'Absolutes Feuerverbot: Wald und Waldesnähe',
      PreventionCategory.outdoorBan => 'Absolutes Feuerverbot: im Freien',
      PreventionCategory.unknown => 'Massnahme nicht klassifizierbar',
    };

/// A Swiss publication date is kept as a source-local calendar date. The API
/// does not publish a timezone, so it must not be described as an exact UTC time.
DateTime? parseSwissCalendarDate(Object? value) {
  if (value == null) return null;
  if (value is num) return null;
  final text = value.toString().trim();
  final swiss = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2}))?',
  );
  final match = swiss.firstMatch(text);
  if (match != null) {
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final hour = int.tryParse(match[4] ?? '0') ?? 0;
    final minute = int.tryParse(match[5] ?? '0') ?? 0;
    final date = DateTime.utc(year, month, day, hour, minute);
    return date.year == year &&
            date.month == month &&
            date.day == day &&
            date.hour == hour &&
            date.minute == minute
        ? date
        : null;
  }
  final parsed = DateTime.tryParse(text);
  return parsed?.toUtc();
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.length > 1600 ? null : text;
}

/// A measure's validity and the map's publication date are different concepts.
class PreventionMeasure {
  const PreventionMeasure({
    required this.sourceId,
    required this.title,
    required this.category,
    this.description,
    this.canton,
    this.region,
    this.validFrom,
    this.validUntil,
    this.validFromRaw,
    this.validUntilRaw,
  });

  final String sourceId;
  final String title;
  final PreventionCategory category;
  final String? description, canton, region;
  final DateTime? validFrom, validUntil;
  final String? validFromRaw, validUntilRaw;

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'title': title,
    'category': category.name,
    'description': description,
    'canton': canton,
    'region': region,
    'validFrom': validFromRaw,
    'validUntil': validUntilRaw,
  };

  factory PreventionMeasure.fromJson(Map<String, dynamic> json) =>
      PreventionMeasure(
        sourceId: json['sourceId'] as String,
        title: json['title'] as String,
        // Do not trust categories from saved JSON: always reclassify the title.
        category: preventionCategory(json['title'] as String?),
        description: json['description'] as String?,
        canton: json['canton'] as String?,
        region: json['region'] as String?,
        validFromRaw: json['validFrom'] as String?,
        validUntilRaw: json['validUntil'] as String?,
        validFrom: parseSwissCalendarDate(json['validFrom']),
        validUntil: parseSwissCalendarDate(json['validUntil']),
      );
}

class PreventionSnapshot {
  const PreventionSnapshot({
    required this.latitude,
    required this.longitude,
    required this.fetchedUtc,
    required this.measures,
    this.publicationRaw,
    this.truncated = false,
    this.fromCache = false,
    this.refreshFailed = false,
  });
  final double latitude, longitude;
  final DateTime fetchedUtc;
  final List<PreventionMeasure> measures;
  final String? publicationRaw;
  final bool truncated, fromCache, refreshFailed;
  DateTime? get publicationCalendar => parseSwissCalendarDate(publicationRaw);

  /// Absent/undated/old publication is UNKNOWN, not 'no ban'.
  bool isOutdated(DateTime now) {
    final utc = now.toUtc();
    final age = utc.difference(fetchedUtc);
    final pub = publicationCalendar;
    if (refreshFailed ||
        age.isNegative ||
        age > const Duration(hours: 6) ||
        pub == null ||
        pub.isAfter(utc.add(const Duration(hours: 2))) ||
        utc.difference(pub) > const Duration(hours: 48)) {
      return true;
    }
    return false;
  }

  String freshnessLabel(DateTime now) {
    if (refreshFailed) return 'Aktualisierung fehlgeschlagen';
    if (publicationCalendar == null) return 'Ohne Publikationsdatum';
    if (isOutdated(now)) return 'Veralteter Datenstand';
    return 'Datierter Quellenstand, nicht rechtsverbindlich';
  }

  PreventionSnapshot cached({bool failed = false}) => PreventionSnapshot(
    latitude: latitude,
    longitude: longitude,
    fetchedUtc: fetchedUtc,
    measures: measures,
    publicationRaw: publicationRaw,
    truncated: truncated,
    fromCache: true,
    refreshFailed: failed,
  );

  String encode() => jsonEncode({
    'lat': latitude,
    'lon': longitude,
    'fetched': fetchedUtc.toIso8601String(),
    'publication': publicationRaw,
    'truncated': truncated,
    'measures': measures.map((m) => m.toJson()).toList(),
  });

  factory PreventionSnapshot.decode(String value) {
    final json = Map<String, dynamic>.from(jsonDecode(value) as Map);
    final raw = json['measures'] as List;
    if (raw.length > 50) throw const FormatException('Invalid measure cache');
    return PreventionSnapshot(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      fetchedUtc: DateTime.parse(json['fetched'] as String).toUtc(),
      publicationRaw: json['publication'] as String?,
      truncated: json['truncated'] == true,
      measures: List.unmodifiable(
        raw.map(
          (e) =>
              PreventionMeasure.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
    );
  }
}

/// GeoAdmin Identify returns polygons covering the requested WGS84 point.
/// Overlapping regional/cantonal records must not be collapsed into one rule.
PreventionSnapshot parsePreventionIdentify(
  String body, {
  required double latitude,
  required double longitude,
  required DateTime fetchedUtc,
  String? publicationRaw,
}) {
  final document = jsonDecode(body);
  if (document is! Map || document['results'] is! List) {
    throw const FormatException('Invalid BAFU Identify response');
  }
  final results = document['results'] as List;
  if (results.length > 200) {
    throw const FormatException('BAFU response exceeds limit');
  }
  final measures = <PreventionMeasure>[];
  final seen = <String>{};
  for (final raw in results) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    if (item['layerBodId'] != null && item['layerBodId'] != preventionLayerId) {
      continue;
    }
    final fields = item['properties'] ?? item['attributes'];
    if (fields is! Map) continue;
    final properties = Map<String, dynamic>.from(fields);
    final title = _text(properties['title_de']);
    final id = _text(item['featureId'] ?? item['id'] ?? properties['id']);
    if (title == null || id == null) continue;
    final canton = _text(properties['canton']);
    final region = _text(properties['name_de']);
    final unique = '$id|$canton|$region';
    if (!seen.add(unique)) continue;
    final from = _text(properties['valid_from']);
    final until = _text(properties['valid_until']);
    measures.add(
      PreventionMeasure(
        sourceId: id,
        title: title,
        category: preventionCategory(title),
        canton: canton,
        region: region,
        description: _text(properties['description_de']),
        validFromRaw: from,
        validUntilRaw: until,
        validFrom: parseSwissCalendarDate(from),
        validUntil: parseSwissCalendarDate(until),
      ),
    );
    if (measures.length == 50) break;
  }
  return PreventionSnapshot(
    latitude: latitude,
    longitude: longitude,
    fetchedUtc: fetchedUtc.toUtc(),
    measures: List.unmodifiable(measures),
    publicationRaw: publicationRaw,
    truncated: results.length >= 50,
  );
}

const preventionLayerId =
    'ch.bafu.gefahren-waldbrand_praeventionsmassnahmen_kantone';

/// Legend provides an optional publication/data-status calendar value.
/// If it changes format, this returns null rather than inventing a timestamp.
String? parsePreventionLegendPublication(String html) {
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  final match = RegExp(
    r'(?:Datenstand|Data status|État des données|Stato dei dati)\s*:?\s*(\d{1,2}\.\d{1,2}\.\d{4}(?:\s+\d{1,2}:\d{2})?)',
    caseSensitive: false,
  ).firstMatch(text);
  return match == null ? null : match[1];
}
