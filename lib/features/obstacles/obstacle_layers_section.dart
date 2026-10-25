import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'obstacle_map_controller.dart';
import 'obstacle_models.dart';
import 'swiss_obstacle_provider.dart';

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
          'Swiss aviation obstacles',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(obstacleCoverageNotice),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Published obstacles · WMS'),
          subtitle: Text('BAZL / FOCA · geo.admin.ch · ${controller.wmsState}'),
          value: controller.wmsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setWmsVisible(v)))
              : null,
        ),
        if (controller.wmsState == 'loading') const LinearProgressIndicator(),
        Text('Obstacle imagery opacity: ${(opacity * 100).round()}%'),
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
        const Text(
          'Combined raster symbols: no category filters, object selection or precise 3D heights.',
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
            label: const Text('Retry obstacle imagery'),
          ),
        ],
        TextButton.icon(
          icon: const Icon(Icons.legend_toggle),
          label: const Text('Official WMS legend'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('BAZL obstacle legend'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        ObstacleLayersSection.legendUrl,
                        errorBuilder: (_, error, stack) => const Text(
                          'Legend unavailable. Open the official link below.',
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
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selectable obstacles · 3D vector'),
          subtitle: const Text(
            'Full official KMZ · stored locally after import',
          ),
          value: controller.vectorsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setVectorsVisible(v)))
              : null,
        ),
        if (controller.vectorsVisible)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('3D obstacle models'),
            subtitle: const Text(
              'Published height above ground · schematic shape, width and heading',
            ),
            value: controller.modelsVisible,
            onChanged: enabled
                ? (v) => unawaited(run(() => controller.setModelsVisible(v)))
                : null,
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Highlight hazard areas'),
          subtitle: const Text(
            'Advisory horizontal buffers · independent of UAS restrictions',
          ),
          value: controller.hazardsVisible,
          onChanged: enabled
              ? (v) => unawaited(run(() => controller.setHazardsVisible(v)))
              : null,
        ),
        Text(
          'Horizontal buffer: ${(_previewBuffer ?? controller.bufferMeters).toStringAsFixed(0)} m',
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
        const Text(
          'Cyan areas are calculated planning aids around published points and lines. '
          'They do not define legal separation or vertical clearance. A zero buffer draws no area. '
          'Category filters also apply to advisory areas and route proximity checks.',
        ),
        if (busy) const LinearProgressIndicator(),
        Text(controller.provider.progress),
        Text('Data status: ${state.dataState.label}'),
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
            '${snapshot.count} imported objects · ${snapshot.skipped} unsupported records',
          ),
          Text(
            'Source updated: ${snapshot.sourceUpdated?.toIso8601String() ?? 'unknown'}',
          ),
          Text(
            'Published: ${snapshot.metadata['datasetPublishedAt'] ?? 'unknown'} UTC',
          ),
          Text('Retrieved: ${snapshot.fetchedAt.toIso8601String()}'),
          Text('Metadata checked: ${snapshot.checkedAt.toIso8601String()}'),
          Text(
            'Local cache: ${dataset!.freshnessAt(DateTime.now()).name} · source validity: '
            '${dataset.validity?.at(DateTime.now()).name ?? OsintValidity.unknown.name}',
          ),
          if (snapshot.metadata['datasetValidFrom'] != null ||
              snapshot.metadata['datasetValidTo'] != null)
            Text(
              'Published validity: ${snapshot.metadata['datasetValidFrom'] ?? '?'} → ${snapshot.metadata['datasetValidTo'] ?? '?'} UTC',
            ),
          const Text(
            'Cached vectors reopen offline. Published coverage is incomplete; offline imagery and terrain are not included.',
          ),
        ],
        TextButton.icon(
          onPressed: enabled && !busy ? controller.refreshVectors : null,
          icon: const Icon(Icons.sync),
          label: Text(
            snapshot == null
                ? 'Download vector dataset'
                : 'Check source for updates',
          ),
        ),
        const Text(
          'Absolute source heights: LN02. Elevated display: CHGeo2004 + HTRANS to the '
          'ETRS89 ellipsoid, used as a WGS84 approximation. Unknown line/area elevations are shown only as a ground marker at their first source vertex. '
          'Isolated point obstacles with an official AGL height are displayed at that exact height above the currently rendered terrain; their visualized absolute top may differ from the surveyed LN02 top. '
          'Extra KML label points on lines/polygons are not drawn as obstacles. '
          'Cable vertices matching published masts follow the same terrain-adjusted mast tops, with interpolated display corrections between supports. '
          'Other geometry retains source absolute elevations. Cable sag is not reconstructed; route checks use original source geometry.',
        ),
        SelectableText(
          SwissObstacleProvider.obstacleSource.metadataUri.toString(),
          style: Theme.of(context).textTheme.bodySmall,
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
            child: const Text('Map layers'),
          ),
        ),
      );
    },
  );
}
