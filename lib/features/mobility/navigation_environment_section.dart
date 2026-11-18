import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../globe/globe_controller.dart';
import '../help/guides_screen.dart';

/// The shared preferences own these choices; the navigation renderer only
/// reports availability and applies a temporary override to its map layers.
class NavigationEnvironmentSection extends StatelessWidget {
  const NavigationEnvironmentSection({
    super.key,
    required this.settings,
    this.renderer,
  });
  final GlobeController settings;
  final GlobeController? renderer;

  @override
  Widget build(BuildContext context) {
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.localized(
                  "3D-Einstellung konnte nicht übernommen werden.",
                  (l10n) => l10n.mobilityDEinstellungKonnteNicht1dd69132,
                ),
              ),
            ),
          );
        }
      }
    }

    Widget layer(
      String key,
      String title,
      NavigationEnvironmentMode mode,
      bool inherited,
      Future<void> Function(NavigationEnvironmentMode) save,
    ) {
      final enabled = mode.override ?? inherited;
      final status = renderer?.sceneLayerStatus(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          SegmentedButton<NavigationEnvironmentMode>(
            segments: [
              ButtonSegment(
                value: NavigationEnvironmentMode.inherit,
                label: Text(
                  context.localized(
                    "Wie Karte",
                    (l10n) => l10n.mobilityWieKarte9cb7c6de,
                  ),
                ),
              ),
              ButtonSegment(
                value: NavigationEnvironmentMode.disabled,
                label: Text(
                  context.localized("Aus", (l10n) => l10n.commonAus6997e3eb),
                ),
              ),
              ButtonSegment(
                value: NavigationEnvironmentMode.enabled,
                label: Text(
                  context.localized("Ein", (l10n) => l10n.commonEin3b564e70),
                ),
              ),
            ],
            selected: {mode},
            onSelectionChanged: settings.canEditPreferences
                ? (value) => change(() => save(value.single))
                : null,
          ),
          if (enabled && status == 'loading') const LinearProgressIndicator(),
          if (enabled && ['partial', 'failed', 'offline'].contains(status))
            Row(
              children: [
                Expanded(
                  child: Text(
                    status == 'partial'
                        ? context.localized(
                            "Einige 3D-Kacheln fehlen.",
                            (l10n) => l10n.mobilityEinigeDKachelnFehlen747d8e09,
                          )
                        : context.localized(
                            "3D-Daten fehlen oder sind offline nicht verfügbar.",
                            (l10n) => l10n.mobilityDDatenFehlenOderdd9b0af0,
                          ),
                  ),
                ),
                IconButton(
                  tooltip: context.localizedWithArgs(
                    "{0} erneut laden",
                    [title],
                    (l10n, value) => l10n.mobilityErneutLaden13159aac(value(0)),
                  ),
                  onPressed: () =>
                      change(() => renderer!.setSceneEnvironment(retry: key)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (settings.preferencesError != null) ...[
          Text(settings.preferencesError!),
          TextButton(
            onPressed: settings.preferencesLoading
                ? null
                : settings.preferencesLoadFailed
                ? settings.retryLoadingPreferences
                : settings.retrySavingPreferences,
            child: Text(
              context.localized(
                "Erneut versuchen",
                (l10n) => l10n.commonErneutVersuchen3234b7ec,
              ),
            ),
          ),
        ],
        Text(
          context.localized(
            "3D-Umgebung in der Navigation",
            (l10n) => l10n.mobilityDUmgebungInDer7e362fb8,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        layer(
          'buildings',
          'Gebäude',
          settings.navigationBuildings,
          settings.buildings3dVisible,
          (value) => settings.setNavigationEnvironment(buildings: value),
        ),
        layer(
          'vegetation',
          'Bäume und Wälder',
          settings.navigationVegetation,
          settings.vegetation3dVisible,
          (value) => settings.setNavigationEnvironment(vegetation: value),
        ),
        const SizedBox(height: 8),
        const Text(
          '© swisstopo · Streaming-Daten erforderlich. Luftfahrthindernisse werden separat eingestellt.',
        ),
        const GuideLink(GuideTopic.mobility),
      ],
    );
  }
}
