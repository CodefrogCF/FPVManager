import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
                        ? context.localized(
                            "Verkehrsmeldungen werden aktualisiert …",
                            (l10n) => l10n
                                .mobilityVerkehrsmeldungenWerdenAktualisiert10e1b261,
                          )
                        : dataset == null
                        ? context.localized(
                            "Keine Verkehrsdaten geladen",
                            (l10n) =>
                                l10n.mobilityKeineVerkehrsdatenGeladena56a2b8a,
                          )
                        : provider.status.error != null
                        ? context.localized(
                            "Aktualisierung fehlgeschlagen · letzter Datenstand bleibt sichtbar",
                            (l10n) => l10n
                                .mobilityAktualisierungFehlgeschlagenLetzterDatenstand97d6ca24,
                          )
                        : dataset.requiresRevalidation
                        ? context.localized(
                            "Importierte Daten · online nicht geprüft",
                            (l10n) => l10n
                                .mobilityImportierteDatenOnlineNicht8129ba14,
                          )
                        : provider.status.dataState == OsintDataState.fresh
                        ? context.localized(
                            "Letzter Abruf aktuell",
                            (l10n) => l10n.mobilityLetzterAbrufAktuellfe37dd68,
                          )
                        : context.localized(
                            "Abruf veraltet · erneut aktualisieren",
                            (l10n) => l10n
                                .mobilityAbrufVeraltetErneutAktualisieren5ed4d00d,
                          ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (dataset != null) ...[
                    Text(
                      context.localizedWithArgs(
                        "Letzter Abruf / Import: {0}",
                        [trafficTime(dataset.fetchedAtUtc)],
                        (l10n, value) =>
                            l10n.mobilityLetzterAbrufImportea742e4d(value(0)),
                      ),
                    ),
                    Text(
                      context.localizedWithArgs(
                        "Quellenpublikation: {0}",
                        [trafficTime(dataset.publishedAtUtc)],
                        (l10n, value) =>
                            l10n.mobilityQuellenpublikationd60ff8d0(value(0)),
                      ),
                    ),
                    Text(
                      context.localizedWithArgs(
                        "{0} Ereignisse · {1} ohne Kartenposition · {2} nicht auswertbar",
                        [
                          (data?['records'] as List?)?.length ?? records.length,
                          data?['unlocated'] ?? 0,
                          data?['omitted'] ?? 0,
                        ],
                        (l10n, value) => l10n
                            .mobilityEreignisseOhneKartenpositionNichta9154e17(
                              value(0),
                              value(1),
                              value(2),
                            ),
                      ),
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
              decoration: InputDecoration(
                labelText: context.localized(
                  "Straße, Ort oder Meldung suchen",
                  (l10n) => l10n.commonStrasseOrtOderMeldung26ebddfb,
                ),
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
                  label: Text(
                    context.localized(
                      "Nur mit Kartenposition",
                      (l10n) => l10n.mobilityNurMitKartenposition87e01213,
                    ),
                  ),
                  selected: _positionedOnly,
                  onSelected: (v) => _filter(() => _positionedOnly = v),
                ),
              ],
            ),
            DropdownButton<TrafficCategory?>(
              isExpanded: true,
              value: _category,
              items: [
                DropdownMenuItem<TrafficCategory?>(
                  value: null,
                  child: Text(
                    context.localized(
                      "Alle Ereignistypen",
                      (l10n) => l10n.mobilityAlleEreignistypenf0956deb,
                    ),
                  ),
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
                label: Text(
                  context.localized(
                    "Aktuelle Meldungen auf Karte zeigen",
                    (l10n) => l10n.mobilityAktuelleMeldungenAufKarte65e8ab99,
                  ),
                ),
              ),
            Text(
              context.localizedWithArgs(
                "{0} passende Ereignisse{1}",
                [
                  filtered.length,
                  widget.routeRecords != null ? " im Routenumfeld" : "",
                ],
                (l10n, value) =>
                    l10n.mobilityPassendeEreignisse872c00ef(value(0), value(1)),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.localized(
                    "Keine passenden Meldungen. Das bestätigt keine freie Fahrt oder vollständige Quellenabdeckung.",
                    (l10n) => l10n.mobilityKeinePassendenMeldungenDas1634f284,
                  ),
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
                child: Text(
                  context.localizedWithArgs(
                    "Weitere Meldungen ({0})",
                    [filtered.length - _limit],
                    (l10n, value) =>
                        l10n.mobilityWeitereMeldungenc11d95f1(value(0)),
                  ),
                ),
              ),
            ExpansionTile(
              title: Text(
                context.localized(
                  "Abdeckung und zusätzliche Verkehrsdaten",
                  (l10n) => l10n
                      .mobilityAbdeckungUndZusaetzlicheVerkehrsdatenca67bb5b,
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    context.localized(
                      "ASTRA / VMZ-CH veröffentlicht Ereignismeldungen. Ohne passende offizielle TMC-Ortstabelle können reine Ortscodes nicht auf der Karte verortet werden. Solche Meldungen bleiben hier durchsuchbar. Kartenpunkte können nur eine Anzeigereferenz sein; gerade Linien bilden keinen genauen Straßenverlauf ab.\n\nDurchgehende Verkehrsdichte und verkehrsabhängige Ankunftszeiten sind damit nicht verfügbar. ASTRA bietet zusätzlich Geschwindigkeiten und Fahrzeugmengen an Zählstellen über einen separaten API-Zugang an.",
                      (l10n) => l10n.mobilityAstraVmzChVeroeffentlicht4c4e6620,
                    ),
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
                    ? context.localized(
                        "Ohne Kartenposition · TMC-Ortstabelle erforderlich",
                        (l10n) => l10n
                            .mobilityOhneKartenpositionTmcOrtstabelle29d7c796,
                      )
                    : context.localized(
                        "Ohne nutzbare Quellenposition",
                        (l10n) =>
                            l10n.mobilityOhneNutzbareQuellenposition09a6b7b9,
                      ),
              ),
            if (r.data['geometryAccuracy'] == 'displayReference')
              Text(
                context.localized(
                  "Anzeigereferenz · genaue Ausdehnung unbekannt",
                  (l10n) => l10n
                      .mobilityAnzeigereferenzGenaueAusdehnungUnbekannt92e1ba4c,
                ),
              ),
            if ({
              'tmcAnchors',
              'tmcReference',
            }.contains(r.data['geometryAccuracy']))
              Text(
                context.localized(
                  "TMC-Tabellenbezug · kein genauer Straßenverlauf",
                  (l10n) => l10n.mobilityTmcTabellenbezugKeinGenauer361692b0,
                ),
              ),
            if (along != null)
              Text(
                context.localizedWithArgs("In {0} km · im 300-m-Routenumfeld", [
                  ((along - progressMeters).clamp(0, double.infinity) / 1000)
                      .toStringAsFixed(1),
                ], (l10n, value) => l10n.mobilityInKmImMf10f6e91(value(0))),
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
                      ? context.localized(
                          "Kein öffentlicher Beschreibungstext vorhanden.",
                          (l10n) => l10n
                              .mobilityKeinOeffentlicherBeschreibungstextVorhanden581108e5,
                        )
                      : r.description,
                ),
                const SizedBox(height: 8),
                Text(
                  context.localizedWithArgs(
                    "Meldung geändert: {0}",
                    [trafficTime(r.updated)],
                    (l10n, value) =>
                        l10n.mobilityMeldungGeaenderta349466c(value(0)),
                  ),
                ),
                Text(
                  context.localizedWithArgs(
                    "Gültig ab: {0} · bis: {1}",
                    [trafficTime(r.from), trafficTime(r.until)],
                    (l10n, value) =>
                        l10n.mobilityGueltigAbBisc0b768b9(value(0), value(1)),
                  ),
                ),
                if (r.data['recurring'] == true)
                  Text(
                    context.localized(
                      "Die Quelle nennt wiederkehrende Zeitfenster. Einzelne Zeitfenster vor Fahrtantritt prüfen.",
                      (l10n) =>
                          l10n.mobilityDieQuelleNenntWiederkehrende01133c3c,
                    ),
                  ),
                if (r.data['tmcStatus'] case final String status) Text(status),
                if (r.data['geometryAccuracy'] == 'approximateLine')
                  Text(
                    context.localized(
                      "Gerade Verbindung zwischen Quellenpositionen; kein genauer Straßenverlauf.",
                      (l10n) => l10n
                          .mobilityGeradeVerbindungZwischenQuellenpositionen0a65d12c,
                    ),
                  ),
                if (r.data['tmcCodes'] case final List codes
                    when codes.isNotEmpty)
                  Text(
                    context.localizedWithArgs(
                      "TMC-Version {0} · Orte {1} · Richtungscode {2}",
                      [
                        r.data['tmcVersion'],
                        codes.join(", "),
                        r.data['directionCode'] ?? "unbekannt",
                      ],
                      (l10n, value) =>
                          l10n.mobilityTmcVersionOrteRichtungscodecfd846ff(
                            value(0),
                            value(1),
                            value(2),
                          ),
                    ),
                  ),
                SelectableText(
                  context.localizedWithArgs(
                    "ASTRA / VMZ-CH · Ereignis {0} · {1} Teilmeldungen",
                    [r.data['id'], r.data['parts'] ?? 1],
                    (l10n, value) => l10n.mobilityAstraVmzChEreignis5068b250(
                      value(0),
                      value(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
