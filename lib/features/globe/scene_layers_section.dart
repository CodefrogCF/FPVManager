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
          if (visible && ['failed', 'partial', 'offline'].contains(state)) ...[
            Text(
              state == 'partial'
                  ? 'Einige 3D-Kacheln fehlen. Geladene Modelle bleiben sichtbar.'
                  : state == 'offline'
                  ? '3D-Daten offline nicht vollständig verfügbar.'
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
        layer(
          'structures',
          'Brücken und 3D-Bauwerke',
          controller.structures3dVisible,
          (value) => controller.setSceneEnvironment(structures: value),
        ),
        if (controller.structures3dVisible)
          Row(
            children: [
              const Text('Bauwerke-Deckkraft'),
              Expanded(
                child: Slider(
                  value: controller.structuresOpacity,
                  min: .2,
                  max: 1,
                  divisions: 8,
                  onChanged: enabled
                      ? (value) => change(
                          () => controller.setSceneEnvironment(
                            structuresOpacity: value,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        const Text(
          'Offizielle swisstopo-3D-Tiles; einzelne Brücken oder andere Bauwerke können fehlen. Keine Kollisionsfreigabe.',
        ),
        if (controller.selectedInfrastructure != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ausgewähltes Infrastrukturobjekt · swisstopo'),
                  Text(
                    'Quelle: ${controller.selectedInfrastructure!['source']}',
                  ),
                  if (controller.selectedInfrastructure!['name'] is String)
                    Text('Name: ${controller.selectedInfrastructure!['name']}'),
                  if (controller.selectedInfrastructure!['sourceId'] != null)
                    Text(
                      'Quellkennung: ${controller.selectedInfrastructure!['sourceId']}',
                    ),
                  if (controller.selectedInfrastructure!['attributes'] is Map)
                    for (final entry
                        in (controller.selectedInfrastructure!['attributes']
                                as Map)
                            .entries)
                      Text('${entry.key}: ${entry.value}'),
                  const Text(
                    'Höhenbezug und Modellvollständigkeit nur gemäß Originaldaten; keine Durchflugfreigabe.',
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tunnelverläufe und Unterführungen'),
          subtitle: const Text(
            'swissTLM3D Verkehrsachsen · schematischer Verlauf auf der Geländeoberfläche, keine Tunnelröhre.',
          ),
          value: controller.tunnelRoutesVisible,
          onChanged: enabled
              ? (value) => change(
                  () =>
                      controller.setTunnelInfrastructure(routesVisible: value),
                )
              : null,
        ),
        if (controller.tunnelRoutesVisible) ...[
          Row(
            children: [
              const Text('Tunnelachse-Deckkraft'),
              Expanded(
                child: Slider(
                  value: controller.tunnelRoutesOpacity,
                  min: .2,
                  max: 1,
                  divisions: 8,
                  onChanged: enabled
                      ? (value) => change(
                          () => controller.setTunnelInfrastructure(
                            opacity: value,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schematische Tunnel-Erkundung erlauben'),
            subtitle: const Text(
              'Kamerafahrt oberhalb des Geländes entlang einer veröffentlichten Achse; kein Tunnel-Durchflug.',
            ),
            value: controller.tunnelExplorationEnabled,
            onChanged: enabled
                ? (value) => change(
                    () => controller.setTunnelInfrastructure(
                      explorationAllowed: value,
                    ),
                  )
                : null,
          ),
          TextButton.icon(
            onPressed: enabled && !controller.tunnelScanPending
                ? () => change(() => controller.scanTunnelRoutes())
                : null,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Tunnelachsen um Kartenmitte suchen (600 m)'),
          ),
          if (controller.tunnelScanPending) const LinearProgressIndicator(),
          if (controller.tunnelScanError != null)
            Text('Abfrage fehlgeschlagen: ${controller.tunnelScanError}'),
          if (controller.tunnelScanIncomplete)
            const Text(
              'Datenabdeckung unvollständig oder Quellenanfrage begrenzt; fehlende Objekte sind nicht ausgeschlossen.',
            ),
          if (controller.tunnelRoutes.isEmpty &&
              !controller.tunnelScanPending &&
              controller.tunnelScanError == null)
            const Text(
              'Keine Tunnelachsen geladen. Suche bewusst manuell starten; Offline-Abfrage nicht verfügbar.',
            ),
          for (final route in controller.tunnelRoutes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(route['name'] as String),
              subtitle: Text(
                '${route['transport']} · ${route['kind']} · swisstopo · Portalhöhen unbekannt',
              ),
              isThreeLine: false,
              trailing: PopupMenuButton<String>(
                tooltip: 'Tunnelroute erkunden',
                onSelected: (action) => change(() async {
                  final id = route['id'] as String;
                  if (action == 'start') {
                    await controller.focusTunnelRoute(id);
                  } else if (action == 'end') {
                    await controller.focusTunnelRoute(id, end: true);
                  } else if (action == 'explore') {
                    await controller.exploreTunnelRoute(id);
                  }
                }),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'start',
                    child: Text('Zum ersten Achsenpunkt'),
                  ),
                  const PopupMenuItem(
                    value: 'end',
                    child: Text('Zum letzten Achsenpunkt'),
                  ),
                  if (controller.tunnelExplorationEnabled)
                    const PopupMenuItem(
                      value: 'explore',
                      child: Text('Schematische Oberflächen-Erkundung'),
                    ),
                ],
              ),
            ),
          if (controller.tunnelExploring)
            TextButton.icon(
              onPressed: enabled
                  ? () => change(() => controller.exitTunnelExploration())
                  : null,
              icon: const Icon(Icons.close),
              label: const Text(
                'Erkundung beenden und Kartenkamera wiederherstellen',
              ),
            ),
          if (controller.tunnelExploreMessage != null)
            Text(controller.tunnelExploreMessage!),
          const Text(
            'Achsenenden sind keine vermessenen Tunnelportale. Keine Angaben zu Hohlraum, Lichtraumprofil, Flughindernissen oder Zugangsberechtigung.',
          ),
        ],
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
