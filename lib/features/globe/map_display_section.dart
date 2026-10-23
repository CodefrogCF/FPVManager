import 'package:flutter/material.dart';

import 'globe_controller.dart';

class MapDisplaySection extends StatelessWidget {
  const MapDisplaySection({
    super.key,
    required this.controller,
    this.routeControls,
  });
  final GlobeController controller;
  final Widget? routeControls;
  @override
  Widget build(BuildContext context) {
    final source = controller.uasSource;
    Future<void> execute(Future<void> Function() command) async {
      try {
        await command();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update map display. Please retry.'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BASE MAP', style: Theme.of(context).textTheme.labelLarge),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: SegmentedButton<GlobeMapStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: GlobeMapStyle.satellite,
                label: Text('Satellite'),
                icon: Icon(Icons.satellite_alt),
              ),
              ButtonSegment(
                value: GlobeMapStyle.topographic,
                label: Text('Topo'),
                icon: Icon(Icons.map_outlined),
              ),
              ButtonSegment(
                value: GlobeMapStyle.relief,
                label: Text('Relief'),
                icon: Icon(Icons.terrain),
              ),
            ],
            selected: {controller.mapStyle},
            onSelectionChanged:
                controller.isReady && controller.canEditPreferences
                ? (selection) {
                    execute(() => controller.setMapStyle(selection.first));
                  }
                : null,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'OVERLAY ORDER · FRONT TO BACK',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Terrain and the base map stay below these overlays.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final overlay in controller.overlayOrder.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              overlay == GlobeOverlay.savedSpots
                  ? Icons.place_outlined
                  : Icons.shield_outlined,
            ),
            title: Text(
              overlay == GlobeOverlay.savedSpots ? 'Saved spots' : 'UAS zones',
            ),
            subtitle: Text(
              overlay == GlobeOverlay.savedSpots
                  ? 'Local library'
                  : source.publisher,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                      'Bring ${overlay == GlobeOverlay.savedSpots ? 'saved spots' : 'UAS zones'} forward',
                  onPressed:
                      controller.isReady &&
                          controller.canEditPreferences &&
                          overlay != controller.overlayOrder.last
                      ? () => execute(
                          () => controller.setOverlayOrder(
                            controller.overlayOrder.reversed.toList(),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip:
                      'Send ${overlay == GlobeOverlay.savedSpots ? 'saved spots' : 'UAS zones'} backward',
                  onPressed:
                      controller.isReady &&
                          controller.canEditPreferences &&
                          overlay != controller.overlayOrder.first
                      ? () => execute(
                          () => controller.setOverlayOrder(
                            controller.overlayOrder.reversed.toList(),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ),

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show saved spots'),
          value: controller.savedSpotsVisible,
          onChanged: controller.isReady && controller.canEditPreferences
              ? (visible) =>
                    execute(() => controller.setSavedSpotsVisible(visible))
              : null,
        ),
        const SizedBox(height: 16),

        if (routeControls != null) ...[
          const Divider(height: 32),
          routeControls!,
        ],
      ],
    );
  }
}
