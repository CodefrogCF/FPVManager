import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'globe_controller.dart';

class SceneLayersSection extends StatelessWidget {
  const SceneLayersSection({super.key, required this.controller});
  final GlobeController controller;
  @override
  Widget build(BuildContext context) {
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        if (context.mounted) {
          final detail = error.toString();
          final message = detail.length > 180
              ? '${detail.substring(0, 180)}…'
              : detail;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('3D-Aktion fehlgeschlagen: $message')),
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
      key: const PageStorageKey('map-3d-environment'),
      tilePadding: EdgeInsets.zero,
      title: const Text('3D & Licht'),
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
          'Brücken und Bauwerke',
          controller.structures3dVisible,
          (value) => controller.setSceneEnvironment(structures: value),
        ),
        if (controller.structures3dVisible)
          Row(
            children: [
              const Expanded(child: Text('Deckkraft')),
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('3D-Tunnel automatisch laden'),
          subtitle: const Text(
            'Simulation · Online-Ersatzsuche sendet Kartenausschnitt.',
          ),
          value: controller.schematicTunnel3dEnabled,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setTunnelInfrastructure(autoModels: value),
                )
              : null,
        ),
        if (controller.schematicTunnel3dEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${controller.schematicTunnelMeshCount} / '
              '${controller.schematicTunnelMeshBudget} Tunnel geladen',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (controller.schematicTunnelMeshError != null)
          Text(
            'Tunnel: ${controller.schematicTunnelMeshError}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sonnen- und Mondlicht'),
          subtitle: const Text('Tag und Nacht nach Gerätezeit.'),
          value: controller.realisticLighting,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setSceneEnvironment(lighting: value),
                )
              : null,
        ),
        ExpansionTile(
          key: const PageStorageKey('map-tunnel-tools'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Tunnelwerkzeuge'),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('3D-Modellkollisionen (experimentell)'),
              subtitle: const Text(
                'Experimentell · geladene Modelloberflächen, keine exakte Wandprüfung.',
              ),
              value: controller.sceneModelCollisionsEnabled,
              onChanged: enabled
                  ? (value) => change(
                      () => controller.setSceneEnvironment(
                        modelCollisions: value,
                      ),
                    )
                  : null,
            ),
            TextButton.icon(
              onPressed: enabled && !controller.tunnelScanPending
                  ? () => change(() => controller.scanTunnelRoutes())
                  : null,
              icon: const Icon(Icons.travel_explore),
              label: const Text('Tunnel in der Nähe suchen'),
            ),
            if (controller.tunnelScanPending) const LinearProgressIndicator(),
            if (controller.tunnelScanError != null)
              Text('Abfrage fehlgeschlagen: ${controller.tunnelScanError}'),
            if (controller.tunnelScanIncomplete)
              const Text('Tunnelabdeckung unvollständig.'),
            if (controller.tunnelRoutes.isEmpty &&
                !controller.tunnelScanPending &&
                controller.tunnelScanError == null)
              const Text('Noch keine Tunnel gefunden.'),
            for (final route in controller.tunnelRoutes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(route['name'] as String),
                subtitle: Text('${route['transport']} · ${route['source']}'),
                isThreeLine: false,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Tunnelaktionen',
                  onSelected: (action) => change(() async {
                    final id = route['id'] as String;
                    if (action == 'start') {
                      await controller.focusTunnelRoute(id);
                    } else if (action == 'end') {
                      await controller.focusTunnelRoute(id, end: true);
                    } else if (action == 'model') {
                      await controller.prepareTunnelModel(id);
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
                    const PopupMenuItem(
                      value: 'model',
                      child: Text('3D-Gewölbetunnel erzeugen (synthetisch)'),
                    ),
                  ],
                ),
              ),
            if (controller.tunnelModelPending) const LinearProgressIndicator(),
            if (controller.tunnelModelError != null)
              Text('3D-Tunnel: ${controller.tunnelModelError}'),
            if (controller.tunnelModelReady) ...[
              if (controller.tunnelModelSource != null)
                Text('Modellquelle: ${controller.tunnelModelSource}'),
              Text(
                controller.tunnelModelQuality == 'simulation-only'
                    ? 'Synthetisches Modell · Portale und Abmessungen geschätzt. Nur Simulation, keine reale Durchflugfreigabe.'
                    : controller.tunnelModelQuality ==
                          'external-mesh-unverified'
                    ? 'Importiertes Mesh · Herkunft und Höhenbezug nicht unabhängig geprüft. Geländeöffnung erforderlich.'
                    : 'Importiertes Modell · Herkunft und Lichtraum ungeprüft. Keine reale Durchflugfreigabe.',
              ),
              if (controller.tunnelMeshTriangles != null)
                Text(
                  'Sichtdreiecke: ${controller.tunnelMeshTriangles} · '
                  'Kollisionsdreiecke: ${controller.tunnelCollisionTriangles ?? 0}',
                ),
              if (!controller.tunnelModelCanFly)
                const Text(
                  'Durchflug nicht verfügbar: Angaben zu '
                  'Einstieg, Höhenprofil oder Terrain-Ausschnitten.',
                ),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in const ['gps', 'angle', 'acro'])
                    OutlinedButton(
                      onPressed:
                          enabled &&
                              !controller.tunnelModelPending &&
                              controller.tunnelModelCanFly
                          ? () => change(
                              () => controller.enterTunnelFlight(mode: mode),
                            )
                          : null,
                      child: Text('Durchflug: ${mode.toUpperCase()}'),
                    ),
                  TextButton.icon(
                    onPressed: enabled
                        ? () => change(controller.removeTunnelModel)
                        : null,
                    icon: const Icon(Icons.close),
                    label: const Text('3D-Tunnel entfernen'),
                  ),
                ],
              ),
            ],
            if (controller.selectedInfrastructure != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ausgewähltes Bauwerk'),
                      Text(
                        'Quelle: ${controller.selectedInfrastructure!['datasetSource']}',
                      ),
                      if (controller.selectedInfrastructure!['name'] is String)
                        Text(
                          'Name: ${controller.selectedInfrastructure!['name']}',
                        ),
                      if (controller.selectedInfrastructure!['sourceId'] !=
                          null)
                        Text(
                          'Quellkennung: ${controller.selectedInfrastructure!['sourceId']}',
                        ),
                      if (controller.selectedInfrastructure!['attributes']
                          is Map)
                        for (final entry
                            in (controller.selectedInfrastructure!['attributes']
                                    as Map)
                                .entries)
                          Text('${entry.key}: ${entry.value}'),
                      const Text('Originaldaten · keine Durchflugfreigabe.'),
                      if (controller.selectedInfrastructure!['id'] is String &&
                          {'tunnel', 'underpass'}.contains(
                            controller.selectedInfrastructure!['kind'],
                          ))
                        TextButton.icon(
                          onPressed: enabled && !controller.tunnelModelPending
                              ? () => change(
                                  () => controller.prepareTunnelModel(
                                    controller.selectedInfrastructure!['id']
                                        as String,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text('Aus Achse 3D-Gewölbe simulieren'),
                        ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: enabled && !controller.tunnelModelPending
                  ? () => change(() async {
                      final file = await openFile(
                        acceptedTypeGroups: [
                          const XTypeGroup(
                            label:
                                'Georeferenced tunnel mesh or cross sections',
                            extensions: ['json'],
                          ),
                        ],
                      );
                      if (file == null) return;
                      if (await file.length() > 2097152) {
                        throw const FormatException(
                          'Tunnel geometry exceeds 2 MiB',
                        );
                      }
                      final data = jsonDecode(await file.readAsString());
                      if (data is! Map<String, dynamic>) {
                        throw const FormatException(
                          'Expected tunnel geometry object',
                        );
                      }
                      await controller.importTunnelModel(data);
                    })
                  : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Tunnelmodell importieren (JSON)'),
            ),
            const Text(
              'JSON mit EPSG:4979, Quelle und separatem Kollisionsmesh. '
              'GLB/IFC werden nicht direkt unterstützt.',
            ),
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey('map-tunnel-data'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Tunnelstatus & Daten'),
          children: [
            if (controller.structures3dVisible) ...[
              if (controller.tunnelAutoState == 'loading')
                const LinearProgressIndicator(),
              Text(switch (controller.tunnelAutoState) {
                'ready' =>
                  controller.tunnelAutoCount == 0
                      ? 'Keine im lokalen Index erfassten Tunnel im Kartenausschnitt. Datenabdeckung möglicherweise unvollständig.'
                      : '${controller.tunnelAutoCount} Tunnelachsen im Kartenausschnitt gefunden (schematisch).',
                'partial' =>
                  '${controller.tunnelAutoCount} Tunnelachsen gefunden; Abdeckung unvollständig.',
                'failed' => 'Tunnelindex konnte nicht geladen werden. Quelle und Build-Daten prüfen.',
                'offline' => 'Tunnelachsen derzeit offline nicht verfügbar.',
                'outside' => 'Tunnelachsen nur bei bodennaher Schweizer Kartenansicht automatisch laden.',
                _ => 'Tunnelachsen werden automatisch für den nahen sichtbaren Kartenausschnitt gesucht.',
              }),
              if (controller.tunnelAutoMessage != null)
                Text('Tunnel-Datenquelle: ${controller.tunnelAutoMessage}'),
            ],
            if (controller.schematicTunnel3dEnabled) ...[
              Text(
                'Automatisch dargestellte schematische Tunnel: '
                '${controller.schematicTunnelMeshCount} von maximal '
                '${controller.schematicTunnelMeshBudget} (Grafikprofil).',
              ),
              if (controller.schematicTunnelSkipped > 0)
                Text(
                  'Nicht modellierbare Tunnelabschnitte: '
                  '${controller.schematicTunnelSkipped} von '
                  '${controller.schematicTunnelConsidered} erfassten Achsen.',
                ),
              if (controller.schematicTunnelMeshCount > 0)
                Text(
                  'Terrain-Aussparungen: '
                  '${controller.schematicTunnelClipped}. Weitere sichtbare Röhren '
                  'sind ggf. vom Gelände verdeckt.',
                ),
              if (controller.schematicTunnelMeshError != null)
                Text('3D-Tunnel: ${controller.schematicTunnelMeshError}'),
            ],
            if (controller.tunnelRoutes.any(
              (route) => route['source'] == 'OpenStreetMap (Overpass fallback)',
            ))
              const Text(
                '© OpenStreetMap contributors (ODbL) · '
                'openstreetmap.org/copyright',
              ),
            const Text(
              'Tunnel stammen aus dem vorbereiteten Schweizer Offlineindex. '
              'Fehlt dieser, sendet die Online-Ersatzsuche den Kartenausschnitt '
              'an die Datenquelle. Querschnitt, Portale und Höhen sind nicht '
              'vermessen. Nur Simulation, keine reale Durchflugfreigabe.',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }
}
