import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import 'globe_controller.dart';

/// A terrain outage does not replace the working map or its layer controls.
class TerrainStatusBanner extends StatelessWidget {
  const TerrainStatusBanner({super.key, required this.controller});

  final GlobeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (!controller.isReady ||
          (controller.terrainAvailable && !controller.terrainResourceWarning)) {
        return const SizedBox.shrink();
      }
      final busy =
          controller.terrainRetrying ||
          controller.terrainState == GlobeTerrainState.loading;
      final message = controller.terrainAvailable
          ? 'Some terrain tiles are unavailable. Loaded 3D terrain remains visible; heights may be missing in affected areas.'
          : busy
          ? 'Connecting to 3D terrain. Flat map shown.'
          : controller.terrainState == GlobeTerrainState.offline
          ? 'Offline: flat map shown. Terrain heights are unavailable.'
          : '3D terrain unavailable. Flat map shown; terrain heights are disabled.';
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final description = Row(
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.terrain_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(context.translate(message)),
                      ),
                    ),
                  ],
                );
                final retry = TextButton(
                  onPressed: controller.canRetryTerrain
                      ? () async {
                          try {
                            await controller.retryTerrain();
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.translate(
                                    "Unable to reconnect to terrain. Please retry.",
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text(context.translate("Retry terrain")),
                );
                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      description,
                      Align(alignment: Alignment.centerRight, child: retry),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 8),
                    retry,
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
