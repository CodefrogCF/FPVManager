import 'package:flutter/material.dart';

import '../../core/osint/osint_provider_state.dart';
import 'situational_provider.dart';
import 'traffic_incident.dart';

String trafficTime(DateTime? value) {
  if (value == null) return 'unbekannt';
  final d = value.toLocal();
  String n(int v) => v.toString().padLeft(2, '0');
  return '${n(d.day)}.${n(d.month)}.${d.year} ${n(d.hour)}:${n(d.minute)}';
}

IconData trafficIcon(TrafficCategory category) => switch (category) {
  TrafficCategory.closure => Icons.block,
  TrafficCategory.accident => Icons.car_crash,
  TrafficCategory.congestion => Icons.traffic,
  TrafficCategory.roadworks => Icons.construction,
  TrafficCategory.weather => Icons.cloud,
  _ => Icons.warning_amber,
};

Color trafficColor(TrafficCategory category) => Color(switch (category) {
  TrafficCategory.closure || TrafficCategory.accident => 0xffe75c54,
  TrafficCategory.congestion => 0xffef9847,
  TrafficCategory.roadworks => 0xffd6b74f,
  TrafficCategory.weather => 0xff55a9db,
  TrafficCategory.hazard => 0xffbb82cf,
  TrafficCategory.other => 0xffaab4b7,
});

class TrafficBulletin extends StatefulWidget {
  const TrafficBulletin({
    super.key,
    required this.provider,
    this.routeRecords,
    this.progressMeters = 0,
    this.onShowMap,
  });
  final SituationalProvider provider;
  final List<Map<String, dynamic>>? routeRecords;
  final double progressMeters;
  final VoidCallback? onShowMap;
  @override
  State<TrafficBulletin> createState() => _TrafficBulletinState();
}

class _TrafficBulletinState extends State<TrafficBulletin> {
  String _query = '', _period = 'Aktuell';
  TrafficCategory? _category;
  bool _positionedOnly = false;
  int _limit = 30;
  void _filter(VoidCallback change) => setState(() {
    change();
    _limit = 30;
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final provider = widget.provider,
          dataset = provider.status.dataset,
          data = dataset?.data;
      final now = provider.nowUtc;
      final records =
          widget.routeRecords ??
          ((data?['records'] as List?) ??
                  [
                    ...data?['features'] as List? ?? [],
                    ...data?['unlocatedRecords'] as List? ?? [],
                  ])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
      final filtered = records
          .map(TrafficIncident.new)
          .where(
            (r) =>
                (_period == 'Alle' ||
                    (_period == 'Geplant'
                        ? r.state(now) == 'Geplant'
                        : r.relevantNow(now))) &&
                (_category == null || r.category == _category) &&
                (!_positionedOnly || r.located) &&
                (_query.isEmpty || r.searchable.contains(_query.toLowerCase())),
          )
          .toList();
      if (widget.routeRecords == null) {
        filtered.sort((a, b) {
          final rank = a.category.index.compareTo(b.category.index);
          return rank != 0
              ? rank
              : (b.updated ?? DateTime(1970)).compareTo(
                  a.updated ?? DateTime(1970),
                );
        });
      }
      final scheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.status.update == OsintUpdateState.loading
                        ? 'Verkehrsmeldungen werden aktualisiert …'
                        : dataset == null
                        ? 'Keine Verkehrsdaten geladen'
                        : provider.status.error != null
                        ? 'Aktualisierung fehlgeschlagen · letzter Datenstand bleibt sichtbar'
                        : dataset.requiresRevalidation
                        ? 'Importierte Daten · online nicht geprüft'
                        : provider.status.dataState == OsintDataState.fresh
                        ? 'Letzter Abruf aktuell'
                        : 'Abruf veraltet · erneut aktualisieren',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (dataset != null) ...[
                    Text(
                      'Letzter Abruf / Import: ${trafficTime(dataset.fetchedAtUtc)}',
                    ),
                    Text(
                      'Quellenpublikation: ${trafficTime(dataset.publishedAtUtc)}',
                    ),
                    Text(
                      '${(data?['records'] as List?)?.length ?? records.length} Ereignisse · ${data?['unlocated'] ?? 0} ohne Kartenposition · ${data?['omitted'] ?? 0} nicht auswertbar',
                    ),
                  ],
                  if (provider.status.error != null)
                    Text(
                      provider.status.error!.message,
                      style: TextStyle(color: scheme.error),
                    ),
                ],
              ),
            ),
          ),
          if (dataset != null) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Straße, Ort oder Meldung suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => _filter(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final period in ['Aktuell', 'Geplant', 'Alle'])
                  ChoiceChip(
                    label: Text(period),
                    selected: _period == period,
                    onSelected: (_) => _filter(() => _period = period),
                  ),
                FilterChip(
                  label: const Text('Nur mit Kartenposition'),
                  selected: _positionedOnly,
                  onSelected: (v) => _filter(() => _positionedOnly = v),
                ),
              ],
            ),
            DropdownButton<TrafficCategory?>(
              isExpanded: true,
              value: _category,
              items: [
                const DropdownMenuItem<TrafficCategory?>(
                  value: null,
                  child: Text('Alle Ereignistypen'),
                ),
                for (final c in TrafficCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => _filter(() => _category = v),
            ),
            if (widget.onShowMap != null)
              FilledButton.tonalIcon(
                onPressed: widget.onShowMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Aktuelle Meldungen auf Karte zeigen'),
              ),
            Text(
              '${filtered.length} passende Ereignisse${widget.routeRecords != null ? " im Routenumfeld" : ""}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Keine passenden Meldungen. Das bestätigt keine freie Fahrt oder vollständige Quellenabdeckung.',
                ),
              ),
            for (final incident in filtered.take(_limit))
              TrafficIncidentCard(
                incident: incident,
                now: now,
                progressMeters: widget.progressMeters,
              ),
            if (filtered.length > _limit)
              OutlinedButton(
                onPressed: () => setState(() => _limit += 30),
                child: Text('Weitere Meldungen (${filtered.length - _limit})'),
              ),
            ExpansionTile(
              title: const Text('Abdeckung und zusätzliche Verkehrsdaten'),
              children: const [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'ASTRA / VMZ-CH veröffentlicht Ereignismeldungen. Ohne passende offizielle TMC-Ortstabelle können reine Ortscodes nicht auf der Karte verortet werden. Solche Meldungen bleiben hier durchsuchbar. Kartenpunkte können nur eine Anzeigereferenz sein; gerade Linien bilden keinen genauen Straßenverlauf ab.\n\nDurchgehende Verkehrsdichte und verkehrsabhängige Ankunftszeiten sind damit nicht verfügbar. ASTRA bietet zusätzlich Geschwindigkeiten und Fahrzeugmengen an Zählstellen über einen separaten API-Zugang an.',
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class TrafficIncidentCard extends StatelessWidget {
  const TrafficIncidentCard({
    super.key,
    required this.incident,
    required this.now,
    this.progressMeters = 0,
  });
  final TrafficIncident incident;
  final DateTime now;
  final double progressMeters;
  @override
  Widget build(BuildContext context) {
    final r = incident;
    final labels = trafficMetricLabels(r.metrics);
    final along = (r.data['alongMeters'] as num?)?.toDouble();
    return Card(
      child: ExpansionTile(
        key: ValueKey(r.data['id']),
        leading: Icon(trafficIcon(r.category), color: trafficColor(r.category)),
        title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.category.label} · ${r.state(now)}'),
            if (!r.located)
              Text(
                (r.data['tmcCodes'] as List?)?.isNotEmpty == true
                    ? 'Ohne Kartenposition · TMC-Ortstabelle erforderlich'
                    : 'Ohne nutzbare Quellenposition',
              ),
            if (r.data['geometryAccuracy'] == 'displayReference')
              const Text('Anzeigereferenz · genaue Ausdehnung unbekannt'),
            if (along != null)
              Text(
                'In ${((along - progressMeters).clamp(0, double.infinity) / 1000).toStringAsFixed(1)} km · im 300-m-Routenumfeld',
              ),
            ...labels.map(Text.new),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  r.description.isEmpty
                      ? 'Kein öffentlicher Beschreibungstext vorhanden.'
                      : r.description,
                ),
                const SizedBox(height: 8),
                Text('Meldung geändert: ${trafficTime(r.updated)}'),
                Text(
                  'Gültig ab: ${trafficTime(r.from)} · bis: ${trafficTime(r.until)}',
                ),
                if (r.data['recurring'] == true)
                  const Text(
                    'Die Quelle nennt wiederkehrende Zeitfenster. Einzelne Zeitfenster vor Fahrtantritt prüfen.',
                  ),
                if (r.data['geometryAccuracy'] == 'approximateLine')
                  const Text(
                    'Gerade Verbindung zwischen Quellenpositionen; kein genauer Straßenverlauf.',
                  ),
                if (r.data['tmcCodes'] case final List codes
                    when codes.isNotEmpty)
                  Text(
                    'TMC-Version ${r.data['tmcVersion']} · Orte ${codes.join(", ")} · Richtungscode ${r.data['directionCode'] ?? "unbekannt"}',
                  ),
                SelectableText(
                  'ASTRA / VMZ-CH · Ereignis ${r.data['id']} · ${r.data['parts'] ?? 1} Teilmeldungen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
