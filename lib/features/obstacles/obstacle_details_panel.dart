import 'package:flutter/material.dart';

import 'obstacle_models.dart';
import 'obstacle_layers_section.dart';

class ObstacleDetailsPanel extends StatelessWidget {
  const ObstacleDetailsPanel({
    super.key,
    required this.feature,
    required this.snapshot,
    required this.onClose,
  });
  final ObstacleFeature feature;
  final ObstacleSnapshot? snapshot;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final first = feature.parts.first.coordinates.first;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.42,
        ),
        child: Card(
          margin: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close obstacle details',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Type: ${feature.sourceType.isEmpty ? 'unknown' : feature.sourceType} · ${feature.category.label}',
                ),
                SelectableText(
                  'Source ID: ${feature.id}\nUUID: ${feature.attributes['uuid'] ?? 'unknown'}',
                ),
                Text(
                  'First coordinate: ${first[1].toStringAsFixed(7)}, ${first[0].toStringAsFixed(7)} · WGS84',
                ),
                Text(
                  'Top elevation: ${feature.attributes['topElevationAMSL']?.isNotEmpty == true ? '${feature.attributes['topElevationAMSL']} m LN02' : 'unknown'}',
                ),
                Text(
                  'Source maximum height: ${feature.attributes['maxHeightAGL']?.isNotEmpty == true ? '${feature.attributes['maxHeightAGL']} m AGL' : 'unknown'}',
                ),
                for (final p in feature.parts)
                  Text(
                    '${p.kind}: ${p.coordinates.length} vertices · altitude mode: ${p.mode} · '
                    '${p.mode == 'absolute' && p.coordinates.every((a) => a.length == 3) ? 'LN02 elevations; 3D where CHGeo2004 covers the position' : 'ground marker at first vertex; elevated geometry unavailable'}',
                  ),
                for (final p in feature.parts)
                  if (p.coordinates.first.length == 3)
                    Text(
                      'First source vertex height: ${p.coordinates.first[2]} m · '
                      '${p.mode == 'absolute'
                          ? 'LN02'
                          : p.mode == 'relativeToGround'
                          ? 'relative to ground'
                          : 'reference not usable for elevated display'}',
                    ),
                if (feature.approximate)
                  const Text(
                    'Approximate geometry: straight connections / polygon outlines from the source. '
                    'Actual cable sag and obstacle surfaces are not defined.',
                  ),
                const Text(
                  'Height conversion: CHGeo2004 + HTRANS → ETRS89 ellipsoid (WGS84 approximation). '
                  'Source AGL is never used to invent missing cable elevations.',
                ),
                Text(
                  'Effective date: ${feature.attributes['effectiveDate'] ?? 'unknown'} UTC',
                ),
                Text(
                  'Source updated: ${snapshot?.sourceUpdated?.toIso8601String() ?? 'unknown'}\n'
                  'Retrieved: ${snapshot?.fetchedAt.toIso8601String() ?? 'unknown'}',
                ),
                const Text('BAZL / FOCA · Skyguide · geo.admin.ch'),
                SelectableText(
                  snapshot?.assetUrl ?? 'Source asset unavailable',
                ),
                if (snapshot?.metadata['datasetUsageRestriction']
                    case final String restriction)
                  Text(restriction),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Source attributes'),
                  children: [
                    for (final e in feature.attributes.entries)
                      ListTile(
                        dense: true,
                        title: Text(e.key),
                        subtitle: SelectableText(
                          e.value.isEmpty ? 'Not supplied' : e.value,
                        ),
                      ),
                  ],
                ),
                const Text(obstacleCoverageNotice),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
