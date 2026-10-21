import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/battery_repository.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/database/repositories/radio_equipment_repository.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/radio_profile.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/core/models/spot_classification.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/data/spot_photo_service.dart';

void main() {
  test(
    'all personal data survives closing and reopening a local SQLite file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fpvmanager-repository-test-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}personal.sqlite',
      );
      FpvDatabase? database;
      try {
        final first = database = FpvDatabase(NativeDatabase(file));
        final spots = SpotRepository(first);
        final photo = prepareSpotPhoto(
          img.encodeJpg(img.Image(width: 8, height: 4)),
        );
        final spotId = await spots.createSpot(
          name: 'Private spot',
          latitude: 47,
          longitude: 8,
          notes: 'Private access notes',
          photos: [photo],
          classification: SpotClassification(
            category: 'Alpine',
            tags: ['Quiet', 'Freestyle'],
          ),
        );
        await spots.setFavorite(id: spotId, isFavorite: true);
        final droneId = await DroneRepository(first)
            .createDrone(name: 'My drone', takeoffWeightGrams: 700);
        final batteryId = await BatteryRepository(first).createBattery(
          name: 'My pack',
          cellCount: 6,
          capacityMah: 1500,
          cycleCount: 23,
        );
        final radioId = await RadioEquipmentRepository(first).saveProfile(
          RadioProfileInput(
            name: 'My radio',
            category: 'control',
            parameters: {
              RadioParameter.frequencyMhz: 868,
              RadioParameter.sensitivityDbm: -110,
              RadioParameter.rxGainDbi: -1.5,
            },
            descriptions: {
              RadioTextField.protocol: 'Private system',
              RadioTextField.txAntenna: 'Dipole',
              RadioTextField.specificationSource: 'Recorded source',
            },
            droneIds: {droneId},
          ),
        );
        final planId = await FlightPlanRepository(first).createFlightPlan(
          name: 'My route',
          droneId: droneId,
          startSpotId: spotId,
          notes: 'Private plan',
          waypoints: [
            const RouteWaypointInput(
              position: Wgs84Coordinate(latitude: 47, longitude: 8),
              height: AbsoluteWaypointHeight(
                ReferencedElevation(
                  meters: 830,
                  reference: VerticalReference.wgs84Ellipsoid,
                ),
              ),
            ),
          ],
        );
        await UserPreferencesRepository(first).savePreferences(
          const UserPreferences(
            mapStyle: GlobeMapStyle.relief,
            uasZonesVisible: true,
            uasZonesFillOpacity: .6,
            savedSpotsVisible: false,
            overlayOrder: [GlobeOverlay.savedSpots, GlobeOverlay.uasZones],
          ),
        );
        await first.close();
        database = null;

        final reopened = database = FpvDatabase(NativeDatabase(file));
        final spot = (await SpotRepository(reopened).getSpot(spotId))!;
        expect(spot.notes, 'Private access notes');
        expect(spot.isFavorite, isTrue);
        expect(spot.category, 'Alpine');
        expect(await SpotRepository(reopened).getTags(spotId), [
          'freestyle',
          'quiet',
        ]);
        final storedPhotos = await SpotRepository(reopened).getPhotos(spotId);
        expect(storedPhotos, hasLength(1));
        expect(
          await SpotRepository(reopened)
              .getPhotoBytes(spotId: spotId, photoId: storedPhotos.single.id),
          photo.imageBytes,
        );
        expect(
          (await DroneRepository(reopened).getDrone(droneId))!
              .takeoffWeightGrams,
          700,
        );
        expect(
          (await BatteryRepository(reopened).getBattery(batteryId))!.cycleCount,
          23,
        );
        expect(
          (await RadioEquipmentRepository(reopened).getEquipment(radioId))!
              .frequencyMhz,
          868,
        );
        final radio = (await RadioEquipmentRepository(reopened)
            .getProfile(radioId))!;
        expect(radio.drones.single.id, droneId);
        expect(radio.equipment.sensitivityDbm, -110);
        expect(radio.equipment.rxGainDbi, -1.5);
        expect(radio.equipment.protocol, 'Private system');
        expect(radio.equipment.txAntenna, 'Dipole');
        expect(radio.equipment.specificationSource, 'Recorded source');
        final route = (await FlightPlanRepository(reopened).getRoute(planId))!;
        expect(route.plan.droneId, droneId);
        expect(route.plan.startSpotId, spotId);
        expect(route.plan.notes, 'Private plan');
        expect(
          (route.waypoints.single.height as AbsoluteWaypointHeight)
              .elevation
              .reference,
          VerticalReference.wgs84Ellipsoid,
        );
        expect(route.waypoints.single.height!.meters, 830);
        final preferences = await UserPreferencesRepository(reopened)
            .getPreferences();
        expect(preferences.mapStyle, GlobeMapStyle.relief);
        expect(preferences.uasZonesVisible, isTrue);
        expect(preferences.uasZonesFillOpacity, .6);
        expect(preferences.savedSpotsVisible, isFalse);
        expect(preferences.overlayOrder, [
          GlobeOverlay.savedSpots,
          GlobeOverlay.uasZones,
        ]);
      } finally {
        await database?.close();
        // Only remove the unique fixture directory created above, within temp.
        final tempPath = await Directory.systemTemp.resolveSymbolicLinks();
        final fixtureParent = await directory.parent.resolveSymbolicLinks();
        if (fixtureParent == tempPath &&
            directory.uri.pathSegments
                .where((segment) => segment.isNotEmpty)
                .last
                .startsWith('fpvmanager-repository-test-')) {
          await directory.delete(recursive: true);
        }
      }
    },
  );
}
