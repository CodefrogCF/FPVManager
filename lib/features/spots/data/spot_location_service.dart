import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/repository_validation.dart';
import '../../../core/geo/geo_coordinate_service.dart';

class SpotLocation {
  const SpotLocation({required this.position, required this.accuracyMeters});
  final Wgs84Coordinate position;
  final double? accuracyMeters;
}

class SpotLocationException implements Exception {
  const SpotLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class SpotLocationService {
  const factory SpotLocationService() = DeviceSpotLocationService;
  Future<SpotLocation> currentLocation();
}

final class DeviceSpotLocationService implements SpotLocationService {
  const DeviceSpotLocationService();

  @override
  Future<SpotLocation> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const SpotLocationException(
          'Location services are disabled. Enable them or enter coordinates manually.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const SpotLocationException(
          'Location access is blocked. Allow it in your device/browser settings or enter coordinates manually.',
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const SpotLocationException(
          'Location access was denied. You can still enter coordinates manually.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      RepositoryValidation.coordinates(position.latitude, position.longitude);
      if (!position.accuracy.isFinite || position.accuracy < 0) {
        throw const SpotLocationException(
          'The device returned an invalid location. Try again or enter coordinates manually.',
        );
      }
      return SpotLocation(
        position: Wgs84Coordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        accuracyMeters: position.hasAccuracy ? position.accuracy : null,
      );
    } on SpotLocationException {
      rethrow;
    } on TimeoutException {
      throw const SpotLocationException(
        'Location request timed out. Try again outdoors or enter coordinates manually.',
      );
    } on PermissionDeniedException {
      throw const SpotLocationException(
        'Location access was denied. You can still enter coordinates manually.',
      );
    } on LocationServiceDisabledException {
      throw const SpotLocationException(
        'Location services are disabled. Enter coordinates manually or enable location services.',
      );
    } on UnsupportedError {
      throw const SpotLocationException(
        'Location is unavailable here. On the web use HTTPS or localhost, or enter coordinates manually.',
      );
    } on MissingPluginException {
      throw const SpotLocationException(
        'Location is unavailable on this platform. Enter coordinates manually.',
      );
    } catch (_) {
      throw const SpotLocationException(
        'Unable to read location. Check device/browser permissions and try again, or enter coordinates manually.',
      );
    }
  }
}
