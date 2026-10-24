import 'package:flutter/material.dart';

import 'globe_controller.dart';
import 'map_display_section.dart';
import 'uas_map_layers_section.dart';
import '../obstacles/obstacle_layers_section.dart';

enum MapLayerTab { map, airspace, obstacles, situational }

class MapLayersSheet extends StatelessWidget {
  const MapLayersSheet({
    super.key,
    required this.controller,
    this.routeControls,
    this.situationalControls,
    this.initialTab = MapLayerTab.map,
  });
  final GlobeController controller;
  final Widget? routeControls;
  final Widget? situationalControls;
  final MapLayerTab initialTab;
  @override
  Widget build(BuildContext context) {
    Future<void> execute(Future<void> Function() command) async {
      try {
        await command();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update map preferences. Please retry.'),
            ),
          );
        }
      }
    }

    Widget page(String key, Widget child) => SingleChildScrollView(
      key: PageStorageKey(key),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: child,
    );
    return SafeArea(
      top: false,
      child: DefaultTabController(
        length: 4,
        initialIndex: initialTab.index,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Map Layers'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              if (controller.preferencesLoading) ...[
                const LinearProgressIndicator(),
                const Text('Loading saved map preferences...'),
                const SizedBox(height: 12),
              ],
              if (controller.preferencesError != null) ...[
                Text(
                  controller.preferencesError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: controller.preferencesLoading
                          ? null
                          : () => execute(
                              controller.preferencesLoadFailed
                                  ? controller.retryLoadingPreferences
                                  : controller.retrySavingPreferences,
                            ),
                      child: const Text('Retry'),
                    ),
                    if (controller.preferencesLoadFailed)
                      TextButton(
                        onPressed: controller.preferencesLoading
                            ? null
                            : () => execute(controller.resetPreferences),
                        child: const Text('Reset map preferences'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Map'),
                  Tab(text: 'Airspace'),
                  Tab(text: 'Obstacles'),
                  Tab(text: 'OSINT'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    page(
                      'map-display',
                      MapDisplaySection(
                        controller: controller,
                        routeControls: routeControls,
                      ),
                    ),
                    page(
                      'map-airspace',
                      UasMapLayersSection(controller: controller),
                    ),
                    page(
                      'map-obstacles',
                      ObstacleLayersSection(
                        controller: controller.obstacles,
                        enabled:
                            controller.isReady && controller.canEditPreferences,
                      ),
                    ),
                    page(
                      'map-situational',
                      situationalControls ??
                          const Text(
                            'Open Mobility & OSINT to load independent information layers.',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
