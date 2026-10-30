import 'package:flutter/material.dart';

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
            const SnackBar(
              content: Text('3D-Einstellung konnte nicht übernommen werden.'),
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
            segments: const [
              ButtonSegment(
                value: NavigationEnvironmentMode.inherit,
                label: Text('Wie Karte'),
              ),
              ButtonSegment(
                value: NavigationEnvironmentMode.disabled,
                label: Text('Aus'),
              ),
              ButtonSegment(
                value: NavigationEnvironmentMode.enabled,
                label: Text('Ein'),
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
                        ? 'Einige 3D-Kacheln fehlen.'
                        : '3D-Daten fehlen oder sind offline nicht verfügbar.',
                  ),
                ),
                IconButton(
                  tooltip: '$title erneut laden',
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
            child: const Text('Erneut versuchen'),
          ),
        ],
        Text(
          '3D-Umgebung in der Navigation',
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
