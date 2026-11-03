import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_models.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_service.dart';
import 'package:fpvmanager/features/mobility/mobile_sites/mobile_site_stac.dart';

void main() {
  final area = MobileSiteArea(46.948, 7.44, 2000);

  test(
    'GeoAdmin identify uses bounded LV95 rectangle, official mobile-site layer',
    () {
      final uri = mobileSitesIdentifyUrl(area);
      expect(uri.host, 'api3.geo.admin.ch');
      expect(uri.queryParameters['layers'], 'all:$mobileSiteCollectionId');
      expect(uri.queryParameters['sr'], '2056');
      expect(uri.queryParameters['limit'], '200');
      final coords = uri.queryParameters['geometry']!
          .split(',')
          .map(double.parse)
          .toList();
      expect(coords[2] - coords[0], 4000);
      expect(coords[3] - coords[1], 4000);
      expect(() => MobileSiteArea(46.9, 7.4, 25000), throwsFormatException);
    },
  );

  test(
    'LV95 origin, technology and power class preserved without mast height',
    () {
      final body = jsonEncode({
        'results': [
          {
            'featureId': 101,
            'attributes': {
              'station': 'Swisscom TEST',
              'koord': '2600000,1200000',
              'typ_de': 'Outdoor > 6 Werp',
              'techno_de': 'Technologie 4G,5G',
              'power_de': 'Leistungsklasse : mittel (bis 5000 W)',
            },
          },
          {
            'featureId': 101,
            'attributes': {'station': 'duplicate', 'koord': '2600000,1200000'},
          },
        ],
      });
      final sites = parseMobileSites(body);
      expect(sites, hasLength(1));
      expect(sites.single.id, '101');
      expect(sites.single.sourceEasting, 2600000);
      expect(sites.single.sourceNorthing, 1200000);
      expect(sites.single.latitude, closeTo(46.95, .02));
      expect(sites.single.longitude, closeTo(7.44, .02));
      expect(sites.single.objectHeightMeters, isNull);
      expect(sites.single.technology, contains('5G'));
      expect(sites.single.powerClass, contains('mittel'));
    },
  );

  test('missing station labels and technology remain explicitly unknown', () {
    final sites = parseMobileSites(
      jsonEncode({
        'results': [
          {
            'featureId': 'missing',
            'geometry': {'x': 2600000, 'y': 1200000},
            'attributes': {},
          },
          {
            'featureId': 'bad',
            'geometry': {'x': 0, 'y': 0},
            'attributes': {},
          },
        ],
      }),
    );
    expect(sites, hasLength(1));
    expect(sites.single.station, 'Mobilfunkstation missing');
    expect(sites.single.technology, isNull);
    expect(sites.single.sourceEasting, 2600000);
  });

  test(
    'invalid/crowded payload rejected without treating it as empty coverage',
    () {
      expect(() => parseMobileSites('{}'), throwsFormatException);
      expect(
        () => parseMobileSites(jsonEncode({'results': List.filled(201, {})})),
        throwsFormatException,
      );
    },
  );

  test(
    'STAC collection and item assets discovered, license and dates retained',
    () {
      final collection = jsonEncode({
        'id': mobileSiteCollectionId,
        'license': 'proprietary',
        'updated': '2026-11-02T12:00:00Z',
        'links': [
          {
            'rel': 'license',
            'href': 'https://opendata.swiss/en/terms-of-use/#terms_by',
          },
        ],
        'assets': {},
      });
      final items = jsonEncode({
        'features': [
          {
            'collection': mobileSiteCollectionId,
            'properties': {'datetime': '2026-11-01T00:00:00Z'},
            'assets': {
              'sites.gpkg': {
                'href': 'https://data.geo.admin.ch/sites.gpkg',
                'type': 'application/geopackage+sqlite3',
              },
              'sites.geojson': {
                'href': 'https://data.geo.admin.ch/sites.geojson',
                'type': 'application/geo+json',
              },
              'evil': {'href': 'https://not-official.invalid/steal.csv'},
            },
          },
        ],
      });
      final catalog = parseMobileSiteStac(collection, items);
      expect(catalog.licence, 'proprietary');
      expect(catalog.termsUrl!.host, 'opendata.swiss');
      expect(catalog.updatedUtc!.year, 2026);
      expect(catalog.assets, hasLength(2));
      expect(catalog.assets.where((a) => a.supported), hasLength(1));
      expect(catalog.assets.where((a) => !a.supported), hasLength(1));
      expect(() => parseMobileSiteStac('{}', items), throwsFormatException);
    },
  );
}
