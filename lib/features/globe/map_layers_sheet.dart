import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
    this.onOpenSettings,
  });
  final GlobeController controller;
  final Widget? routeControls;
  final Widget? situationalControls;
  final MapLayerTab initialTab;
  final VoidCallback? onOpenSettings;
  @override
  Widget build(BuildContext context) {
    Future<void> execute(Future<void> Function() command) async {
      try {
        await command();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.translate(
                  "Unable to update map preferences. Please retry.",
                ),
              ),
            ),
          );
        }
      }
    }

    Widget page(String key, Widget child) => SingleChildScrollView(
      key: PageStorageKey(key),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                title: Text(context.translate("Karte & Ansicht")),
                dense: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onOpenSettings != null)
                      IconButton(
                        tooltip: context.translate("Allgemeine Einstellungen"),
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    IconButton(
                      tooltip: context.translate("Schließen"),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (controller.preferencesLoading) ...[
                const LinearProgressIndicator(),
                Text(context.translate("Karteneinstellungen werden geladen …")),
                const SizedBox(height: 12),
              ],
              if (controller.preferencesError != null) ...[
                Text(
                  context.translate(controller.preferencesError!),
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
                      child: Text(context.translate("Erneut versuchen")),
                    ),
                    if (controller.preferencesLoadFailed)
                      TextButton(
                        onPressed: controller.preferencesLoading
                            ? null
                            : () => execute(controller.resetPreferences),
                        child: Text(
                          context.translate("Karteinstellungen zurücksetzen"),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: context.translate('Karte')),
                  Tab(text: context.translate('Luftraum')),
                  Tab(text: context.translate('Hindernisse')),
                  const Tab(text: 'OSINT'),
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
                          Text(
                            context.translate(
                              "Weitere Datenebenen unter Mobilität & OSINT laden.",
                            ),
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
