import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../globe/globe_controller.dart';
import '../airspace/uas_zone_details_panel.dart';
import '../airspace/airspace_check_sheet.dart';
import '../obstacles/obstacle_details_panel.dart';
import '../spots/data/spot_repository.dart';
import '../spots/data/spot_query.dart';
import '../spots/spot_photo_viewer.dart';

class MapSelectionPanel extends StatelessWidget {
  const MapSelectionPanel({
    super.key,
    required this.controller,
    required this.spotsById,
    required this.spotRepository,
    required this.onSpotDetails,
    required this.onCommand,
  });
  final GlobeController controller;
  final Map<int, SpotMapEntry> spotsById;
  final SpotRepository? spotRepository;
  final Future<void> Function(int) onSpotDetails;
  final Future<void> Function(Future<void> Function()) onCommand;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final obstacle = controller.obstacles.selected;
      if (obstacle != null) {
        return ObstacleDetailsPanel(
          feature: obstacle,
          snapshot: controller.obstacles.provider.status.dataset?.data,
          onClose: controller.obstacles.clearSelection,
        );
      }
      if (controller.navigationActive ||
          controller.groundViewPending ||
          controller.simulationPending) {
        return const SizedBox.shrink();
      }
      final spotId = controller.selectedSpotId;

      final selectedSpot = spotId == null ? null : spotsById[spotId];

      if (selectedSpot != null) {
        return SafeArea(
          top: false,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.place,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(selectedSpot.name),
                  subtitle: Text(
                    '${selectedSpot.latitude.toStringAsFixed(8)}, '
                    '${selectedSpot.longitude.toStringAsFixed(8)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Close spot details',
                    onPressed: controller.clearSelectedSpot,
                    icon: const Icon(Icons.close),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onSpotDetails(selectedSpot.id),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showAirspaceCheck(
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
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Check airspace'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => SpotPhotosDialog(
                            repository: spotRepository!,
                            spotId: selectedSpot.id,
                            spotName: selectedSpot.name,
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Photos'),
                      ),
                      FilledButton.icon(
                        onPressed: () => onCommand(
                          () => controller.focusSpot(
                            latitude: selectedSpot.latitude,
                            longitude: selectedSpot.longitude,
                            rangeMeters: 300,
                          ),
                        ),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Fly to Spot'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final selectedZone = controller.selectedUasZone;
      if (selectedZone != null) {
        return UasZoneDetailsPanel(
          zone: selectedZone,
          zones: controller.selectedUasZones,
          selectedIndex: controller.selectedUasZoneIndex,
          onZoneSelected: controller.selectUasZone,
          selectionError: controller.uasSelectionError,
          source: controller.uasSource,
          downloadedAtUtc: controller.uasDisplayedDataset?.fetchedAtUtc,
          onClose: controller.clearSelectedUasZone,
        );
      }
      final point = controller.selectedPoint;
      if (point != null && controller.error == null) {
        return const SizedBox.shrink();
      }
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
