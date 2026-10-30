import 'package:flutter/material.dart';
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
          const SnackBar(
            content: Text(
              'Outdoor-Ebene konnte nicht geändert werden. Erneut versuchen.',
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
              OutdoorLayerGroup.nature => 'Natur und Wildruhezonen',
              OutdoorLayerGroup.networks => 'Amtliche Wegenetze',
              OutdoorLayerGroup.closures => 'Sperrungen und Umleitungen',
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
                            'Kartenebene: ${state ?? 'angefordert'} · Quelldatum nicht vom Dienst mitgeteilt',
                          ),
                          if (state == 'failed')
                            TextButton(
                              onPressed: () => _run(
                                context,
                                () => globe.setOutdoorLayer(layer, retry: true),
                              ),
                              child: const Text('Kartenkacheln erneut laden'),
                            ),
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              layer.legend,
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Amtliche Legende und Quelle'),
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
                              label: const Text(
                                'Details um den Kartenpunkt abrufen',
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Online-Ebene · Offline-Kacheldownload nicht freigegeben. Abdeckung und Aktualität können lückenhaft sein.',
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
      appBar: AppBar(title: const Text('Amtlicher Outdoor-Kontext')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Der gewählte Ausschnitt wird an geo.admin.ch gesendet. Räumlicher Auszug, keine vollständige Zugänglichkeitsprüfung.',
            ),
            if (busy) const LinearProgressIndicator(),
            Text(provider.status.dataState.label),
            if (data != null)
              Text(
                'Abgerufen: ${data.fetchedAtUtc.toLocal()} · amtliches Publikationsdatum nicht mitgeteilt',
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
                  label: const Text('Auszug aktualisieren'),
                ),
                if (records.isNotEmpty)
                  OutlinedButton(
                    onPressed: _showFeatures,
                    child: const Text('Auszug auf Karte anzeigen'),
                  ),
              ],
            ),
            if (data != null) Text('${data.data['coverage']}'),
            if (data?.data['preciseRouteCheck'] == false)
              const Text(
                'Route oder Auszug überschreiten das Größenlimit für den vollständigen Einzelabgleich. Bitte einen kürzeren Abschnitt wählen. Die Originalgeometrie bleibt erhalten.',
              ),
            if (data?.data['atLimit'] == true)
              const Text(
                'Ergebnisgrenze erreicht · weitere Objekte können fehlen.',
              ),
            if (data != null && records.isEmpty)
              const Text(
                'Keine Objekte im Auszug gefunden. Das bestätigt keine offene oder freie Route.',
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
                            label: const Text('Offizielle Details'),
                          ),
                          ExpansionTile(
                            title: const Text('Originalattribute'),
                            children: [
                              SelectableText(
                                'Quellen-ID: ${r['id']}\n${a.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const Text(
              'Diese Detailauszüge werden nur im Arbeitsspeicher gehalten. Kantonsübergreifende Vektorpakete und deren Weitergabe benötigen jeweils passende Nutzungsbedingungen.',
            ),
            const GuideLink(GuideTopic.outdoor),
          ],
        ),
      ),
    );
  }
}
