import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
                      tooltip: context.translate("Close obstacle details"),
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  context.translate("Type: {0} · {1}", [
                    feature.sourceType.isEmpty ? 'unknown' : feature.sourceType,
                    feature.category.label,
                  ]),
                ),
                SelectableText(
                  context.translate("Source ID: {0}\nUUID: {1}", [
                    feature.id,
                    feature.attributes['uuid'] ?? 'unknown',
                  ]),
                ),
                Text(
                  context.translate("First coordinate: {0}, {1} · WGS84", [
                    first[1].toStringAsFixed(7),
                    first[0].toStringAsFixed(7),
                  ]),
                ),
                Text(
                  context.translate("Top elevation: {0}", [
                    feature.attributes['topElevationAMSL']?.isNotEmpty == true
                        ? '${feature.attributes['topElevationAMSL']} m LN02'
                        : 'unknown',
                  ]),
                ),
                Text(
                  context.translate("Source maximum height: {0}", [
                    feature.attributes['maxHeightAGL']?.isNotEmpty == true
                        ? '${feature.attributes['maxHeightAGL']} m AGL'
                        : 'unknown',
                  ]),
                ),
                for (final p in feature.parts)
                  Text(
                    context.translate(
                      "{0}: {1} vertices · altitude mode: {2} · {3}",
                      [
                        p.kind,
                        p.coordinates.length,
                        p.mode,
                        p.mode == 'absolute' &&
                                p.coordinates.every((a) => a.length == 3)
                            ? 'LN02 elevations; 3D where CHGeo2004 covers the position'
                            : 'ground marker at first vertex; elevated geometry unavailable',
                      ],
                    ),
                  ),
                for (final p in feature.parts)
                  if (p.coordinates.first.length == 3)
                    Text(
                      context.translate(
                        "First source vertex height: {0} m · {1}",
                        [
                          p.coordinates.first[2],
                          p.mode == 'absolute'
                              ? 'LN02'
                              : p.mode == 'relativeToGround'
                              ? 'relative to ground'
                              : 'reference not usable for elevated display',
                        ],
                      ),
                    ),
                if (feature.approximate)
                  Text(
                    context.translate(
                      "Approximate geometry: straight connections / polygon outlines from the source. Actual cable sag and obstacle surfaces are not defined.",
                    ),
                  ),
                Text(
                  context.translate(
                    "Height conversion: CHGeo2004 + HTRANS → ETRS89 ellipsoid (WGS84 approximation). For single Point obstacles with valid AGL, the rendered marker and height stem use local Cesium terrain + source AGL; the source top AMSL remains listed above and may differ. Cable vertices that match a unique published mast (within 2 m horizontally and 5 m in source top elevation) follow its displayed top; offsets between matched supports are interpolated. This is an approximate display correction, not surveyed cable geometry. Unmatched sections retain source heights. Route checks use original source elevations.",
                  ),
                ),
                Text(
                  context.translate("Effective date: {0} UTC", [
                    feature.attributes['effectiveDate'] ?? 'unknown',
                  ]),
                ),
                Text(
                  context.translate("Source updated: {0}\nRetrieved: {1}", [
                    snapshot?.sourceUpdated?.toIso8601String() ?? 'unknown',
                    snapshot?.fetchedAt.toIso8601String() ?? 'unknown',
                  ]),
                ),
                const Text('BAZL / FOCA · Skyguide · geo.admin.ch'),
                SelectableText(
                  snapshot?.assetUrl ??
                      context.translate("Source asset unavailable"),
                ),
                if (snapshot?.metadata['datasetUsageRestriction']
                    case final String restriction)
                  Text(restriction),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(context.translate("Source attributes")),
                  children: [
                    for (final e in feature.attributes.entries)
                      ListTile(
                        dense: true,
                        title: Text(e.key),
                        subtitle: SelectableText(
                          e.value.isEmpty
                              ? context.translate("Not supplied")
                              : e.value,
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
