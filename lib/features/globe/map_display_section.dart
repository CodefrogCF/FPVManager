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
                context.localized(
                  "Unable to update map display. Please retry.",
                  (l10n) => l10n.globeUnableToUpdateMapefb1235c,
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
                label: Text(
                  context.localized(
                    "Satellite",
                    (l10n) => l10n.globeSatellited1ffec93,
                  ),
                ),
                icon: Icon(Icons.satellite_alt),
              ),
              ButtonSegment(
                value: GlobeMapStyle.topographic,
                label: Text(
                  context.localized("Topo", (l10n) => l10n.globeTopo7416e691),
                ),
                icon: Icon(Icons.map_outlined),
              ),
              ButtonSegment(
                value: GlobeMapStyle.relief,
                label: Text(
                  context.localized(
                    "Relief",
                    (l10n) => l10n.commonReliefbe53bb74,
                  ),
                ),
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
          title: Text(
            context.localized(
              "Orts- und Straßennamen",
              (l10n) => l10n.globeOrtsUndStrassennamenbe90f8a3,
            ),
          ),
          value: controller.labelsVisible,
          onChanged: controller.canEditPreferences
              ? (value) => execute(() => controller.setMapLabels(value))
              : null,
        ),
        if (controller.labelsVisible && controller.labelsState != 'ready') ...[
          Text(switch (controller.labelsState) {
            'loading' => context.localized(
              "Beschriftungen werden geladen …",
              (l10n) => l10n.globeBeschriftungenWerdenGeladenb8c71bdb,
            ),
            'partial' => context.localized(
              "Beschriftungen teilweise verfügbar.",
              (l10n) => l10n.globeBeschriftungenTeilweiseVerfuegbar5ada98f5,
            ),
            'offline' => context.localized(
              "Beschriftungen offline nicht verfügbar.",
              (l10n) => l10n.globeBeschriftungenOfflineNichtVerfuegbar79eca86d,
            ),
            'zoomIn' => context.localized(
              "Für Beschriftungen näher heranzoomen.",
              (l10n) => l10n.globeFuerBeschriftungenNaeherHeranzoomen6f64dcb5,
            ),
            'outside' => context.localized(
              "Nur Schweiz und Liechtenstein.",
              (l10n) => l10n.globeNurSchweizUndLiechtenstein1516f8d3,
            ),
            'failed' => context.localized(
              "Neue Beschriftungen konnten nicht geladen werden.",
              (l10n) => l10n.globeNeueBeschriftungenKonntenNicht08732593,
            ),
            _ => '',
          }, style: Theme.of(context).textTheme.bodySmall),
          if (controller.labelsState == 'failed')
            TextButton.icon(
              onPressed: () =>
                  execute(() => controller.setMapLabels(true, retry: true)),
              icon: const Icon(Icons.refresh),
              label: Text(
                context.localized(
                  "Beschriftungen erneut laden",
                  (l10n) => l10n.globeBeschriftungenErneutLaden53e7b713,
                ),
              ),
            ),
        ],

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Straßen und Wege",
              (l10n) => l10n.commonStrassenUndWegea615580e,
            ),
          ),
          value: controller.roadsVisible,
          onChanged: controller.isReady && controller.canEditPreferences
              ? (visible) =>
                    execute(() => controller.setRoadsOverlay(visible: visible))
              : null,
        ),
        if (controller.roadsVisible) ...[
          Row(
            children: [
              Text(
                context.localized(
                  "Deckkraft",
                  (l10n) => l10n.globeDeckkraft3c11c68b,
                ),
              ),
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
              label: Text(
                context.localized(
                  "Straßen-Layer erneut laden",
                  (l10n) => l10n.globeStrassenLayerErneutLadenfb527544,
                ),
              ),
            ),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Gespeicherte Spots",
              (l10n) => l10n.globeGespeicherteSpots4f634531,
            ),
          ),
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
          title: Text(
            context.localized(
              "Reihenfolge der Ebenen",
              (l10n) => l10n.globeReihenfolgeDerEbenenf736c2db,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Vorne nach hinten",
              (l10n) => l10n.globeVorneNachHinten4d9d3fd7,
            ),
          ),
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
                      ? context.localized(
                          "Saved spots",
                          (l10n) => l10n.globeSavedSpotsf65c2504,
                        )
                      : 'UAS zones',
                ),
                subtitle: Text(
                  overlay == GlobeOverlay.savedSpots
                      ? context.localized(
                          "Local library",
                          (l10n) => l10n.globeLocalLibrary1c67cdf4,
                        )
                      : source.publisher,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.localizedWithArgs(
                        "Bring {0} forward",
                        [
                          overlay == GlobeOverlay.savedSpots
                              ? 'saved spots'
                              : 'UAS zones',
                        ],
                        (l10n, value) =>
                            l10n.globeBringForwardcf73f6a1(value(0)),
                      ),
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
            title: Text(
              context.localized(
                "Flugrouten",
                (l10n) => l10n.commonFlugrouten39801473,
              ),
            ),
            children: [routeControls!],
          ),
        const GuideLink(GuideTopic.map, label: 'Hilfe zur Karte'),
      ],
    );
  }
}
