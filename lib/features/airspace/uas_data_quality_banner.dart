import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';
import '../../core/osint/osint_provider_state.dart';

/// Warn about the displayed snapshot's age/update failures and known gaps.
/// Unknown coverage remains explicit in layer metadata and zone inspection.
class UasDataQualityBanner extends StatefulWidget {
  const UasDataQualityBanner({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final GlobeController controller;
  final VoidCallback onDetails;

  @override
  State<UasDataQualityBanner> createState() => _UasDataQualityBannerState();
}

class _UasDataQualityBannerState extends State<UasDataQualityBanner> {
  Timer? _ageTimer;
  @override
  void initState() {
    super.initState();
    _ageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final assessment = controller.uasDatasetAssessment;
      final status = controller.uasDisplayedStatus;
      final state = status.dataState;
      if ((!controller.uasZonesVisible && !controller.uasRequestedVisible) ||
          state == OsintDataState.fresh &&
              (!controller.uasZonesVisible || assessment?.hasIssues != true) ||
          controller.uasZonesLoading && status.dataset == null) {
        return const SizedBox.shrink();
      }
      final message = state == OsintDataState.fresh && assessment != null
          ? 'UAS data limited · ${assessment.renderedFeatureCount}/${assessment.sourceFeatureCount} features displayed'
          : status.dataset == null
          ? 'UAS data unavailable · check official sources'
          : 'UAS · ${state.label} · check official sources';
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
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'UAS data quality',
                onPressed: widget.onDetails,
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
      );
    },
  );
}
