import 'package:flutter/material.dart';

import 'globe_controller.dart';
import 'scene_layers_section.dart';
import '../weather/wind_settings_sheet.dart';
import '../help/guides_screen.dart';

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
        const GuideLink(GuideTopic.map),
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

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Orts- und Straßennamen'),
          subtitle: const Text('Reine Textbeschriftung · © swisstopo'),
          value: controller.labelsVisible,
          onChanged: controller.canEditPreferences
              ? (value) => execute(() => controller.setMapLabels(value))
              : null,
        ),
        if (controller.labelsVisible) ...[
          Text(switch (controller.labelsState) {
            'loading' => 'Beschriftungen werden geladen …',
            'partial' =>
              'Auswahl verfügbar · Quell- oder Darstellungsgrenze erreicht.',
            'offline' => 'Beschriftungen offline nicht verfügbar; kein Online-Ersatzabruf.',
            'zoomIn' => 'Für Beschriftungen näher heranzoomen.',
            'outside' =>
              'Beschriftungsquelle für die Schweiz und Liechtenstein.',
            'failed' => 'Beschriftungsabruf fehlgeschlagen. Geladene Namen bleiben erhalten.',
            _ => 'Ortsnamen; Straßennamen im Nahbereich. Keine vollständige Wegabdeckung.',
          }, style: Theme.of(context).textTheme.bodySmall),
          if (controller.labelsState == 'failed')
            TextButton.icon(
              onPressed: () =>
                  execute(() => controller.setMapLabels(true, retry: true)),
              icon: const Icon(Icons.refresh),
              label: const Text('Beschriftungen erneut laden'),
            ),
        ],

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Straßen und Wege'),
          subtitle: const Text('swissTLM3D · © swisstopo'),
          value: controller.roadsVisible,
          onChanged: controller.isReady && controller.canEditPreferences
              ? (visible) =>
                    execute(() => controller.setRoadsOverlay(visible: visible))
              : null,
        ),
        if (controller.roadsVisible) ...[
          Row(
            children: [
              const Text('Deckkraft'),
              Expanded(
                child: Slider(
                  value: controller.roadsOpacity,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: '${(controller.roadsOpacity * 100).round()} %',
                  onChanged: controller.isReady && controller.canEditPreferences
                      ? (opacity) => execute(
                          () => controller.setRoadsOverlay(opacity: opacity),
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (controller.situationalStatus('roads') == 'loading')
            const LinearProgressIndicator(),
          if (controller.situationalStatus('roads') == 'failed')
            TextButton.icon(
              onPressed: controller.isReady
                  ? () => execute(() => controller.setRoadsOverlay(retry: true))
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Straßen-Layer erneut laden'),
            ),
        ],
        const SizedBox(height: 16),
        SceneLayersSection(controller: controller),
        WindControlsLauncher(globe: controller),
        const SizedBox(height: 16),
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
