import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
          'Brücken, 3D-Bauwerke und Tunnelachsen',
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
          'Bauwerke aus swisstopo-3D-Tiles. Tunnelachsen werden getrennt aus dem vorbereiteten OSM-Offlineindex geladen und optional als schematische 3D-Röhren dargestellt.',
        ),
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('3D-Tunnel automatisch laden (schematisch)'),
          subtitle: const Text(
            'Lädt Tunnel- und Unterführungsachsen aus dem vorbereiteten '
            'Schweizer Offlineindex (© OpenStreetMap contributors, ODbL). '
            'Im normalen Betrieb keine Online-Tunnelabfrage. Wenn der '
            'Index im Build fehlt, wird ersatzweise die bisherige '
            'Online-Suche versucht; dabei geht der Kartenausschnitt an '
            'die jeweiligen Dienste. Das Grafikprofil begrenzt gleichzeitig '
            'gerenderte Röhren auf 16 bis 64 (normal 32, hohe Qualität 64). '
            'Die Modelle werden in kleinen Gruppen nachgeladen (ca. 6 × 5 m). Querschnitt, Portale und Höhen sind '
            'NICHT vermessen. Nur Simulation, keine reale Freigabe. '
            'Für die Geländeöffnung ist Terrain/3D-Clipping erforderlich.',
          ),
          value: controller.schematicTunnel3dEnabled,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setTunnelInfrastructure(autoModels: value),
                )
              : null,
        ),
        if (controller.tunnelRoutes.any(
          (route) => route['source'] == 'OpenStreetMap (Overpass fallback)',
        ))
          const Text(
            '© OpenStreetMap contributors (ODbL) · '
            'openstreetmap.org/copyright',
          ),
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('3D-Modellkollisionen (experimentell)'),
          subtitle: const Text(
            'Schematische Tunnel: geometriebasierte Kollision an Wänden, Decke und Boden. '
            'Geladene 3D-Modelle: gedrosselte Kollision nahe der sichtbaren '
            'Oberfläche (nicht der gesamte Raum bis zum Boden). Brücken-'
            'Unterseiten bleiben frei, soweit keine modellierten Bauteile '
            'berührt werden. KEINE exakte Wandkollision. Unbekannte '
            'oder nicht geladene Geometrie bleibt ungeprüft. Nur Simulation.',
          ),
          value: controller.sceneModelCollisionsEnabled,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setSceneEnvironment(modelCollisions: value),
                )
              : null,
        ),
        if (controller.selectedInfrastructure != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ausgewähltes Infrastrukturobjekt · Quellenangabe unten',
                  ),
                  Text(
                    'Quelle: ${controller.selectedInfrastructure!['datasetSource']}',
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
                  if (controller.selectedInfrastructure!['id'] is String &&
                      {
                        'tunnel',
                        'underpass',
                      }.contains(controller.selectedInfrastructure!['kind']))
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
        const Divider(),
        TextButton.icon(
          onPressed: enabled && !controller.tunnelModelPending
              ? () => change(() async {
                  final file = await openFile(
                    acceptedTypeGroups: [
                      const XTypeGroup(
                        label: 'Georeferenced tunnel mesh or cross sections',
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
          label: const Text(
            'Optional: eigenes 3D-Tunnelmesh importieren (JSON)',
          ),
        ),
        const Text(
          'Importierte Meshes: explizites EPSG:4979 / WGS84-Ellipsoid, '
          'separates Kollisionsmesh und Quelle erforderlich. Keine automatische '
          'Vermessungs- oder Lichtraumprüfung. GLB/IFC nicht direkt unterstützt.',
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tunnelverläufe und Unterführungen'),
          subtitle: const Text(
            'swissTLM3D oder OpenStreetMap-Fallback · schematischer Verlauf auf der Geländeoberfläche, keine Tunnelröhre.',
          ),
          value: controller.tunnelRoutesVisible,
          onChanged: enabled
              ? (value) => change(
                  () =>
                      controller.setTunnelInfrastructure(routesVisible: value),
                )
              : null,
        ),
        if (controller.tunnelRoutesVisible ||
            controller.schematicTunnel3dEnabled) ...[
          if (controller.tunnelRoutesVisible)
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
              'Noch keine Tunnelachsen aufgelistet. Bei aktivierten schematischen 3D-Tunneln erfolgt eine begrenzte automatische Suche; manuelle Suche bleibt verfügbar.',
            ),
          for (final route in controller.tunnelRoutes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(route['name'] as String),
              subtitle: Text(
                '${route['transport']} · ${route['kind']} · ${route['source']} · Portalhöhen unbekannt',
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
                  if (controller.tunnelExplorationEnabled)
                    const PopupMenuItem(
                      value: 'explore',
                      child: Text('Schematische Oberflächen-Erkundung'),
                    ),
                  const PopupMenuItem(
                    value: 'model',
                    child: Text('3D-Gewölbetunnel erzeugen (synthetisch)'),
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
        if (controller.tunnelModelPending) const LinearProgressIndicator(),
        if (controller.tunnelModelError != null)
          Text('3D-Tunnel: ${controller.tunnelModelError}'),
        if (controller.tunnelModelReady) ...[
          if (controller.tunnelModelSource != null)
            Text('Modellquelle: ${controller.tunnelModelSource}'),
          Text(
            controller.tunnelModelQuality == 'simulation-only'
                ? 'SIMULATION ONLY: 3D-Gewölbe (6 × 5 m), Portale und Lichtraum sind künstlich erzeugt. Kollisionen sind geometriebasiert nur für dieses Modell; keine realen Freiräume oder Zugangsberechtigungen.'
                : controller.tunnelModelQuality == 'external-mesh-unverified'
                ? 'GEOREFERENZIERTES MESH: Sicht- und Kollisionsdreiecke importiert; Herkunft, Datumstransformation und Lichtraum sind nicht unabhängig geprüft. Unterirdische Flächen können ohne explizite Terrain-Ausschnitte verborgen bleiben.'
                : 'IMPORTIERTE MODELLGEOMETRIE: Provenienz und Lichtraumprofil sind nicht unabhängig verifiziert. Keine reale Durchflugfreigabe.',
          ),
          if (controller.tunnelMeshTriangles != null)
            Text(
              'Sichtdreiecke: ${controller.tunnelMeshTriangles} · '
              'Kollisionsdreiecke: ${controller.tunnelCollisionTriangles ?? 0}',
            ),
          if (!controller.tunnelModelCanFly)
            const Text(
              'Durchflug deaktiviert: Es fehlen geprüfte Angaben zu '
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
