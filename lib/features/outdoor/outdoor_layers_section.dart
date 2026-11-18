import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/models/outdoor_layer.dart';
import '../../core/osint/osint_provider_state.dart';
import '../globe/globe_controller.dart';
import '../help/guides_screen.dart';
import '../mobility/road_routing.dart';
import 'outdoor_context.dart';

Future<void> showOutdoorContext(
  BuildContext context, {
  required GlobeController globe,
  required List<MobilityPoint> path,
  List<OutdoorLayer>? layers,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => OutdoorContextScreen(
      globe: globe,
      path: path,
      layers:
          layers ??
          OutdoorLayer.values
              .where((l) => l.group == OutdoorLayerGroup.closures)
              .toList(),
    ),
  ),
);

class OutdoorLayersSection extends StatelessWidget {
  const OutdoorLayersSection({super.key, required this.globe});
  final GlobeController globe;
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                "Outdoor-Ebene konnte nicht geändert werden. Erneut versuchen.",
                (l10n) => l10n.outdoorOutdoorEbeneKonnteNichtdae0b0f9,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: globe,
    builder: (context, _) => Column(
      children: [
        for (final group in OutdoorLayerGroup.values)
          ExpansionTile(
            leading: Icon(switch (group) {
              OutdoorLayerGroup.nature => Icons.forest_outlined,
              OutdoorLayerGroup.networks => Icons.hiking,
              OutdoorLayerGroup.closures => Icons.warning_amber_outlined,
            }),
            title: Text(switch (group) {
              OutdoorLayerGroup.nature => context.localized(
                "Natur und Wildruhezonen",
                (l10n) => l10n.outdoorNaturUndWildruhezonen7304b9ec,
              ),
              OutdoorLayerGroup.networks => context.localized(
                "Amtliche Wegenetze",
                (l10n) => l10n.outdoorAmtlicheWegenetzeee6981c0,
              ),
              OutdoorLayerGroup.closures => context.localized(
                "Sperrungen und Umleitungen",
                (l10n) => l10n.outdoorSperrungenUndUmleitungenc019df11,
              ),
            }),
            children: [
              for (final layer in OutdoorLayer.values.where(
                (l) => l.group == group,
              ))
                Builder(
                  builder: (context) {
                    final config = globe.outdoorPreference(layer),
                        state = globe.situationalStatus(layer.rendererId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          title: Text(layer.label),
                          subtitle: Text(layer.publisher),
                          value: config.visible,
                          onChanged: globe.isReady && globe.canEditPreferences
                              ? (v) => _run(
                                  context,
                                  () =>
                                      globe.setOutdoorLayer(layer, visible: v),
                                )
                              : null,
                        ),
                        if (config.visible) ...[
                          Slider(
                            label: 'Deckkraft ${layer.label}',
                            value: config.opacity,
                            onChanged: (opacity) => _run(
                              context,
                              () => globe.setOutdoorLayer(
                                layer,
                                opacity: opacity,
                              ),
                            ),
                          ),
                          if (state == 'loading')
                            const LinearProgressIndicator(),
                          Text(
                            context.localizedWithArgs(
                              "Kartenebene: {0} · Quelldatum nicht vom Dienst mitgeteilt",
                              [state ?? 'angefordert'],
                              (l10n, value) => l10n
                                  .outdoorKartenebeneQuelldatumNichtVom78282b34(
                                    value(0),
                                  ),
                            ),
                          ),
                          if (state == 'failed')
                            TextButton(
                              onPressed: () => _run(
                                context,
                                () => globe.setOutdoorLayer(layer, retry: true),
                              ),
                              child: Text(
                                context.localized(
                                  "Kartenkacheln erneut laden",
                                  (l10n) => l10n
                                      .outdoorKartenkachelnErneutLadend22d2379,
                                ),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              layer.legend,
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              context.localized(
                                "Amtliche Legende und Quelle",
                                (l10n) => l10n
                                    .outdoorAmtlicheLegendeUndQuelle17cac2a2,
                              ),
                            ),
                          ),
                          if (globe.selectedPoint != null)
                            TextButton.icon(
                              onPressed: () => showOutdoorContext(
                                context,
                                globe: globe,
                                path: [
                                  MobilityPoint(
                                    globe.selectedPoint!.latitude,
                                    globe.selectedPoint!.longitude,
                                  ),
                                ],
                                layers: [layer],
                              ),
                              icon: const Icon(Icons.info_outline),
                              label: Text(
                                context.localized(
                                  "Details um den Kartenpunkt abrufen",
                                  (l10n) => l10n
                                      .outdoorDetailsUmDenKartenpunktdbe266e7,
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              context.localized(
                                "Online-Ebene · Offline-Kacheldownload nicht freigegeben. Abdeckung und Aktualität können lückenhaft sein.",
                                (l10n) => l10n
                                    .outdoorOnlineEbeneOfflineKacheldownload52ce6e5a,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              const GuideLink(GuideTopic.outdoor),
            ],
          ),
      ],
    ),
  );
}

class OutdoorContextScreen extends StatefulWidget {
  const OutdoorContextScreen({
    super.key,
    required this.globe,
    required this.path,
    required this.layers,
    this.provider,
  });
  final GlobeController globe;
  final List<MobilityPoint> path;
  final List<OutdoorLayer> layers;
  final OutdoorContextProvider? provider;
  @override
  State<OutdoorContextScreen> createState() => _OutdoorContextScreenState();
}

class _OutdoorContextScreenState extends State<OutdoorContextScreen> {
  late final provider =
      widget.provider ??
      OutdoorContextProvider(path: widget.path, layers: widget.layers);
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    provider.addListener(_changed);
    _refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await provider.fetch(forceRefresh: true);
    } catch (e) {
      if (mounted) error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    provider.removeListener(_changed);
    if (widget.provider == null) provider.dispose();
    super.dispose();
  }

  Future<void> _showFeatures() async {
    final records = provider.status.dataset?.data['records'] as List? ?? [];
    final features = <Map<String, dynamic>>[];
    for (final raw in records) {
      final r = Map<String, dynamic>.from(raw as Map), g = r['geometry'];
      if (g is! Map) continue;
      final geometries = g['type'] == 'MultiLineString'
          ? [
              for (final line in g['coordinates'] as List)
                {'type': 'LineString', 'coordinates': line},
            ]
          : [g];
      for (var i = 0; i < geometries.length; i++) {
        final detail =
            '${r['classification']} · ${r['validity']}\n${r['relation']}\n${r['attributes']['duration_de'] ?? r['attributes']['schutzzeit'] ?? 'Gültigkeit nicht bereitgestellt'}\nAbgerufen: ${provider.status.dataset!.fetchedAtUtc.toIso8601String()}\n${r['reference']}';
        features.add({
          'id': '${r['id']}:$i',
          'name': r['name'],
          'detail': detail.length > 1200
              ? '${detail.substring(0, 1160)}… Details im Outdoor-Menü'
              : detail,
          'geometry': geometries[i],
        });
      }
    }
    try {
      await widget.globe.showSituationalOverlay({
        'id': 'outdoor-context',
        'visible': true,
        'opacity': .3,
        'features': features,
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Details konnten nicht auf der Karte dargestellt werden.',
        );
      }
    }
  }

  Future<void> _reference(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = provider.status.dataset,
        records = data?.data['records'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Amtlicher Outdoor-Kontext",
            (l10n) => l10n.outdoorAmtlicherOutdoorKontextab221e59,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.localized(
                "Der gewählte Ausschnitt wird an geo.admin.ch gesendet. Räumlicher Auszug, keine vollständige Zugänglichkeitsprüfung.",
                (l10n) => l10n.commonDerGewaehlteAusschnittWird46b1cc5d,
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Text(provider.status.dataState.label),
            if (data != null)
              Text(
                context.localizedWithArgs(
                  "Abgerufen: {0} · amtliches Publikationsdatum nicht mitgeteilt",
                  [data.fetchedAtUtc.toLocal()],
                  (l10n, value) => l10n
                      .outdoorAbgerufenAmtlichesPublikationsdatumNicht1eb563a2(
                        value(0),
                      ),
                ),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    context.localized(
                      "Auszug aktualisieren",
                      (l10n) => l10n.outdoorAuszugAktualisieren55f223d5,
                    ),
                  ),
                ),
                if (records.isNotEmpty)
                  OutlinedButton(
                    onPressed: _showFeatures,
                    child: Text(
                      context.localized(
                        "Auszug auf Karte anzeigen",
                        (l10n) => l10n.outdoorAuszugAufKarteAnzeigen9105f450,
                      ),
                    ),
                  ),
              ],
            ),
            if (data != null) Text('${data.data['coverage']}'),
            if (data?.data['preciseRouteCheck'] == false)
              Text(
                context.localized(
                  "Route oder Auszug überschreiten das Größenlimit für den vollständigen Einzelabgleich. Bitte einen kürzeren Abschnitt wählen. Die Originalgeometrie bleibt erhalten.",
                  (l10n) => l10n.outdoorRouteOderAuszugUeberschreitene46a9d8f,
                ),
              ),
            if (data?.data['atLimit'] == true)
              Text(
                context.localized(
                  "Ergebnisgrenze erreicht · weitere Objekte können fehlen.",
                  (l10n) =>
                      l10n.outdoorErgebnisgrenzeErreichtWeitereObjektefa8b4a21,
                ),
              ),
            if (data != null && records.isEmpty)
              Text(
                context.localized(
                  "Keine Objekte im Auszug gefunden. Das bestätigt keine offene oder freie Route.",
                  (l10n) => l10n.outdoorKeineObjekteImAuszug3e189c68,
                ),
              ),
            for (final raw in records)
              Builder(
                builder: (context) {
                  final r = raw as Map,
                      a = Map<String, dynamic>.from(r['attributes'] as Map),
                      wildlife = r['layer'] == OutdoorLayer.wildlife.name;
                  final classification = wildlife
                      ? switch (r['classification']) {
                          'statutory' => 'Rechtsverbindlicher Schutz',
                          'recommended' => 'Empfehlung',
                          _ => 'Schutzstatus unbekannt',
                        }
                      : '${r['classification']}';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${r['name']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(classification),
                          Text(
                            outdoorValidity(
                              a,
                              DateTime.now().toUtc(),
                              wildlife: wildlife,
                            ),
                          ),
                          Text('${r['relation']}'),
                          for (final key in [
                            'schutzzeit',
                            'best_de',
                            'einschraenkungen',
                            'wegtyp_de',
                            'duration_de',
                            'route_nr',
                            'reason_de',
                            'abstract_de',
                            'state_validate_de',
                          ])
                            if (a[key] != null && '${a[key]}'.trim().isNotEmpty)
                              Text(
                                '${const {'schutzzeit': 'Schutzzeit', 'best_de': 'Bestimmung', 'einschraenkungen': 'Einschränkungen', 'wegtyp_de': 'Erlaubte Wege', 'duration_de': 'Gültigkeit', 'route_nr': 'Betroffene Route', 'reason_de': 'Grund', 'abstract_de': 'Beschreibung', 'state_validate_de': 'Publikationsstatus'}[key] ?? key}: ${a[key]}',
                              ),
                          TextButton.icon(
                            onPressed: () => _reference('${r['reference']}'),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              context.localized(
                                "Offizielle Details",
                                (l10n) => l10n.outdoorOffizielleDetails573452dd,
                              ),
                            ),
                          ),
                          ExpansionTile(
                            title: Text(
                              context.localized(
                                "Originalattribute",
                                (l10n) => l10n.outdoorOriginalattribute38290624,
                              ),
                            ),
                            children: [
                              SelectableText(
                                context.localizedWithArgs(
                                  "Quellen-ID: {0}\n{1}",
                                  [
                                    r['id'],
                                    a.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join('\n'),
                                  ],
                                  (l10n, value) =>
                                      l10n.outdoorQuellenIdba307a43(
                                        value(0),
                                        value(1),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Text(
              context.localized(
                "Diese Detailauszüge werden nur im Arbeitsspeicher gehalten. Kantonsübergreifende Vektorpakete und deren Weitergabe benötigen jeweils passende Nutzungsbedingungen.",
                (l10n) => l10n.outdoorDieseDetailauszuegeWerdenNur71ff8d83,
              ),
            ),
            const GuideLink(GuideTopic.outdoor),
          ],
        ),
      ),
    );
  }
}
