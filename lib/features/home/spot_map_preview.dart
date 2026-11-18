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
                tooltip: context.localized(
                  "More spot actions",
                  (l10n) => l10n.homeMoreSpotActionsec926581,
                ),
                onSelected: (action) => switch (action) {
                  _SpotAction.airspace => onAirspace(),
                  _SpotAction.photos => onPhotos(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SpotAction.airspace,
                    child: Text(
                      context.localized(
                        "Check airspace",
                        (l10n) => l10n.homeCheckAirspace81aa4af7,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SpotAction.photos,
                    child: Text(
                      context.localized(
                        "Photos",
                        (l10n) => l10n.commonPhotosc8b2e864,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: context.localized(
                  "Close spot details",
                  (l10n) => l10n.homeCloseSpotDetailsb8c47dc2,
                ),
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
                label: Text(
                  context.localized(
                    "Details",
                    (l10n) => l10n.homeDetailsdc3decbb,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onFocus,
                icon: const Icon(Icons.navigation),
                label: Text(
                  context.localized(
                    "Fly to Spot",
                    (l10n) => l10n.homeFlyToSpot253cde4f,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
