import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'obstacle_map_controller.dart';
import 'obstacle_models.dart';
import 'swiss_obstacle_provider.dart';
import '../help/guides_screen.dart';

const obstacleCoverageNotice =
    'Published obstacles only. Missing objects, cables and other hazards may exist. '
    'This layer does not establish that an area is obstacle-free or authorize a flight.';

class ObstacleLayersSection extends StatefulWidget {
  const ObstacleLayersSection({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final ObstacleMapController controller;
  final bool enabled;
  static const legendUrl =
      'https://api3.geo.admin.ch/static/images/legends/ch.bazl.luftfahrthindernis_de.png';
  @override
  State<ObstacleLayersSection> createState() => _ObstacleLayersSectionState();
}

class _ObstacleLayersSectionState extends State<ObstacleLayersSection> {
  double? _previewOpacity;
  double? _previewBuffer;
  ObstacleMapController get controller => widget.controller;
  bool get enabled => widget.enabled;
  @override
  Widget build(BuildContext context) {
    final opacity = _previewOpacity ?? controller.wmsOpacity;
    final state = controller.provider.status;
    final dataset = state.dataset;
    final snapshot = dataset?.data;
    final busy = state.update == OsintUpdateState.loading;
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localized(
            "Swiss aviation obstacles",
            (l10n) => l10n.obstaclesSwissAviationObstacles1befa7cf,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.localized(
            "Nur veröffentlichte Hindernisse · fehlende Objekte möglich.",
            (l10n) =>
                l10n.obstaclesNurVeroeffentlichteHindernisseFehlende874c23fc,
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Published obstacles · WMS",
              (l10n) => l10n.obstaclesPublishedObstaclesWms03371ce2,
            ),
          ),
          subtitle: Text('BAZL / FOCA · geo.admin.ch · ${controller.wmsState}'),
          value: controller.wmsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setWmsVisible(v)))
              : null,
        ),
        if (controller.wmsState == 'loading') const LinearProgressIndicator(),
        Text(
          context.localizedWithArgs(
            "Obstacle imagery opacity: {0}%",
            [(opacity * 100).round()],
            (l10n, value) =>
                l10n.obstaclesObstacleImageryOpacity83ec0630(value(0)),
          ),
        ),
        Slider(
          value: opacity,
          divisions: 20,
          label: '${(opacity * 100).round()}%',
          onChanged: enabled
              ? (v) => setState(() => _previewOpacity = v)
              : null,
          onChangeEnd: enabled
              ? (v) => unawaited(
                  run(() async {
                    await controller.setWmsOpacity(v);
                    if (mounted) setState(() => _previewOpacity = null);
                  }),
                )
              : null,
        ),
        Text(
          context.localized(
            "Combined raster symbols: no category filters, object selection or precise 3D heights.",
            (l10n) => l10n.commonCombinedRasterSymbolsNo01f2553a,
          ),
        ),
        if (controller.wmsError != null) ...[
          Text(
            controller.wmsError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            onPressed: enabled
                ? () => controller.restoreWms(retry: true)
                : null,
            icon: const Icon(Icons.refresh),
            label: Text(
              context.localized(
                "Retry obstacle imagery",
                (l10n) => l10n.obstaclesRetryObstacleImagerya63bb8aa,
              ),
            ),
          ),
        ],
        TextButton.icon(
          icon: const Icon(Icons.legend_toggle),
          label: Text(
            context.localized(
              "Official WMS legend",
              (l10n) => l10n.obstaclesOfficialWmsLegenda55cc700,
            ),
          ),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                context.localized(
                  "BAZL obstacle legend",
                  (l10n) => l10n.obstaclesBazlObstacleLegend85da8229,
                ),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        ObstacleLayersSection.legendUrl,
                        errorBuilder: (_, error, stack) => Text(
                          context.localized(
                            "Legend unavailable. Open the official link below.",
                            (l10n) =>
                                l10n.obstaclesLegendUnavailableOpenThe1690ecec,
                          ),
                        ),
                      ),
                      const SelectableText(ObstacleLayersSection.legendUrl),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.localized(
                      "Close",
                      (l10n) => l10n.commonClosebbfa773e,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Selectable obstacles · 3D vector",
              (l10n) => l10n.obstaclesSelectableObstaclesDVectore21d36db,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Amtlicher Datensatz · nach Import offline verfügbar.",
              (l10n) => l10n.obstaclesAmtlicherDatensatzNachImportd2d6162d,
            ),
          ),
          value: controller.vectorsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setVectorsVisible(v)))
              : null,
        ),
        if (controller.vectorsVisible)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.localized(
                "3D obstacle models",
                (l10n) => l10n.obstaclesDObstacleModels82a00838,
              ),
            ),
            subtitle: Text(
              context.localized(
                "Veröffentlichte Höhe · Form und Breite geschätzt.",
                (l10n) => l10n.obstaclesVeroeffentlichteHoeheFormUnd8f84873d,
              ),
            ),
            value: controller.modelsVisible,
            onChanged: enabled
                ? (v) => unawaited(run(() => controller.setModelsVisible(v)))
                : null,
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Highlight hazard areas",
              (l10n) => l10n.obstaclesHighlightHazardAreas0d0a655e,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Planungshilfe · keine Freigabe oder Abstandsprüfung.",
              (l10n) => l10n.obstaclesPlanungshilfeKeineFreigabeOder3f2c05b6,
            ),
          ),
          value: controller.hazardsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setHazardsVisible(v)))
              : null,
        ),
        Text(
          context.localizedWithArgs(
            "Horizontal buffer: {0} m",
            [(_previewBuffer ?? controller.bufferMeters).toStringAsFixed(0)],
            (l10n, value) => l10n.obstaclesHorizontalBufferMc4e67f2c(value(0)),
          ),
        ),
        Slider(
          value: _previewBuffer ?? controller.bufferMeters,
          max: 1000,
          divisions: 200,
          label: '${controller.bufferMeters.toStringAsFixed(0)} m',
          onChanged: enabled ? (v) => setState(() => _previewBuffer = v) : null,
          onChangeEnd: enabled
              ? (v) => unawaited(
                  run(() async {
                    await controller.setBufferMeters(v);
                    if (mounted) setState(() => _previewBuffer = null);
                  }),
                )
              : null,
        ),
        if (busy) const LinearProgressIndicator(),
        Text(controller.provider.progress),
        Text(
          context.localizedWithArgs("Data status: {0}", [
            state.dataState.label,
          ], (l10n, value) => l10n.obstaclesDataStatusef822b6e(value(0))),
        ),
        if (controller.vectorsVisible || controller.hazardsVisible) ...[
          Text(controller.vectorStatus),
          Wrap(
            spacing: 6,
            children: [
              for (final category in ObstacleCategory.values)
                FilterChip(
                  label: Text(category.label),
                  selected: controller.categories.contains(category),
                  onSelected: enabled
                      ? (v) => unawaited(
                          run(() => controller.setCategory(category, v)),
                        )
                      : null,
                ),
            ],
          ),
        ],
        if (controller.vectorError != null || state.error != null)
          Text(
            controller.vectorError ?? state.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (snapshot != null) ...[
          if (snapshot.metadata['datasetUsageRestriction']
              case final String restriction)
            Text(
              restriction,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          Text(
            context.localizedWithArgs(
              "Local cache: {0} · source validity: {1}",
              [
                dataset!.freshnessAt(DateTime.now()).name,
                dataset.validity?.at(DateTime.now()).name ??
                    OsintValidity.unknown.name,
              ],
              (l10n, value) => l10n.obstaclesLocalCacheSourceValidity2bcad0a6(
                value(0),
                value(1),
              ),
            ),
          ),
          if (snapshot.metadata['datasetValidFrom'] != null ||
              snapshot.metadata['datasetValidTo'] != null)
            Text(
              context.localizedWithArgs(
                "Published validity: {0} → {1} UTC",
                [
                  snapshot.metadata['datasetValidFrom'] ?? '?',
                  snapshot.metadata['datasetValidTo'] ?? '?',
                ],
                (l10n, value) => l10n.obstaclesPublishedValidityUtcb1c25560(
                  value(0),
                  value(1),
                ),
              ),
            ),
        ],
        TextButton.icon(
          onPressed: enabled && !busy ? controller.refreshVectors : null,
          icon: const Icon(Icons.sync),
          label: Text(
            snapshot == null
                ? context.localized(
                    "Download vector dataset",
                    (l10n) => l10n.obstaclesDownloadVectorDataset689316d7,
                  )
                : context.localized(
                    "Check source for updates",
                    (l10n) => l10n.obstaclesCheckSourceForUpdates9b2adfd6,
                  ),
          ),
        ),
        ExpansionTile(
          key: const PageStorageKey('map-obstacle-source-details'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Daten & Höhenbezug",
              (l10n) => l10n.obstaclesDatenHoehenbezug36af217e,
            ),
          ),
          children: [
            if (snapshot != null) ...[
              Text(
                context.localizedWithArgs(
                  "{0} imported objects · {1} unsupported records",
                  [snapshot.count, snapshot.skipped],
                  (l10n, value) =>
                      l10n.obstaclesImportedObjectsUnsupportedRecords947e6f13(
                        value(0),
                        value(1),
                      ),
                ),
              ),
              Text(
                context.localizedWithArgs(
                  "Source updated: {0}",
                  [snapshot.sourceUpdated?.toIso8601String() ?? 'unknown'],
                  (l10n, value) =>
                      l10n.obstaclesSourceUpdated81b6e983(value(0)),
                ),
              ),
              Text(
                context.localizedWithArgs(
                  "Published: {0} UTC",
                  [snapshot.metadata['datasetPublishedAt'] ?? 'unknown'],
                  (l10n, value) => l10n.obstaclesPublishedUtcc490142e(value(0)),
                ),
              ),
              Text(
                context.localizedWithArgs("Retrieved: {0}", [
                  snapshot.fetchedAt.toIso8601String(),
                ], (l10n, value) => l10n.commonRetrievedc0a8bd29(value(0))),
              ),
              Text(
                context.localizedWithArgs(
                  "Metadata checked: {0}",
                  [snapshot.checkedAt.toIso8601String()],
                  (l10n, value) =>
                      l10n.obstaclesMetadataChecked61ccc766(value(0)),
                ),
              ),
            ],
            Text(
              context.localized(
                "Absolute source heights: LN02. Elevated display: CHGeo2004 + HTRANS to the ETRS89 ellipsoid, used as a WGS84 approximation. Unknown line/area elevations are shown only as a ground marker at their first source vertex. Isolated point obstacles with an official AGL height are displayed at that exact height above the currently rendered terrain; their visualized absolute top may differ from the surveyed LN02 top. Extra KML label points on lines/polygons are not drawn as obstacles. Cable vertices matching published masts follow the same terrain-adjusted mast tops, with interpolated display corrections between supports. Other geometry retains source absolute elevations. Cable sag is not reconstructed; route checks use original source geometry.",
                (l10n) => l10n.commonAbsoluteSourceHeightsLn1571b147,
              ),
            ),
            SelectableText(
              SwissObstacleProvider.obstacleSource.metadataUri.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Text(obstacleCoverageNotice),
            const GuideLink(GuideTopic.obstacles),
          ],
        ),
        const Divider(height: 32),
      ],
    );
  }
}

class ObstacleStatusBanner extends StatelessWidget {
  const ObstacleStatusBanner({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final ObstacleMapController controller;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final error = controller.wmsError ?? controller.vectorError;
      if (error == null) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.warning_amber_outlined),
          title: Text(error, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: TextButton(
            onPressed: onDetails,
            child: Text(
              context.localized(
                "Map layers",
                (l10n) => l10n.commonMapLayersfdee4317,
              ),
            ),
          ),
        ),
      );
    },
  );
}
