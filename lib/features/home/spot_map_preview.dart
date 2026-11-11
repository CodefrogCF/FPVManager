import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../spots/data/spot_query.dart';

enum _SpotAction { airspace, photos }

class SpotMapPreview extends StatelessWidget {
  const SpotMapPreview({
    super.key,
    required this.spot,
    required this.onClose,
    required this.onDetails,
    required this.onFocus,
    required this.onAirspace,
    required this.onPhotos,
  });
  final SpotMapEntry spot;
  final VoidCallback onClose, onDetails, onFocus, onAirspace, onPhotos;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${spot.latitude.toStringAsFixed(8)}, ${spot.longitude.toStringAsFixed(8)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_SpotAction>(
                tooltip: context.translate("More spot actions"),
                onSelected: (action) => switch (action) {
                  _SpotAction.airspace => onAirspace(),
                  _SpotAction.photos => onPhotos(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SpotAction.airspace,
                    child: Text(context.translate("Check airspace")),
                  ),
                  PopupMenuItem(
                    value: _SpotAction.photos,
                    child: Text(context.translate("Photos")),
                  ),
                ],
              ),
              IconButton(
                tooltip: context.translate("Close spot details"),
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline),
                label: Text(context.translate("Details")),
              ),
              FilledButton.icon(
                onPressed: onFocus,
                icon: const Icon(Icons.navigation),
                label: Text(context.translate("Fly to Spot")),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
