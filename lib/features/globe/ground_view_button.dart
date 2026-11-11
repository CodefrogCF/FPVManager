import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import 'globe_controller.dart';

/// Shared entry point for terrain-relative inspection; movement lives in Cesium.
class GroundViewButton extends StatelessWidget {
  const GroundViewButton({
    super.key,
    required this.controller,
    this.onCommand,
    this.latitude,
    this.longitude,
  });
  final GlobeController controller;
  final double? latitude, longitude;
  final Future<void> Function(Future<void> Function())? onCommand;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (onCommand != null) return onCommand!(action);
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate("Ground view: {0}", [error])),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final lat = latitude ?? controller.selectedPoint?.latitude;
      final lon = longitude ?? controller.selectedPoint?.longitude;
      final running =
          controller.groundViewActive ||
          controller.groundViewPending ||
          controller.simulationActive ||
          controller.simulationPending;
      final pending =
          controller.groundViewPending || controller.simulationPending;
      return IconButton(
        tooltip: pending
            ? context.translate("Cancel spawn")
            : running
            ? context.translate("Return to globe")
            : context.translate("Spawn here"),
        onPressed: running
            ? () => _run(context, controller.exitNavigation)
            : controller.isReady &&
                  controller.terrainAvailable &&
                  lat != null &&
                  lon != null
            ? () => _run(
                context,
                () => controller.enterGroundView(latitude: lat, longitude: lon),
              )
            : null,
        icon: pending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(running ? Icons.public : Icons.directions_walk),
        color: running ? Theme.of(context).colorScheme.primary : null,
      );
    },
  );
}
