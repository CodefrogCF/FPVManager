import 'package:flutter/material.dart';

import 'globe_controller.dart';

/// Shared entry point for terrain-relative inspection; movement lives in Cesium.
class GroundViewBar extends StatelessWidget {
  const GroundViewBar({super.key, required this.controller, this.onCommand});
  final GlobeController controller;
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
      final point = controller.selectedPoint;
      if (!controller.groundViewActive &&
          !controller.groundViewPending &&
          point == null &&
          controller.groundViewMessage == null) {
        return const SizedBox.shrink();
      }
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                controller.groundViewActive
                    ? 'Ground view · ≈ 2 m · Arrow keys to walk · Drag to look'
                    : controller.groundViewPending
                    ? 'Sampling terrain at spawn point…'
                    : controller.groundViewMessage ??
                          'Selected point · Spawn to inspect from ground level',
              ),
              if (controller.groundViewActive || controller.groundViewPending)
                OutlinedButton(
                  onPressed: () => _run(context, controller.exitGroundView),
                  child: const Text('Return to globe'),
                )
              else
                FilledButton.icon(
                  onPressed:
                      controller.isReady &&
                          controller.terrainAvailable &&
                          point != null
                      ? () => _run(
                          context,
                          () => controller.enterGroundView(
                            latitude: point.latitude,
                            longitude: point.longitude,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Spawn here'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
