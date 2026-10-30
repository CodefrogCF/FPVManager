import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fpvmanager/features/globe/globe_location_controller.dart';
import 'package:fpvmanager/features/mobility/navigation_location.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

class LocationSource implements NavigationLocationSource {
  int starts = 0, stops = 0;
  final streams = <StreamController<NavigationFix>>[];
  @override
  Stream<NavigationFix> watch() {
    starts++;
    final stream = StreamController<NavigationFix>(
      sync: true,
      onCancel: () => stops++,
    );
    streams.add(stream);
    return stream.stream;
  }

  void add(NavigationFix fix) => streams.last.add(fix);
  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}

class LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied,
      requested = LocationPermission.whileInUse;
  int permissions = 0, streams = 0;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissions++;
    return requested;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    settings = locationSettings;
    return const Stream.empty();
  }
}

void main() {
  late LocationSource source;
  late GlobeLocationController controller;
  late DateTime now;
  late List<Map<String, dynamic>> commands;
  NavigationFix fix({
    double lat = 47,
    double? heading = 90,
    double? accuracy = 5,
    double speed = 4,
  }) => NavigationFix(
    point: MobilityPoint(lat, 8),
    accuracyMeters: 12,
    timeUtc: now,
    headingDegrees: heading,
    headingAccuracyDegrees: accuracy,
    speedMetersPerSecond: speed,
  );
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  setUp(() {
    source = LocationSource();
    now = DateTime.utc(2026, 10, 30, 12);
    commands = [];
    controller = GlobeLocationController(
      source: source,
      now: () => now,
      send: (command) async => commands.add(command),
    );
  });
  tearDown(() async {
    controller.dispose();
    await settle();
    await source.close();
  });

  test('disabled location does no GPS or bridge work during foreground and simulation transitions', () async {
    await controller.foreground(false);
    await controller.foreground(true);
    await controller.suspended(true);
    await controller.suspended(false);
    expect(source.starts, 0);
    expect(commands, isEmpty);
  });

  test('locating is explicit; marker updates retain manual camera position until following is enabled', () async {
    expect(source.starts, 0);
    expect(commands, isEmpty);
    await controller.locate();
    source.add(fix());
    await settle();
    expect(commands.last['recenter'], true);
    expect(commands.last['follow'], false);
    expect((commands.last['fix'] as Map)['accuracyMeters'], 12);
    expect(controller.heading, 90);
    source.add(fix(lat: 47.001));
    await settle();
    expect(commands.last['recenter'], false);
    await controller.setFollowing(true);
    expect(commands.last['follow'], true);
    await controller.setFollowing(false);
    expect(commands.last['follow'], false);
    await controller.locate();
    expect(commands.last['recenter'], true);
  });

  test('stale fixes, unknown course and stream failures are never represented as current', () async {
    await controller.locate();
    source.add(fix(speed: 0));
    await settle();
    expect(controller.heading, isNull);
    source.add(fix(accuracy: null));
    await settle();
    expect(controller.heading, isNull);
    source.add(fix(accuracy: double.nan));
    await settle();
    expect(controller.heading, isNull);
    source.add(fix(speed: double.nan));
    await settle();
    expect(controller.heading, isNull);
    source.add(fix());
    now = now.add(const Duration(seconds: 31));
    await controller.rendererReady();
    expect(controller.stale, true);
    expect(controller.heading, isNull);
    expect((commands.last['fix'] as Map)['stale'], true);
    source.streams.last.addError(
      const FormatException('Standortdienste sind ausgeschaltet.'),
    );
    await settle();
    expect(controller.message, contains('ausgeschaltet'));
    expect(commands.last['follow'], false);
    expect(controller.enabled, false);
    await controller.foreground(false);
    await controller.foreground(true);
    expect(
      source.starts,
      1,
      reason: 'A denied/failed stream must not request permission again automatically',
    );
  });

  test('backgrounding, simulation, disabling and disposal cancel streams; resume needs a new fix', () async {
    await controller.locate();
    source.add(fix());
    await settle();
    await controller.foreground(false);
    expect(source.stops, 1);
    expect(controller.stale, true);
    await controller.foreground(true);
    expect(source.starts, 2);
    expect(controller.stale, true);
    source.add(fix());
    await settle();
    expect(controller.stale, false);
    await controller.suspended(true);
    expect(source.stops, 2);
    expect(commands.last['enabled'], false);
    await controller.suspended(false);
    expect(source.starts, 3);
    await controller.disable();
    expect(source.stops, 3);
    expect(controller.fix, isNull);
    expect(commands.last['fix'], isNull);
    expect(commands.last['enabled'], false);
    await controller.foreground(false);
    await controller.foreground(true);
    expect(source.starts, 3);
  });

  test('a blocked renderer retains at most one pending fix and restores the latest position', () async {
    controller.dispose();
    final gate = Completer<void>();
    controller = GlobeLocationController(
      source: source,
      now: () => now,
      send: (command) async {
        commands.add(command);
        if (commands.length == 1) await gate.future;
      },
    );
    await controller.locate();
    source.add(fix());
    for (var i = 1; i <= 50; i++) {
      source.add(fix(lat: 47 + i / 1000));
    }
    expect(commands, hasLength(1));
    gate.complete();
    await settle();
    expect(commands, hasLength(2));
    expect((commands.last['fix'] as Map)['latitude'], 47.05);
    expect(commands.last['recenter'], false);
  });

  test('device permissions are requested only on subscription; denied and disabled sources never start GPS', () async {
    final previous = GeolocatorPlatform.instance, platform = LocationPlatform();
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = previous);
    const device = DeviceNavigationLocation(forNavigation: false);
    expect(platform.permissions, 0);
    expect(platform.streams, 0);
    platform.requested = LocationPermission.denied;
    await expectLater(device.watch().toList(), throwsFormatException);
    expect(platform.streams, 0);
    platform.permission = LocationPermission.deniedForever;
    await expectLater(device.watch().toList(), throwsFormatException);
    expect(platform.permissions, 1);
    platform.enabled = false;
    await expectLater(device.watch().toList(), throwsFormatException);
    expect(platform.streams, 0);
    platform.enabled = true;
    platform.permission = LocationPermission.whileInUse;
    await device.watch().toList();
    expect(platform.streams, 1);
    expect(platform.settings!.distanceFilter, 3);
  });
}
