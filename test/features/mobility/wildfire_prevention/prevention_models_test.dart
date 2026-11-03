import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/wildfire_prevention/prevention_models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);

  test('all five official titles map, unknown source titles do not infer a ban', () {
    const titles = {
      'Keine Massnahmen in Kraft': PreventionCategory.none,
      'Mahnung zu sorgfältigem Umgang mit Feuer im Wald und in Waldesnähe/im Freien':
          PreventionCategory.caution,
      'Bedingtes Feuerverbot im Wald und in Waldesnähe/im Freien':
          PreventionCategory.conditionalBan,
      'Absolutes Feuerverbot im Wald und in Waldesnähe':
          PreventionCategory.forestBan,
      'Absolutes Feuerverbot im Freien': PreventionCategory.outdoorBan,
    };
    for (final entry in titles.entries) {
      expect(preventionCategory(entry.key), entry.value);
    }
    expect(preventionCategory('Gefahr sehr gross'), PreventionCategory.unknown);
    expect(
      preventionCategory('absolutes Feuerverbot'),
      PreventionCategory.unknown,
    );
  });

  test('GeoAdmin Identify retains overlaps, canton, official description and validity', () {
    final raw = jsonEncode({
      'results': [
        {
          'layerBodId': preventionLayerId,
          'featureId': 101,
          'properties': {
            'title_de':
                'Bedingtes Feuerverbot im Wald und in Waldesnähe/im Freien',
            'description_de':
                'Feuer nur auf festeingerichteten Feuerstellen toleriert',
            'canton': 'BE',
            'name_de': 'Grimselregion (BE)',
            'valid_from': '22.09.2026',
          },
        },
        {
          'layerBodId': preventionLayerId,
          'featureId': 101,
          'properties': {
            'title_de':
                'Bedingtes Feuerverbot im Wald und in Waldesnähe/im Freien',
            'canton': 'BE',
            'name_de': 'Grimselregion (BE)',
          },
        },
        {
          'layerBodId': preventionLayerId,
          'featureId': '202',
          'attributes': {
            'title_de': 'Absolutes Feuerverbot im Freien',
            'canton': 'BE',
            'name_de': 'Innertkirchen/ Gadmen (BE)',
          },
        },
      ],
    });
    final snapshot = parsePreventionIdentify(
      raw,
      latitude: 46.7,
      longitude: 8.3,
      fetchedUtc: now,
      publicationRaw: '02.11.2026 12:00',
    );
    expect(snapshot.measures, hasLength(2));
    expect(snapshot.measures[0].category, PreventionCategory.conditionalBan);
    expect(snapshot.measures[0].canton, 'BE');
    expect(snapshot.measures[0].validFrom, DateTime.utc(2026, 9, 22));
    expect(snapshot.measures[1].category, PreventionCategory.outdoorBan);
    expect(snapshot.measures[1].validFrom, isNull);
    expect(snapshot.publicationCalendar, DateTime.utc(2026, 11, 2, 12));
    expect(snapshot.isOutdated(now), isFalse);
    final reloaded = PreventionSnapshot.decode(snapshot.encode());
    expect(reloaded.measures, hasLength(2));
    expect(reloaded.measures[1].category, PreventionCategory.outdoorBan);
    expect(reloaded.publicationRaw, '02.11.2026 12:00');
  });

  test(
    'missing or old publication is unknown, even if source reports no measures',
    () {
      final empty = parsePreventionIdentify(
        '{"results":[]}',
        latitude: 47.3,
        longitude: 8.5,
        fetchedUtc: now,
      );
      expect(empty.measures, isEmpty);
      expect(empty.isOutdated(now), isTrue);
      expect(empty.freshnessLabel(now), 'Ohne Publikationsdatum');
      final none = parsePreventionIdentify(
        jsonEncode({
          'results': [
            {
              'featureId': 'A',
              'properties': {'title_de': 'Keine Massnahmen in Kraft'},
            },
          ],
        }),
        latitude: 47.3,
        longitude: 8.5,
        fetchedUtc: now,
        publicationRaw: '01.10.2026 12:00',
      );
      expect(none.measures.single.category, PreventionCategory.none);
      expect(none.isOutdated(now), isTrue);
      expect(none.freshnessLabel(now), 'Veralteter Datenstand');
      expect(none.cached(failed: true).isOutdated(now), isTrue);
      expect(
        none.cached(failed: true).freshnessLabel(now),
        'Aktualisierung fehlgeschlagen',
      );
      expect(parseSwissCalendarDate('32.10.2026'), isNull);
      expect(parseSwissCalendarDate(null), isNull);
    },
  );

  test('legend publication date is separate from feature validity dates', () {
    expect(
      parsePreventionLegendPublication(
        '<tr><th>Datenstand</th><td>02.11.2026 12:00</td></tr>',
      ),
      '02.11.2026 12:00',
    );
    expect(
      parsePreventionLegendPublication('Data status: 30.10.2026 10:00'),
      '30.10.2026 10:00',
    );
    expect(
      parsePreventionLegendPublication('source date not published'),
      isNull,
    );
  });

  test('bounded payload and invalid schema are rejected', () {
    expect(
      () => parsePreventionIdentify(
        '{}',
        latitude: 47,
        longitude: 8,
        fetchedUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => parsePreventionIdentify(
        jsonEncode({'results': List.filled(201, {})}),
        latitude: 47,
        longitude: 8,
        fetchedUtc: now,
      ),
      throwsFormatException,
    );
  });
}
