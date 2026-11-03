import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_models.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_parser.dart';
import 'package:fpvmanager/features/mobility/ev_charging/ev_charging_service.dart';

void main() {
  final area = EvChargingArea(
    latitude: 47.37,
    longitude: 8.54,
    radiusMeters: 2000,
  );
  final now = DateTime.utc(2026, 11, 3, 15);
  Map<String, dynamic> entry(
    String id, {
    String? status = 'AVAILABLE',
    String? time,
    String? standard = 'IEC_62196_T2',
    Object? power = 22000,
  }) => {
    'featureId': id,
    'geometry': {
      'type': 'Point',
      'coordinates': [8.54, 47.37],
    },
    'properties': {
      'ChargingStationId': 'STATION1',
      'name': 'Bahnhof',
      'address': 'Bahnhofplatz',
      'evses': [
        {
          'uid': id,
          'status': status,
          'last_updated': time,
          'connectors': [
            {'id': '1', 'standard': standard, 'max_electric_power': power},
            {'id': '1', 'standard': standard, 'max_electric_power': power},
          ],
        },
      ],
    },
  };

  test(
    'HTTPS query sends bounded WGS84 envelope, never nationwide geometry',
    () {
      final uri = geoAdminEvQuery(area);
      expect(uri.scheme, 'https');
      expect(uri.host, 'api3.geo.admin.ch');
      expect(uri.queryParameters['geometryType'], 'esriGeometryEnvelope');
      expect(uri.queryParameters['limit'], '200');
      expect(
        uri.queryParameters['layers'],
        'all:ch.bfe.ladestellen-elektromobilitaet',
      );
      final env = (uri.queryParameters['geometry']!)
          .split(',')
          .map(double.parse)
          .toList();
      expect(env[2] - env[0], lessThan(0.1));
      expect(env[3] - env[1], lessThan(0.1));
      expect(
        () => EvChargingArea(
          latitude: 46.9,
          longitude: 8.4,
          radiusMeters: 500000,
        ),
        throwsFormatException,
      );
      expect(
        () => EvChargingArea(latitude: 52.0, longitude: 8.4),
        throwsFormatException,
      );
    },
  );

  test(
    'location, connectors and status are separate; duplicates normalized',
    () {
      final body = jsonEncode({
        'results': [
          entry(
            'evse-1',
            time: now.subtract(const Duration(seconds: 20)).toIso8601String(),
          ),
          entry(
            'evse-2',
            time: now.subtract(const Duration(seconds: 20)).toIso8601String(),
          ),
        ],
      });
      final snapshot = parseEvChargingResponse(body, area, now);
      expect(snapshot.stations, hasLength(1));
      final station = snapshot.stations.single;
      expect(station.evseIds, hasLength(2));
      expect(
        station.connectors,
        hasLength(2),
      ); // Two EVSEs with one unique connector each.
      expect(station.connectors.first.type, 'IEC_62196_T2');
      expect(station.connectors.first.powerKw, 22.0);
      expect(snapshot.statuses, hasLength(2));
      expect(
        snapshot.statuses[station.evseIds.first]!.isAvailable(now),
        isTrue,
      );
      final restored = EvChargingSnapshot.decode(snapshot.encode());
      expect(restored.stations.single.evseIds, station.evseIds);
      expect(restored.statuses.keys, containsAll(station.evseIds));
    },
  );

  test('status changes and missing or stale time never turn into free', () {
    final previous = EvChargingAvailability(
      evseId: '1',
      rawStatus: 'AVAILABLE',
      updatedUtc: now.subtract(const Duration(minutes: 6)),
    );
    expect(previous.isAvailable(now), isFalse);
    expect(previous.label(now), contains('veraltet'));
    final changed = EvChargingAvailability(
      evseId: '1',
      rawStatus: 'CHARGING',
      updatedUtc: now,
    );
    expect(changed.label(now), 'Belegt');
    expect(changed.isAvailable(now), isFalse);
    final unknown = EvChargingAvailability(
      evseId: '1',
      rawStatus: 'AVAILABLE',
      updatedUtc: null,
    );
    expect(unknown.isAvailable(now), isFalse);
    final future = EvChargingAvailability(
      evseId: '1',
      rawStatus: 'AVAILABLE',
      updatedUtc: now.add(const Duration(hours: 1)),
    );
    expect(future.isAvailable(now), isFalse);
  });

  test('missing tags do not infer connector, power or availability', () {
    final result = parseEvChargingResponse(
      jsonEncode({
        'results': [
          {
            'featureId': '123',
            'geometry': {
              'type': 'Point',
              'coordinates': [8.54, 47.37],
            },
            'properties': {'name': 'No details'},
          },
        ],
      }),
      area,
      now,
    );
    expect(result.stations, hasLength(1));
    expect(result.stations.single.connectors, isEmpty);
    expect(result.statuses, isEmpty);
    expect(result.stations.single.evseIds, hasLength(1));
  });

  test('legacy OICP plug strings and power are normalized when supplied', () {
    final snapshot = parseEvChargingResponse(
      jsonEncode({
        'results': [
          {
            'featureId': 'old-1',
            'geometry': {
              'type': 'Point',
              'coordinates': [8.54, 47.37],
            },
            'properties': {
              'Plugs': 'Type 2, CCS',
              'Power': 50,
              'Availability': 'Occupied',
              'LastUpdated': '2026-11-03T15:00:00Z',
            },
          },
        ],
      }),
      area,
      now,
    );
    expect(
      snapshot.stations.single.connectors.map((c) => c.type),
      containsAll(['Type 2', 'CCS']),
    );
    expect(snapshot.stations.single.connectors.first.powerKw, 50.0);
    expect(snapshot.statuses.values.single.label(now), 'Belegt');
  });

  test('changing source status updates the isolated availability record', () {
    String sample(String value) => jsonEncode({
      'results': [entry('evse-1', status: value, time: now.toIso8601String())],
    });
    final available = parseEvChargingResponse(sample('AVAILABLE'), area, now);
    final occupied = parseEvChargingResponse(sample('CHARGING'), area, now);
    expect(
      available.stations.single.toJson(),
      occupied.stations.single.toJson(),
    );
    expect(available.statuses.values.single.isAvailable(now), isTrue);
    expect(occupied.statuses.values.single.isAvailable(now), isFalse);
  });

  test('out of range or malformed coordinates are excluded, invalid schema rejected', () {
    final result = parseEvChargingResponse(
      jsonEncode({
        'results': [
          {
            'featureId': 'far',
            'geometry': {
              'type': 'Point',
              'coordinates': [9.5, 47.37],
            },
            'properties': {'name': 'Far'},
          },
          {
            'featureId': 'missing',
            'properties': {'name': 'No position'},
          },
        ],
      }),
      area,
      now,
    );
    expect(result.stations, isEmpty);
    expect(
      () => parseEvChargingResponse('{}', area, now),
      throwsFormatException,
    );
    expect(
      () => parseEvChargingResponse('{"results": "bad"}', area, now),
      throwsFormatException,
    );
    expect(
      () => parseEvChargingResponse(
        jsonEncode({'results': List.filled(201, entry('z'))}),
        area,
        now,
      ),
      throwsFormatException,
    );
  });
}
