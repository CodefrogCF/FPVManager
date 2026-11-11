import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
            SnackBar(
              content: Text(
                context.translate(
                  "Unable to update map display. Please retry.",
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<GlobeMapStyle>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: GlobeMapStyle.satellite,
                label: Text(context.translate("Satellite")),
                icon: Icon(Icons.satellite_alt),
              ),
              ButtonSegment(
                value: GlobeMapStyle.topographic,
                label: Text(context.translate("Topo")),
                icon: Icon(Icons.map_outlined),
              ),
              ButtonSegment(
                value: GlobeMapStyle.relief,
                label: Text(context.translate("Relief")),
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

        const SizedBox(height: 12),

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Orts- und Straßennamen")),
          value: controller.labelsVisible,
          onChanged: controller.canEditPreferences
              ? (value) => execute(() => controller.setMapLabels(value))
              : null,
        ),
        if (controller.labelsVisible && controller.labelsState != 'ready') ...[
          Text(switch (controller.labelsState) {
            'loading' => context.translate("Beschriftungen werden geladen …"),
            'partial' => context.translate(
              "Beschriftungen teilweise verfügbar.",
            ),
            'offline' => context.translate(
              "Beschriftungen offline nicht verfügbar.",
            ),
            'zoomIn' => context.translate(
              "Für Beschriftungen näher heranzoomen.",
            ),
            'outside' => context.translate("Nur Schweiz und Liechtenstein."),
            'failed' => context.translate(
              "Neue Beschriftungen konnten nicht geladen werden.",
            ),
            _ => '',
          }, style: Theme.of(context).textTheme.bodySmall),
          if (controller.labelsState == 'failed')
            TextButton.icon(
              onPressed: () =>
                  execute(() => controller.setMapLabels(true, retry: true)),
              icon: const Icon(Icons.refresh),
              label: Text(context.translate("Beschriftungen erneut laden")),
            ),
        ],

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Straßen und Wege")),
          value: controller.roadsVisible,
          onChanged: controller.isReady && controller.canEditPreferences
              ? (visible) =>
                    execute(() => controller.setRoadsOverlay(visible: visible))
              : null,
        ),
        if (controller.roadsVisible) ...[
          Row(
            children: [
              Text(context.translate("Deckkraft")),
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
              label: Text(context.translate("Straßen-Layer erneut laden")),
            ),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Gespeicherte Spots")),
          value: controller.savedSpotsVisible,
          onChanged: controller.isReady && controller.canEditPreferences
              ? (visible) =>
                    execute(() => controller.setSavedSpotsVisible(visible))
              : null,
        ),
        const SizedBox(height: 16),

        SceneLayersSection(controller: controller),
        WindControlsLauncher(globe: controller),
        ExpansionTile(
          key: const PageStorageKey('map-overlay-order'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.translate("Reihenfolge der Ebenen")),
          subtitle: Text(context.translate("Vorne nach hinten")),
          children: [
            for (final overlay in controller.overlayOrder.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  overlay == GlobeOverlay.savedSpots
                      ? Icons.place_outlined
                      : Icons.shield_outlined,
                ),
                title: Text(
                  overlay == GlobeOverlay.savedSpots
                      ? context.translate("Saved spots")
                      : 'UAS zones',
                ),
                subtitle: Text(
                  overlay == GlobeOverlay.savedSpots
                      ? context.translate("Local library")
                      : source.publisher,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.translate("Bring {0} forward", [
                        overlay == GlobeOverlay.savedSpots
                            ? 'saved spots'
                            : 'UAS zones',
                      ]),
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
          ],
        ),
        if (routeControls != null)
          ExpansionTile(
            key: const PageStorageKey('map-route-layers'),
            tilePadding: EdgeInsets.zero,
            title: Text(context.translate("Flugrouten")),
            children: [routeControls!],
          ),
        const GuideLink(GuideTopic.map, label: 'Hilfe zur Karte'),
      ],
    );
  }
}
