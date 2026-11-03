import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_models.dart';
import 'package:fpvmanager/features/mobility/osm_poi/osm_poi_service.dart';

void main() {
  final search = OsmPoiSearch(
    latitude: 47.4,
    longitude: 8.5,
    radiusMeters: 500,
    categories: {OsmPoiCategory.drinkingWater, OsmPoiCategory.benches},
  );

  test('query only contains selected category filters and a bounded area', () {
    final query = buildOverpassQuery(search);
    expect(query, contains('around:500,47.40000,8.50000'));
    expect(query, contains('"amenity"="bench"'));
    expect(query, contains('"amenity"="drinking_water"'));
    expect(query, isNot(contains('playground')));
    expect(query, contains('out center 301'));
    expect(
      () => OsmPoiSearch(
        latitude: 47,
        longitude: 8,
        radiusMeters: 500000,
        categories: {OsmPoiCategory.toilets},
      ),
      throwsFormatException,
    );
    expect(
      () => OsmPoiSearch(
        latitude: 47,
        longitude: 8,
        radiusMeters: 500,
        categories: {},
      ),
      throwsFormatException,
    );
  });

  test('deduplicates nodes/ways/relations and retains only provided OSM attributes', () {
    final data = jsonEncode({
      'elements': [
        {
          'type': 'node',
          'id': 10,
          'lat': 47.4,
          'lon': 8.5,
          'tags': {
            'amenity': 'bench',
            'name': 'Parkbank',
            'access': 'yes',
            'wheelchair': 'yes',
          },
        },
        {
          'type': 'node',
          'id': 10,
          'lat': 47.4,
          'lon': 8.5,
          'tags': {'amenity': 'bench'},
        },
        {
          'type': 'way',
          'id': 10,
          'center': {'lat': 47.401, 'lon': 8.501},
          'tags': {'amenity': 'drinking_water', 'opening_hours': '24/7'},
        },
        {
          'type': 'relation',
          'id': 9,
          'tags': {'amenity': 'bench'},
        },
        {'type': 'node', 'id': 11, 'lat': 47.401, 'lon': 8.502},
        {
          'type': 'node',
          'id': 12,
          'lat': 47.402,
          'lon': 8.503,
          'tags': {'leisure': 'playground'},
        },
      ],
    });
    final parsed = parseOverpassPois(data, search);
    expect(parsed.pois, hasLength(2));
    expect(parsed.truncated, isFalse);
    expect(parsed.pois[0].reference, 'node/10');
    expect(parsed.pois[0].suppliedDetails, {
      'access': 'yes',
      'wheelchair': 'yes',
    });
    expect(
      parsed.pois[0].suppliedDetails.containsKey('opening_hours'),
      isFalse,
    );
    expect(parsed.pois[1].reference, 'way/10');
    expect(parsed.pois[1].latitude, 47.401);
    expect(parsed.pois[1].suppliedDetails['opening_hours'], '24/7');
    expect(
      parsed.pois[1].sourceUrl.toString(),
      'https://www.openstreetmap.org/way/10',
    );
  });

  test('server truncation and oversized payloads are explicit', () {
    final entries = [
      for (var i = 1; i <= 301; i++)
        {
          'type': 'node',
          'id': i,
          'lat': 47.4,
          'lon': 8.5,
          'tags': {'amenity': 'bench'},
        },
    ];
    final parsed = parseOverpassPois(jsonEncode({'elements': entries}), search);
    expect(parsed.pois.length, 300);
    expect(parsed.truncated, isTrue);
    expect(
      () => parseOverpassPois('{"elements":"not an array"}', search),
      throwsFormatException,
    );
    expect(
      () => parseOverpassPois(
        '{"elements":[],"remark":"runtime error: timed out"}',
        search,
      ),
      throwsFormatException,
    );
    expect(
      () => parseOverpassPois(List.filled(450001, 'x').join(), search),
      throwsFormatException,
    );
  });

  test('snapshot is bounded, serializes date and rejects corrupt metadata', () {
    final snapshot = OsmPoiSnapshot(
      search: search,
      fetchedAtUtc: DateTime.utc(2026, 11, 3),
      pois: const [],
      truncated: false,
    );
    final reopened = OsmPoiSnapshot.decode(snapshot.encode());
    expect(reopened.fetchedAtUtc, DateTime.utc(2026, 11, 3));
    expect(reopened.isOutdated(DateTime.utc(2026, 11, 5)), isTrue);
    expect(
      () => OsmPoiSnapshot.decode('{"version":2,"pois":[]}'),
      throwsFormatException,
    );
  });
}
