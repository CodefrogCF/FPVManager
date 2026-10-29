import 'dart:convert';

import '../../core/geo/polygon_intersections.dart';

const avalancheLevels = {
  'low': 1,
  'moderate': 2,
  'considerable': 3,
  'high': 4,
  'very_high': 5,
};
const avalancheLabels = {
  1: 'Gering',
  2: 'Mäßig',
  3: 'Erheblich',
  4: 'Groß',
  5: 'Sehr groß',
  0: 'Nicht eingestuft / unbekannt',
};

String avalancheText(Object? raw) {
  if (raw == null) return '';
  if (raw is! String || raw.length > 16000) {
    throw const FormatException('SLF-Text fehlt oder ist zu lang');
  }
  return raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();
}

DateTime avalancheDate(Object? raw) {
  if (raw is! String || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw)) {
    throw const FormatException('SLF-Zeitangabe ohne Zeitzone');
  }
  final time = DateTime.tryParse(raw);
  if (time == null) throw const FormatException('SLF-Zeitangabe ungültig');
  return time.toUtc();
}

Map<String, dynamic> parseAvalancheBulletin(String body) {
  if (body.length > 4 * 1024 * 1024) {
    throw const FormatException('SLF-Bulletin zu groß');
  }
  final json = jsonDecode(body);
  if (json is! Map ||
      json['type'] != 'FeatureCollection' ||
      json['features'] is! List ||
      json['features'].length > 200) {
    throw const FormatException('SLF: GeoJSON-FeatureCollection erwartet');
  }
  final areas = <Map<String, dynamic>>[];
  final ids = <String>{};
  var vertices = 0, textSize = 0;
  for (final raw in json['features']) {
    if (raw is! Map ||
        raw['type'] != 'Feature' ||
        raw['properties'] is! Map ||
        raw['geometry'] is! Map) {
      throw const FormatException('SLF-Gebiet ungültig');
    }
    final p = Map<String, dynamic>.from(raw['properties']);
    final id = p['bulletinID'];
    if (id is! String || id.isEmpty || id.length > 150 || !ids.add(id)) {
      throw const FormatException('SLF-Bulletin-ID fehlt / doppelt');
    }
    final published = avalancheDate(p['publicationTime']);
    final validity = p['validTime'];
    if (validity is! Map) throw const FormatException('SLF-Gültigkeit fehlt');
    final from = avalancheDate(validity['startTime']),
        until = avalancheDate(validity['endTime']);
    if (!until.isAfter(from) ||
        until.difference(from) > const Duration(days: 8)) {
      throw const FormatException('SLF-Gültigkeit ungültig');
    }
    if (p['dangerRatings'] is! List ||
        p['dangerRatings'].length > 32 ||
        p['avalancheProblems'] is! List ||
        p['avalancheProblems'].length > 32 ||
        p['regions'] is! List ||
        p['regions'].length > 300) {
      throw const FormatException('SLF-Einstufungen / Regionen ungültig');
    }
    final ratings = <Map<String, dynamic>>[],
        problems = <Map<String, dynamic>>[];
    Map<String, dynamic> rating(Map input) {
      final value =
          input['mainValue'] ?? input['dangerRatingValue'] ?? 'unknown';
      if (value is! String || value.length > 80) {
        throw const FormatException('SLF-Gefahrenstufe fehlt');
      }
      final aspects = input['aspects'] ?? const [];
      if (aspects is! List ||
          aspects.length > 16 ||
          aspects.any((a) => a is! String || a.length > 20)) {
        throw const FormatException('SLF-Exposition ungültig');
      }
      final elevation = input['elevation'];
      if (elevation != null && elevation is! Map) {
        throw const FormatException('SLF-Höhenband ungültig');
      }
      final period = input['validTimePeriod'] ?? 'unknown';
      if (period is! String || period.length > 60) {
        throw const FormatException('SLF-Tagesabschnitt fehlt');
      }
      return {
        'value': value,
        'level': avalancheLevels[value] ?? 0,
        'period': period,
        'aspects': aspects,
        'lower': avalancheText(elevation?['lowerBound']),
        'upper': avalancheText(elevation?['upperBound']),
        'subdivision': avalancheText(
          input['customData']?['CH']?['subdivision'],
        ),
      };
    }

    for (final r in p['dangerRatings']) {
      if (r is! Map) throw const FormatException('SLF-Gefahrenstufe ungültig');
      ratings.add(rating(r));
    }
    for (final r in p['avalancheProblems']) {
      if (r is! Map ||
          r['problemType'] is! String ||
          r['problemType'].length > 80) {
        throw const FormatException('SLF-Lawinenproblem ungültig');
      }
      problems.add({
        ...rating(r),
        'type': r['problemType'],
        'comment': avalancheText(r['comment']),
        'coreZone': avalancheText(r['customData']?['CH']?['coreZoneText']),
      });
    }
    final names = <String>[];
    for (final r in p['regions']) {
      if (r is! Map ||
          r['regionID'] is! String ||
          r['name'] is! String ||
          r['name'].length > 200) {
        throw const FormatException('SLF-Warnregion ungültig');
      }
      names.add(r['name']);
    }
    final geometry = Map<String, dynamic>.from(raw['geometry']);
    final coordinates = geometry['coordinates'];
    if (!{'Polygon', 'MultiPolygon'}.contains(geometry['type']) ||
        coordinates is! List) {
      throw const FormatException('SLF-Polygon erwartet');
    }
    final polygons = geometry['type'] == 'Polygon'
        ? [coordinates]
        : coordinates;
    if (polygons.isEmpty || polygons.length > 256) {
      throw const FormatException('SLF-Polygonlimit');
    }
    for (final polygon in polygons) {
      if (polygon is! List || polygon.isEmpty || polygon.length > 64) {
        throw const FormatException('SLF-Ringlimit');
      }
      for (final ring in polygon) {
        if (ring is! List ||
            ring.length < 4 ||
            (vertices += ring.length) > 20000) {
          throw const FormatException('SLF-Geometrielimit');
        }
        for (final point in ring) {
          if (point is! List ||
              point.length != 2 ||
              point.any((v) => v is! num || !v.isFinite) ||
              point[0] < 5.5 ||
              point[0] > 11 ||
              point[1] < 45.5 ||
              point[1] > 48.5) {
            throw const FormatException('SLF-Koordinate ungültig');
          }
        }
      }
    }
    final check = PolygonIntersectionIndex.fromGeoJson({
      'type': 'FeatureCollection',
      'features': [
        {'type': 'Feature', 'geometry': geometry},
      ],
    });
    if (check.unassessedFeatureCount != 0) {
      throw const FormatException('SLF-Polygon nicht vollständig prüfbar');
    }
    final sections = <String, String>{};
    for (final key in [
      'highlights',
      'snowpackStructure',
      'weatherForecast',
      'weatherReview',
      'avalancheActivity',
      'travelAdvisory',
    ]) {
      final value = p[key];
      sections[key] = value is Map
          ? avalancheText(value['comment'] ?? value['highlights'])
          : avalancheText(value);
    }
    final area = {
      'id': id,
      'name': names.take(3).join(' · '),
      'regions': names,
      'publishedUtc': published.toIso8601String(),
      'fromUtc': from.toIso8601String(),
      'untilUtc': until.toIso8601String(),
      'nextUpdateUtc': p['nextUpdate'] == null
          ? null
          : avalancheDate(p['nextUpdate']).toIso8601String(),
      'ratings': ratings,
      'problems': problems,
      'sections': sections,
      'geometry': geometry,
    };
    textSize += jsonEncode(area..remove('geometry')).length;
    area['geometry'] = geometry;
    if (textSize > 400000) {
      throw const FormatException('SLF-Textlimit überschritten');
    }
    areas.add(area);
  }
  return {'areas': areas, 'empty': areas.isEmpty};
}

String avalanchePeriod(String period) => switch (period) {
  'all_day' => 'Ganzer Tag',
  'earlier' => 'Früherer Tagesabschnitt',
  'later' => 'Späterer Tagesabschnitt',
  _ => 'Unbekannter Tagesabschnitt ($period)',
};
String avalancheRating(Map r) {
  final level = r['level'] as int;
  final height = [
    if ((r['lower'] as String).isNotEmpty) 'ab ${r['lower']} m',
    if ((r['upper'] as String).isNotEmpty) 'bis ${r['upper']} m',
  ].join(' · ');
  return '${avalancheLabels[level]}${level == 0 ? " (${r['value']})" : " ($level${r['subdivision'] == 'minus'
            ? '-'
            : r['subdivision'] == 'plus'
            ? '+'
            : ''})"} · ${avalanchePeriod(r['period'])}${height.isEmpty ? '' : '\nHöhenangabe: $height'}${(r['aspects'] as List).isEmpty ? '' : '\nExpositionen: ${(r['aspects'] as List).join(", ")}'}';
}

List<Map<String, dynamic>> avalancheFeatures(
  Map<String, dynamic> data, {
  required bool stale,
  required String period,
}) {
  return [
    for (final area in data['areas'] as List)
      _feature(area as Map, stale, period),
  ];
}

Map<String, dynamic> _feature(Map area, bool stale, String period) {
  final ratings = (area['ratings'] as List)
      .where(
        (r) =>
            period == 'all' ||
            r['period'] == 'all_day' ||
            r['period'] == period ||
            !{'all_day', 'earlier', 'later'}.contains(r['period']),
      )
      .toList();
  final unknown =
      ratings.isEmpty ||
      ratings.any(
        (r) =>
            r['level'] == 0 ||
            !{'all_day', 'earlier', 'later'}.contains(r['period']),
      );
  final level = unknown
      ? 0
      : ratings.map((r) => r['level'] as int).reduce((a, b) => a > b ? a : b);
  final detail = StringBuffer(
    '${stale ? 'Veralteter / nicht bestätigter Stand\n' : ''}WSL-Institut für Schnee- und Lawinenforschung SLF · CC BY 4.0\nPubliziert: ${area['publishedUtc']}\nGültig: ${area['fromUtc']} – ${area['untilUtc']}\nWarnregionen: ${(area['regions'] as List).join(", ")}\nKartenfarbe: ${period == 'all' ? 'höchste publizierte Stufe der Tagesübersicht' : avalanchePeriod(period)}; Höhenlagen und Expositionen beachten.\n',
  );
  for (final r in area['ratings']) {
    detail.writeln('\n${avalancheRating(r)}');
  }
  const problemNames = {
    'new_snow': 'Neuschnee',
    'wind_slab': 'Triebschnee',
    'persistent_weak_layers': 'Altschnee',
    'wet_snow': 'Nassschnee',
    'gliding_snow': 'Gleitschnee',
    'cornices': 'Wechten',
    'no_distinct_avalanche_problem': 'Kein ausgeprägtes Lawinenproblem',
  };
  for (final p in area['problems']) {
    detail.writeln(
      '\n${problemNames[p['type']] ?? 'Unbekannter Problemtyp (${p['type']})'}\n${avalancheRating(p)}\n${p['coreZone']}\n${p['comment']}',
    );
  }
  const sectionNames = {
    'highlights': 'Übersicht',
    'snowpackStructure': 'Schneedecke',
    'weatherForecast': 'Wetterprognose',
    'weatherReview': 'Wetterrückblick',
    'avalancheActivity': 'Lawinenaktivität',
    'travelAdvisory': 'Verhaltensempfehlung',
  };
  for (final entry in (area['sections'] as Map).entries) {
    if (entry.value.toString().isNotEmpty) {
      detail.writeln(
        '\n${sectionNames[entry.key] ?? entry.key}\n${entry.value}',
      );
    }
  }
  detail.writeln(
    '\nRegionale Einschätzung; ersetzt keine Beurteilung vor Ort und bestätigt weder sichere Verhältnisse noch eine Flugfreigabe. Offizielles Bulletin: https://www.slf.ch',
  );
  if (detail.length > 16000) {
    throw const FormatException('SLF-Gebietsbeschreibung zu lang');
  }
  final name = area['name'] as String;
  return {
    'id': area['id'],
    'name': name.substring(0, name.length.clamp(0, 200)),
    'detail': detail.toString(),
    'geometry': area['geometry'],
    'level': stale ? 0 : level,
    'validFromUtc': area['fromUtc'],
    'validUntilUtc': area['untilUtc'],
    'timestampUtc': area['publishedUtc'],
  };
}
