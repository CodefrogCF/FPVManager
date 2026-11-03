import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_models.dart';
import 'package:fpvmanager/features/mobility/shared_mobility/shared_mobility_parser.dart';

void main() {
  final area = SharedMobilityArea(latitude: 47.50024, longitude: 8.72334);
  final now = DateTime.utc(2026, 11, 3, 17);
  Map<String, Object?> item(String id, Map<String, Object?> attributes) => {
    'id': id,
    'geometry': {
      'x': 8.7234,
      'y': 47.5003,
      'spatialReference': {'wkid': 4326},
    },
    'attributes': {
      'id': id,
      'provider_id': 'demo',
      'provider_name': 'Demo',
      ...attributes,
    },
  };

  test('real REST EsriJSON layout: station, free-floating, duplicates and missing tags', () {
    final json = jsonEncode([
      item('station-1', {
        'pickup_type': 'station_based',
        'station_name': 'Hauptbahnhof',
        'station_status_installed': true,
        'station_status_renting': true,
        'station_status_num_vehicle_available': 2,
        'vehicle_type': ['Car', 'Car', 'E-Car'],
      }),
      item('station-1', {'pickup_type': 'station_based'}),
      item('vehicle-1', {
        'pickup_type': 'free_floating',
        'vehicle_type': ['E-Scooter'],
        'available': true,
        'vehicle_status_reserved': true,
        'vehicle_status_disabled': false,
        'provider_apps_ios_store_uri': 'https://apps.apple.com/abc',
      }),
      item('vehicle-2', {
        'pickup_type': 'free_floating',
        'available': true,
        'vehicle_status_reserved': false,
        'vehicle_status_disabled': true,
      }),
      item('vehicle-3', {'pickup_type': 'free_floating'}),
      {
        'id': 'bad',
        'geometry': {'x': 8.72, 'y': 47.50},
      },
      {
        'id': 'outside',
        'geometry': {'x': 9.9, 'y': 47.5},
        'attributes': {'provider_id': 'demo', 'id': 'outside'},
      },
    ]);
    final result = parseSharedMobilityResponse(json, area, now);
    expect(result.offers, hasLength(4));
    expect(result.offers.first.vehicleTypes, ['Car', 'E-Car']);
    expect(result.offers.first.availableCount, 2);
    expect(result.offers.first.reportedStatus, SharedMobilityStatus.available);
    expect(result.offers[1].reportedStatus, SharedMobilityStatus.reserved);
    expect(result.offers[2].reportedStatus, SharedMobilityStatus.disabled);
    expect(result.offers[3].reportedStatus, SharedMobilityStatus.unknown);
    expect(result.offers[1].operatorUrl, 'https://apps.apple.com/abc');
    expect(
      result.status(result.offers.first, now),
      SharedMobilityStatus.unknown,
      reason: 'REST does not provide a documented TTL/publication time',
    );
  });

  test('station without rentable vehicles is not available', () {
    final response = jsonEncode([
      item('empty', {
        'pickup_type': 'station_based',
        'station_status_renting': false,
        'station_status_num_vehicle_available': 0,
        'available': true,
      }),
    ]);
    final result = parseSharedMobilityResponse(response, area, now);
    expect(
      result.offers.single.reportedStatus,
      SharedMobilityStatus.unavailable,
    );
  });

  test('rejects unsupported geometry, unsafe links and oversized payloads', () {
    final json = jsonEncode([
      {
        'geometry': {
          'x': 8.72,
          'y': 47.5,
          'spatialReference': {'wkid': 2056},
        },
        'attributes': {'id': 'a', 'provider_id': 'demo'},
      },
      item('b', {'provider_url': 'javascript:alert(1)'}),
    ]);
    final snap = parseSharedMobilityResponse(json, area, now);
    expect(snap.offers, hasLength(1));
    expect(snap.offers.single.operatorUrl, isNull);
    expect(
      () => parseSharedMobilityResponse(
        List.filled(1100001, 'x').join(),
        area,
        now,
      ),
      throwsFormatException,
    );
  });

  for (final version in ['2.0', '2.3']) {
    test('GBFS $version station/free-bike feed normalization and TTL', () {
      final raw = jsonEncode({
        'version': version,
        'last_updated': now.millisecondsSinceEpoch ~/ 1000,
        'ttl': 60,
        'data': {
          'system_information': {'system_id': 'bike_system', 'name': 'Bikes'},
          'station_information': {
            'stations': [
              {
                'station_id': 'station-a',
                'lat': 47.5002,
                'lon': 8.7233,
                'name': 'Example',
                'rental_uris': {'android': 'https://example.org/rent'},
              },
            ],
          },
          'station_status': {
            'stations': [
              {
                'station_id': 'station-a',
                'num_bikes_available': 0,
                'is_installed': true,
                'is_renting': true,
                'last_reported': now.millisecondsSinceEpoch ~/ 1000,
              },
            ],
          },
          'vehicle_types': {
            'vehicle_types': [
              {'vehicle_type_id': 'scooter', 'form_factor': 'scooter'},
            ],
          },
          'free_bike_status': {
            'bikes': [
              {
                'bike_id': 'vehicle-a',
                'lat': 47.5002,
                'lon': 8.7233,
                'vehicle_type_id': 'scooter',
                'is_reserved': false,
                'is_disabled': false,
                'last_reported': now.millisecondsSinceEpoch ~/ 1000,
              },
            ],
          },
        },
      });
      final parsed = parseSharedMobilityResponse(raw, area, now);
      expect(parsed.sourceVersion, 'GBFS $version');
      expect(parsed.offers, hasLength(2));
      expect(parsed.offers[0].reportedStatus, SharedMobilityStatus.unavailable);
      expect(
        parsed.status(parsed.offers[0], now),
        SharedMobilityStatus.unavailable,
      );
      expect(
        parsed.status(parsed.offers[1], now),
        SharedMobilityStatus.available,
      );
      expect(parsed.offers[1].vehicleTypes, ['scooter']);
      expect(
        parsed.status(parsed.offers[1], now.add(const Duration(seconds: 61))),
        SharedMobilityStatus.unknown,
      );
      expect(
        parsed.cached(failed: true).status(parsed.offers[1], now),
        SharedMobilityStatus.unknown,
      );
      final restored = SharedMobilitySnapshot.decode(parsed.encode());
      expect(restored.offers, hasLength(2));
      expect(restored.feedUpdatedUtc, now);
    });
  }

  test('future and missing timestamps cannot assert availability', () {
    const offer = SharedMobilityOffer(
      id: 'v1',
      providerId: 'one',
      providerName: 'One',
      latitude: 47.5,
      longitude: 8.7,
      pickup: SharedMobilityPickup.freeFloating,
      vehicleTypes: ['Bike'],
      reportedAvailable: true,
      disabled: false,
      reserved: false,
    );
    expect(
      offer.effectiveStatus(
        now,
        feedUpdatedUtc: null,
        maxAge: const Duration(seconds: 60),
        refreshFailed: false,
      ),
      SharedMobilityStatus.unknown,
    );
    expect(
      offer.effectiveStatus(
        now,
        feedUpdatedUtc: now.add(const Duration(minutes: 10)),
        maxAge: const Duration(seconds: 60),
        refreshFailed: false,
      ),
      SharedMobilityStatus.unknown,
    );
  });
}
