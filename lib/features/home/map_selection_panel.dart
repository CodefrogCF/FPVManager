import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../globe/globe_controller.dart';
import '../airspace/uas_zone_details_panel.dart';
import '../airspace/airspace_check_sheet.dart';
import '../obstacles/obstacle_details_panel.dart';
import '../spots/data/spot_repository.dart';
import '../spots/data/spot_query.dart';
import '../spots/spot_photo_viewer.dart';
import '../globe/map_floating_surface.dart';
import 'spot_map_preview.dart';

class MapSelectionPanel extends StatelessWidget {
  const MapSelectionPanel({
    super.key,
    required this.controller,
    required this.spotsById,
    required this.spotRepository,
    required this.onSpotDetails,
    required this.onCommand,
    this.floating = false,
  });
  final GlobeController controller;
  final Map<int, SpotMapEntry> spotsById;
  final SpotRepository? spotRepository;
  final Future<void> Function(int) onSpotDetails;
  final Future<void> Function(Future<void> Function()) onCommand;
  final bool floating;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      Widget panel(Widget content) => floating
          ? MapFloatingSurface(
              intercept: true,
              child: SingleChildScrollView(child: content),
            )
          : content;
      if (controller.navigationActive ||
          controller.groundViewPending ||
          controller.simulationPending) {
        return const SizedBox.shrink();
      }
      final obstacle = controller.obstacles.selected;
      if (obstacle != null) {
        return panel(
          ObstacleDetailsPanel(
            feature: obstacle,
            snapshot: controller.obstacles.provider.status.dataset?.data,
            onClose: controller.obstacles.clearSelection,
          ),
        );
      }
      final spotId = controller.selectedSpotId;

      final selectedSpot = spotId == null ? null : spotsById[spotId];

      if (selectedSpot != null) {
        return panel(
          SpotMapPreview(
            spot: selectedSpot,
            onClose: controller.clearSelectedSpot,
            onDetails: () => onSpotDetails(selectedSpot.id),
            onFocus: () => onCommand(
              () => controller.focusSpot(
                latitude: selectedSpot.latitude,
                longitude: selectedSpot.longitude,
                rangeMeters: 300,
              ),
            ),
            onAirspace: () => showAirspaceCheck(
              context,
              controller: controller,
              name: selectedSpot.name,
              positions: [
                Wgs84Coordinate(
                  latitude: selectedSpot.latitude,
                  longitude: selectedSpot.longitude,
                ),
              ],
            ),
            onPhotos: () => showDialog<void>(
              context: context,
              builder: (context) => SpotPhotosDialog(
                repository: spotRepository!,
                spotId: selectedSpot.id,
                spotName: selectedSpot.name,
              ),
            ),
          ),
        );
      }
      final selectedZone = controller.selectedUasZone;
      if (selectedZone != null) {
        return panel(
          UasZoneDetailsPanel(
            zone: selectedZone,
            zones: controller.selectedUasZones,
            selectedIndex: controller.selectedUasZoneIndex,
            onZoneSelected: controller.selectUasZone,
            selectionError: controller.uasSelectionError,
            source: controller.uasSource,
            downloadedAtUtc: controller.uasDisplayedDataset?.fetchedAtUtc,
            onClose: controller.clearSelectedUasZone,
          ),
        );
      }
      final point = controller.selectedPoint;
      if (point != null && controller.error == null) {
        return const SizedBox.shrink();
      }
      if (floating) return const SizedBox.shrink();
      final error = controller.error;

      String status;

      if (error != null) {
        status = 'Map error: $error';
      } else if (!controller.isReady) {
        status = 'Loading globe...';
      } else if (!controller.terrainAvailable) {
        status = 'Flat map — terrain heights unavailable';
      } else if (controller.uasZonesError != null) {
        status = 'UAS zones: ${controller.uasZonesError}';
      } else if (controller.uasZonesLoading) {
        status = 'Loading Swiss UAS zones...';
      } else if (controller.uasZonesVisible) {
        status = 'Swiss UAS zones active | Source: FOCA';
      } else {
        status = '3D globe ready';
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    },
  );
}
