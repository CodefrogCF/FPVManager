import 'package:flutter/material.dart';

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ground view: $error')));
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
          controller.groundViewActive || controller.groundViewPending;
      return IconButton(
        tooltip: controller.groundViewPending
            ? 'Cancel spawn'
            : running
            ? 'Return to globe'
            : 'Spawn here',
        onPressed: running
            ? () => _run(context, controller.exitGroundView)
            : controller.isReady &&
                  controller.terrainAvailable &&
                  lat != null &&
                  lon != null
            ? () => _run(
                context,
                () => controller.enterGroundView(latitude: lat, longitude: lon),
              )
            : null,
        icon: controller.groundViewPending
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
