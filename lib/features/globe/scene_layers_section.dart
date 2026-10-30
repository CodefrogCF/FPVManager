import 'package:flutter/material.dart';

import 'globe_controller.dart';
import '../help/guides_screen.dart';

class SceneLayersSection extends StatelessWidget {
  const SceneLayersSection({super.key, required this.controller});
  final GlobeController controller;
  @override
  Widget build(BuildContext context) {
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '3D-Einstellung konnte nicht übernommen werden. Bitte erneut versuchen.',
              ),
            ),
          );
        }
      }
    }

    final enabled = controller.isReady && controller.canEditPreferences;
    Widget layer(
      String key,
      String label,
      bool visible,
      Future<void> Function(bool) toggle,
    ) {
      final state = controller.sceneLayerStatus(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: const Text('3D Tiles · © swisstopo'),
            value: visible,
            onChanged: enabled ? (value) => change(() => toggle(value)) : null,
          ),
          if (visible && state == 'loading') const LinearProgressIndicator(),
          if (visible && ['failed', 'partial'].contains(state)) ...[
            Text(
              state == 'partial'
                  ? 'Einige 3D-Kacheln fehlen. Geladene Modelle bleiben sichtbar.'
                  : '3D-Daten derzeit nicht verfügbar.',
            ),
            TextButton.icon(
              onPressed: enabled
                  ? () =>
                        change(() => controller.setSceneEnvironment(retry: key))
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut laden'),
            ),
          ],
        ],
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('3D-Umgebung und Himmelslicht'),
      children: [
        layer(
          'buildings',
          'Gebäude',
          controller.buildings3dVisible,
          (value) => controller.setSceneEnvironment(buildings: value),
        ),
        layer(
          'vegetation',
          'Bäume und Wälder',
          controller.vegetation3dVisible,
          (value) => controller.setSceneEnvironment(vegetation: value),
        ),
        const Text(
          'Schweizer Streaming-Daten · Vegetation modelliert · kein Kollisionsmodell.',
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktueller Sonnen- und Mondstand'),
          subtitle: const Text(
            'Gerätezeit · Tag-/Nachtbeleuchtung ohne zusätzliche Schlagschatten.',
          ),
          value: controller.realisticLighting,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setSceneEnvironment(lighting: value),
                )
              : null,
        ),
        const GuideLink(GuideTopic.map, label: '3D-Daten und Beleuchtung'),
      ],
    );
  }
}
