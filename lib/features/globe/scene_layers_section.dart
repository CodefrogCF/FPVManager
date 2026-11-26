import 'dart:convert';

import '../../core/localization/app_localizations.dart';

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
            SnackBar(
              content: Text(
                context.localizedWithArgs(
                  "3D-Aktion fehlgeschlagen: {0}",
                  [message],
                  (l10n, value) =>
                      l10n.globeDAktionFehlgeschlagen11f40ae7(value(0)),
                ),
              ),
            ),
          );
        }
      }
    }

    final enabled = controller.isReady && controller.canEditPreferences;
    final german = Localizations.localeOf(context).languageCode == 'de';
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
            title: Text(context.translate(label)),
            value: visible,
            onChanged: enabled ? (value) => change(() => toggle(value)) : null,
          ),
          if (visible && state == 'loading') const LinearProgressIndicator(),
          if (visible && ['failed', 'partial', 'offline'].contains(state)) ...[
            Text(
              state == 'partial'
                  ? context.localized(
                      "Einige 3D-Kacheln fehlen. Geladene Modelle bleiben sichtbar.",
                      (l10n) => l10n.globeEinigeDKachelnFehlenbf4b88d2,
                    )
                  : state == 'offline'
                  ? context.localized(
                      "3D-Daten offline nicht vollständig verfügbar.",
                      (l10n) => l10n.globeDDatenOfflineNicht0512f9fe,
                    )
                  : context.localized(
                      "3D-Daten derzeit nicht verfügbar.",
                      (l10n) => l10n.globeDDatenDerzeitNichtec1d811a,
                    ),
            ),
            TextButton.icon(
              onPressed: enabled
                  ? () =>
                        change(() => controller.setSceneEnvironment(retry: key))
                  : null,
              icon: const Icon(Icons.refresh),
              label: Text(
                context.localized(
                  "Erneut laden",
                  (l10n) => l10n.globeErneutLaden9c56689e,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ExpansionTile(
      key: const PageStorageKey('map-3d-environment'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        context.localized("3D & Licht", (l10n) => l10n.globeDLicht8b58e045),
      ),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            german
                ? 'Deutschland: BKG DGM5 + LoD2 (3D-Testdienst)'
                : 'Germany: BKG DGM5 + LoD2 (3D test service)',
          ),
          subtitle: Text(
            german
                ? 'Nur Online-Testbetrieb. Standardmäßig aus; keine Offline-Kacheln '
                      'oder dauerhafte Datenspeicherung. © GeoBasis-DE/BKG 2026. '
                      'Funkanalyse nur im lokal vorbereiteten Testgebiet möglich.'
                : 'Online testing only. Off by default; no offline tiles or '
                      'persistent storage. © GeoBasis-DE/BKG 2026. RF is available '
                      'only in the locally prepared test area.',
          ),
          value: controller.bkg3dTestEnabled,
          onChanged: enabled
              ? (value) => change(() => controller.setBkg3dTestEnabled(value))
              : null,
        ),
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
              Expanded(
                child: Text(
                  context.localized(
                    "Deckkraft",
                    (l10n) => l10n.globeDeckkraft3c11c68b,
                  ),
                ),
              ),
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
          title: Text(
            context.localized(
              "3D-Tunnel automatisch laden",
              (l10n) => l10n.globeDTunnelAutomatischLadena71b41bc,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Simulation · Online-Ersatzsuche sendet Kartenausschnitt.",
              (l10n) => l10n.globeSimulationOnlineErsatzsucheSendet67c4c630,
            ),
          ),
          value: controller.schematicTunnel3dEnabled,
          onChanged: enabled
              ? (value) => change(
                  () => controller.setTunnelInfrastructure(autoModels: value),
                )
              : null,
        ),
        if (controller.developerMenusEnabled &&
            controller.schematicTunnel3dEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.localizedWithArgs(
                "{0} / {1} Tunnel geladen",
                [
                  controller.schematicTunnelMeshCount,
                  controller.schematicTunnelMeshBudget,
                ],
                (l10n, value) =>
                    l10n.globeTunnelGeladen76365023(value(0), value(1)),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (controller.schematicTunnelMeshError != null)
          Text(
            controller.developerMenusEnabled
                ? 'Tunnel: ${controller.schematicTunnelMeshError}'
                : context.localized(
                    '3D-Daten derzeit nicht verfügbar.',
                    (l10n) => l10n.globeDDatenDerzeitNichtec1d811a,
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Sonnen- und Mondlicht",
              (l10n) => l10n.globeSonnenUndMondlichtc6291e64,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Tag und Nacht nach Gerätezeit.",
              (l10n) => l10n.globeTagUndNachtNach5c260567,
            ),
          ),
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
          title: Text(
            context.localized(
              "Tunnelwerkzeuge",
              (l10n) => l10n.globeTunnelwerkzeuge9873b3ba,
            ),
          ),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.localized(
                  "3D-Modellkollisionen (experimentell)",
                  (l10n) => l10n.globeDModellkollisionenExperimentell6ac94586,
                ),
              ),
              subtitle: Text(
                context.localized(
                  "Experimentell · geladene Modelloberflächen, keine exakte Wandprüfung.",
                  (l10n) => l10n
                      .commonExperimentellGeladeneModelloberflaechenKeine5d6ce860,
                ),
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
              label: Text(
                context.localized(
                  "Tunnel in der Nähe suchen",
                  (l10n) => l10n.globeTunnelInDerNaehe75bf7c66,
                ),
              ),
            ),
            if (controller.tunnelScanPending) const LinearProgressIndicator(),
            if (controller.tunnelScanError != null)
              Text(
                context.localizedWithArgs(
                  "Abfrage fehlgeschlagen: {0}",
                  [
                    controller.developerMenusEnabled
                        ? controller.tunnelScanError
                        : 'Tunnel',
                  ],
                  (l10n, value) =>
                      l10n.globeAbfrageFehlgeschlagene25d055d(value(0)),
                ),
              ),
            if (controller.tunnelScanIncomplete)
              Text(
                context.localized(
                  "Tunnelabdeckung unvollständig.",
                  (l10n) => l10n.globeTunnelabdeckungUnvollstaendigcfa66c0f,
                ),
              ),
            if (controller.tunnelRoutes.isEmpty &&
                !controller.tunnelScanPending &&
                controller.tunnelScanError == null)
              Text(
                context.localized(
                  "Noch keine Tunnel gefunden.",
                  (l10n) => l10n.globeNochKeineTunnelGefundenbdf89230,
                ),
              ),
            for (final route in controller.tunnelRoutes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(route['name'] as String),
                subtitle: Text('${route['transport']} · ${route['source']}'),
                isThreeLine: false,
                trailing: PopupMenuButton<String>(
                  tooltip: context.localized(
                    "Tunnelaktionen",
                    (l10n) => l10n.globeTunnelaktionenc0d41bdb,
                  ),
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
                    PopupMenuItem(
                      value: 'start',
                      child: Text(
                        context.localized(
                          "Zum ersten Achsenpunkt",
                          (l10n) => l10n.globeZumErstenAchsenpunkt95f01d68,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'end',
                      child: Text(
                        context.localized(
                          "Zum letzten Achsenpunkt",
                          (l10n) => l10n.globeZumLetztenAchsenpunkt5cbcd957,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'model',
                      child: Text(
                        context.localized(
                          "3D-Gewölbetunnel erzeugen (synthetisch)",
                          (l10n) => l10n
                              .globeDGewoelbetunnelErzeugenSynthetischcf487df5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (controller.tunnelModelPending) const LinearProgressIndicator(),
            if (controller.tunnelModelError != null)
              Text(
                context.localizedWithArgs("3D-Tunnel: {0}", [
                  controller.tunnelModelError,
                ], (l10n, value) => l10n.globeDTunnele1017c1e(value(0))),
              ),
            if (controller.tunnelModelReady) ...[
              if (controller.tunnelModelSource != null)
                Text(
                  context.localizedWithArgs("Modellquelle: {0}", [
                    controller.tunnelModelSource,
                  ], (l10n, value) => l10n.globeModellquelle05ae7da1(value(0))),
                ),
              Text(
                controller.tunnelModelQuality == 'simulation-only'
                    ? context.localized(
                        "Synthetisches Modell · Portale und Abmessungen geschätzt. Nur Simulation, keine reale Durchflugfreigabe.",
                        (l10n) =>
                            l10n.commonSynthetischesModellPortaleUnd61794358,
                      )
                    : controller.tunnelModelQuality ==
                          'external-mesh-unverified'
                    ? context.localized(
                        "Importiertes Mesh · Herkunft und Höhenbezug nicht unabhängig geprüft. Geländeöffnung erforderlich.",
                        (l10n) => l10n.globeImportiertesMeshHerkunftUnd538c26a9,
                      )
                    : context.localized(
                        "Importiertes Modell · Herkunft und Lichtraum ungeprüft. Keine reale Durchflugfreigabe.",
                        (l10n) =>
                            l10n.globeImportiertesModellHerkunftUnd950bcbe2,
                      ),
              ),
              if (controller.tunnelMeshTriangles != null)
                Text(
                  context.localizedWithArgs(
                    "Sichtdreiecke: {0} · Kollisionsdreiecke: {1}",
                    [
                      controller.tunnelMeshTriangles,
                      controller.tunnelCollisionTriangles ?? 0,
                    ],
                    (l10n, value) =>
                        l10n.globeSichtdreieckeKollisionsdreiecke2eeb74c5(
                          value(0),
                          value(1),
                        ),
                  ),
                ),
              if (!controller.tunnelModelCanFly)
                Text(
                  context.localized(
                    "Durchflug nicht verfügbar: Angaben zu Einstieg, Höhenprofil oder Terrain-Ausschnitten.",
                    (l10n) =>
                        l10n.commonDurchflugNichtVerfuegbarAngaben4931f578,
                  ),
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
                      child: Text(
                        context.localizedWithArgs(
                          "Durchflug: {0}",
                          [mode.toUpperCase()],
                          (l10n, value) =>
                              l10n.globeDurchfluge383d59a(value(0)),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: enabled
                        ? () => change(controller.removeTunnelModel)
                        : null,
                    icon: const Icon(Icons.close),
                    label: Text(
                      context.localized(
                        "3D-Tunnel entfernen",
                        (l10n) => l10n.globeDTunnelEntfernenc327e7fe,
                      ),
                    ),
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
                      Text(
                        context.localized(
                          "Ausgewähltes Bauwerk",
                          (l10n) => l10n.globeAusgewaehltesBauwerke74d05ef,
                        ),
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Quelle: {0}",
                          [controller.selectedInfrastructure!['datasetSource']],
                          (l10n, value) => l10n.commonQuelle25cfc7b8(value(0)),
                        ),
                      ),
                      if (controller.selectedInfrastructure!['name'] is String)
                        Text(
                          'Name: ${controller.selectedInfrastructure!['name']}',
                        ),
                      if (controller.developerMenusEnabled &&
                          controller.selectedInfrastructure!['sourceId'] !=
                              null)
                        Text(
                          context.localizedWithArgs(
                            "Quellkennung: {0}",
                            [controller.selectedInfrastructure!['sourceId']],
                            (l10n, value) =>
                                l10n.globeQuellkennung050247aa(value(0)),
                          ),
                        ),
                      if (controller.developerMenusEnabled &&
                          controller.selectedInfrastructure!['attributes']
                              is Map)
                        for (final entry
                            in (controller.selectedInfrastructure!['attributes']
                                    as Map)
                                .entries)
                          Text('${entry.key}: ${entry.value}'),
                      Text(
                        context.localized(
                          "Originaldaten · keine Durchflugfreigabe.",
                          (l10n) => l10n
                              .globeOriginaldatenKeineDurchflugfreigabeb2bc03bb,
                        ),
                      ),
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
                          label: Text(
                            context.localized(
                              "Aus Achse 3D-Gewölbe simulieren",
                              (l10n) => l10n.globeAusAchseDGewoelbe0d1ef125,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (controller.developerMenusEnabled)
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
                label: Text(
                  context.localized(
                    "Tunnelmodell importieren (JSON)",
                    (l10n) => l10n.globeTunnelmodellImportierenJson8ffcf7c7,
                  ),
                ),
              ),
            if (controller.developerMenusEnabled)
              Text(
                context.localized(
                  "JSON mit EPSG:4979, Quelle und separatem Kollisionsmesh. GLB/IFC werden nicht direkt unterstützt.",
                  (l10n) => l10n.commonJsonMitEpsgQuellef95a2fe5,
                ),
              ),
          ],
        ),
        if (!controller.developerMenusEnabled &&
            controller.tunnelRoutes.any(
              (route) => route['source'] == 'OpenStreetMap (Overpass fallback)',
            ))
          const Text(
            '© OpenStreetMap contributors (ODbL) · openstreetmap.org/copyright',
          ),
        if (controller.developerMenusEnabled)
          ExpansionTile(
            key: const PageStorageKey('map-tunnel-data'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              context.localized(
                "Tunnelstatus & Daten",
                (l10n) => l10n.globeTunnelstatusDatend6e42b7d,
              ),
            ),
            children: [
              if (controller.structures3dVisible) ...[
                if (controller.tunnelAutoState == 'loading')
                  const LinearProgressIndicator(),
                Text(switch (controller.tunnelAutoState) {
                  'ready' =>
                    controller.tunnelAutoCount == 0
                        ? context.localized(
                            "Keine im lokalen Index erfassten Tunnel im Kartenausschnitt. Datenabdeckung möglicherweise unvollständig.",
                            (l10n) => l10n.globeKeineImLokalenIndex7a2d66ae,
                          )
                        : context.localizedWithArgs(
                            "{0} Tunnelachsen im Kartenausschnitt gefunden (schematisch).",
                            [controller.tunnelAutoCount],
                            (l10n, value) => l10n
                                .globeTunnelachsenImKartenausschnittGefundenbbd7f549(
                                  value(0),
                                ),
                          ),
                  'partial' => context.localizedWithArgs(
                    "{0} Tunnelachsen gefunden; Abdeckung unvollständig.",
                    [controller.tunnelAutoCount],
                    (l10n, value) => l10n
                        .globeTunnelachsenGefundenAbdeckungUnvollstaendigdabfec20(
                          value(0),
                        ),
                  ),
                  'failed' => context.localized(
                    "Tunnelindex konnte nicht geladen werden. Quelle und Build-Daten prüfen.",
                    (l10n) => l10n.globeTunnelindexKonnteNichtGeladen03a91e8e,
                  ),
                  'offline' => context.localized(
                    "Tunnelachsen derzeit offline nicht verfügbar.",
                    (l10n) => l10n.globeTunnelachsenDerzeitOfflineNicht2a3ab99c,
                  ),
                  'outside' => context.localized(
                    "Tunnelachsen nur bei bodennaher Schweizer Kartenansicht automatisch laden.",
                    (l10n) => l10n.globeTunnelachsenNurBeiBodennaherab983e29,
                  ),
                  _ => context.localized(
                    "Tunnelachsen werden automatisch für den nahen sichtbaren Kartenausschnitt gesucht.",
                    (l10n) =>
                        l10n.globeTunnelachsenWerdenAutomatischFuer8bbff5f7,
                  ),
                }),
                if (controller.tunnelAutoMessage != null)
                  Text(
                    context.localizedWithArgs(
                      "Tunnel-Datenquelle: {0}",
                      [controller.tunnelAutoMessage],
                      (l10n, value) =>
                          l10n.globeTunnelDatenquellee8c8f0f5(value(0)),
                    ),
                  ),
              ],
              if (controller.schematicTunnel3dEnabled) ...[
                Text(
                  context.localizedWithArgs(
                    "Automatisch dargestellte schematische Tunnel: {0} von maximal {1} (Grafikprofil).",
                    [
                      controller.schematicTunnelMeshCount,
                      controller.schematicTunnelMeshBudget,
                    ],
                    (l10n, value) => l10n
                        .globeAutomatischDargestellteSchematischeTunnel4dea34ff(
                          value(0),
                          value(1),
                        ),
                  ),
                ),
                if (controller.schematicTunnelSkipped > 0)
                  Text(
                    context.localizedWithArgs(
                      "Nicht modellierbare Tunnelabschnitte: {0} von {1} erfassten Achsen.",
                      [
                        controller.schematicTunnelSkipped,
                        controller.schematicTunnelConsidered,
                      ],
                      (l10n, value) => l10n
                          .globeNichtModellierbareTunnelabschnitteVon25d903e4(
                            value(0),
                            value(1),
                          ),
                    ),
                  ),
                if (controller.schematicTunnelMeshCount > 0)
                  Text(
                    context.localizedWithArgs(
                      "Terrain-Aussparungen: {0}. Weitere sichtbare Röhren sind ggf. vom Gelände verdeckt.",
                      [controller.schematicTunnelClipped],
                      (l10n, value) =>
                          l10n.globeTerrainAussparungenWeitereSichtbaree67506d9(
                            value(0),
                          ),
                    ),
                  ),
                if (controller.schematicTunnelMeshError != null)
                  Text(
                    context.localizedWithArgs("3D-Tunnel: {0}", [
                      controller.schematicTunnelMeshError,
                    ], (l10n, value) => l10n.globeDTunnele1017c1e(value(0))),
                  ),
              ],
              if (controller.tunnelRoutes.any(
                (route) =>
                    route['source'] == 'OpenStreetMap (Overpass fallback)',
              ))
                const Text(
                  '© OpenStreetMap contributors (ODbL) · '
                  'openstreetmap.org/copyright',
                ),
              Text(
                context.localized(
                  "Tunnel stammen aus dem vorbereiteten Schweizer Offlineindex. Fehlt dieser, sendet die Online-Ersatzsuche den Kartenausschnitt an die Datenquelle. Querschnitt, Portale und Höhen sind nicht vermessen. Nur Simulation, keine reale Durchflugfreigabe.",
                  (l10n) => l10n.commonTunnelStammenAusDema4a6630f,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
      ],
    );
  }
}
