import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fpvmanager/features/spots/data/spot_location_service.dart';

class _LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionRequests = 0;
  Object? error;
  LocationSettings? settings;
  Position position = Position(
    longitude: 8,
    latitude: 47,
    timestamp: DateTime.utc(2026, 10, 19),
    accuracy: 12,
    altitude: 800,
    altitudeAccuracy: 20,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    hasAccuracy: true,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionRequests++;
    settings = locationSettings;
    if (error != null) throw error!;
    return position;
  }
}

void main() {
  late GeolocatorPlatform previous;
  late _LocationPlatform platform;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = previous);

  test(
    'location is opt-in, bounded and returns coordinates with accuracy',
    () async {
      const service = SpotLocationService();
      expect(platform.permissionRequests, 0);
      expect(platform.positionRequests, 0);
      final location = await service.currentLocation();
      expect(platform.permissionRequests, 1);
      expect(platform.positionRequests, 1);
      expect(platform.settings!.timeLimit, const Duration(seconds: 20));
      expect(location.position.latitude, 47);
      expect(location.position.longitude, 8);
      expect(location.accuracyMeters, 12);
    },
  );

  test('granted permissions do not prompt again', () async {
    platform.permission = LocationPermission.whileInUse;
    await const SpotLocationService().currentLocation();
    expect(platform.permissionRequests, 0);
    expect(platform.positionRequests, 1);
  });

  test(
    'denied, blocked and disabled location never fetch a position',
    () async {
      platform.requested = LocationPermission.denied;
      await expectLater(
        const SpotLocationService().currentLocation(),
        throwsA(isA<SpotLocationException>()),
      );
      expect(platform.positionRequests, 0);
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        const SpotLocationService().currentLocation(),
        throwsA(isA<SpotLocationException>()),
      );
      expect(platform.permissionRequests, 1);
      platform.enabled = false;
      await expectLater(
        const SpotLocationService().currentLocation(),
        throwsA(isA<SpotLocationException>()),
      );
      expect(platform.positionRequests, 0);
    },
  );

  test('timeout and unsupported platforms become actionable errors', () async {
    platform.permission = LocationPermission.whileInUse;
    platform.error = TimeoutException('test');
    await expectLater(
      const SpotLocationService().currentLocation(),
      throwsA(
        isA<SpotLocationException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
    platform.error = UnsupportedError('test');
    await expectLater(
      const SpotLocationService().currentLocation(),
      throwsA(
        isA<SpotLocationException>().having(
          (error) => error.message,
          'message',
          contains('HTTPS'),
        ),
      ),
    );
  });
}
