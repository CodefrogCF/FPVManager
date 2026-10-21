import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';

/// Only known content gaps occupy map space. Unknown source coverage is always
/// explained in the layer metadata and zone inspection.
class UasDataQualityBanner extends StatelessWidget {
  const UasDataQualityBanner({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final GlobeController controller;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final assessment = controller.uasDatasetAssessment;
      if (!controller.uasZonesVisible ||
          assessment == null ||
          !assessment.hasIssues) {
        return const SizedBox.shrink();
      }
      return Material(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'UAS data limited · ${assessment.renderedFeatureCount}/${assessment.sourceFeatureCount} features displayed',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'UAS data quality',
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
      );
    },
  );
}
