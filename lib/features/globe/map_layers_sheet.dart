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
                context.localized(
                  "Unable to update map preferences. Please retry.",
                  (l10n) => l10n.globeUnableToUpdateMap7af0a9ee,
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
                title: Text(
                  context.localized(
                    "Karte & Ansicht",
                    (l10n) => l10n.commonKarteAnsichtb4cd1571,
                  ),
                ),
                dense: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onOpenSettings != null)
                      IconButton(
                        tooltip: context.localized(
                          "Allgemeine Einstellungen",
                          (l10n) => l10n.globeAllgemeineEinstellungen6f965a12,
                        ),
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    IconButton(
                      tooltip: context.localized(
                        "Schließen",
                        (l10n) => l10n.commonSchliessen44424b18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (controller.preferencesLoading) ...[
                const LinearProgressIndicator(),
                Text(
                  context.localized(
                    "Karteneinstellungen werden geladen …",
                    (l10n) =>
                        l10n.globeKarteneinstellungenWerdenGeladen349c7e7f,
                  ),
                ),
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
                      child: Text(
                        context.localized(
                          "Erneut versuchen",
                          (l10n) => l10n.commonErneutVersuchen3234b7ec,
                        ),
                      ),
                    ),
                    if (controller.preferencesLoadFailed)
                      TextButton(
                        onPressed: controller.preferencesLoading
                            ? null
                            : () => execute(controller.resetPreferences),
                        child: Text(
                          context.localized(
                            "Karteinstellungen zurücksetzen",
                            (l10n) => l10n
                                .globeKarteinstellungenZuruecksetzen3bd1cc02,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    text: context.localized(
                      'Karte',
                      (l10n) => l10n.globeKarteb1636a3d,
                    ),
                  ),
                  Tab(
                    text: context.localized(
                      'Luftraum',
                      (l10n) => l10n.globeLuftraum0992aecb,
                    ),
                  ),
                  Tab(
                    text: context.localized(
                      'Hindernisse',
                      (l10n) => l10n.globeHindernissed58845a0,
                    ),
                  ),
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
                            context.localized(
                              "Weitere Datenebenen unter Mobilität & OSINT laden.",
                              (l10n) => l10n
                                  .globeWeitereDatenebenenUnterMobilitaetd36898b1,
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
