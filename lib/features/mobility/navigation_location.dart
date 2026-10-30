import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'road_routing.dart';

class NavigationFix {
  const NavigationFix({
    required this.point,
    required this.accuracyMeters,
    required this.timeUtc,
    this.speedMetersPerSecond,
    this.headingDegrees,
    this.headingAccuracyDegrees,
  });
  final MobilityPoint point;
  final double accuracyMeters;
  final DateTime timeUtc;
  final double? speedMetersPerSecond, headingDegrees;
  final double? headingAccuracyDegrees;
}

abstract interface class NavigationLocationSource {
  Stream<NavigationFix> watch();
}

class DeviceNavigationLocation implements NavigationLocationSource {
  const DeviceNavigationLocation({this.forNavigation = true});
  final bool forNavigation;
  @override
  Stream<NavigationFix> watch() async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException('Standortdienste sind ausgeschaltet.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const FormatException(
        'Standortzugriff fehlt. Bitte in den Geräte- oder Browser-Einstellungen erlauben.',
      );
    }
    NavigationFix convert(Position p) => NavigationFix(
      point: MobilityPoint(p.latitude, p.longitude),
      accuracyMeters: p.accuracy,
      timeUtc: p.timestamp.toUtc(),
      speedMetersPerSecond: p.hasSpeed && p.speed.isFinite && p.speed >= 0
          ? p.speed
          : null,
      headingDegrees:
          p.hasHeading &&
              p.heading.isFinite &&
              p.heading >= 0 &&
              p.heading < 360
          ? p.heading
          : null,
      headingAccuracyDegrees: p.hasHeadingAccuracy ? p.headingAccuracy : null,
    );
    // Foreground only. No background service or background location permission.
    yield* Geolocator.getPositionStream(
      locationSettings:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: forNavigation
                  ? LocationAccuracy.bestForNavigation
                  : LocationAccuracy.high,
              distanceFilter: forNavigation ? 0 : 3,
              intervalDuration: const Duration(seconds: 1),
            )
          : LocationSettings(
              accuracy: forNavigation
                  ? LocationAccuracy.bestForNavigation
                  : LocationAccuracy.high,
              distanceFilter: forNavigation ? 0 : 3,
            ),
    ).map(convert);
  }
}
