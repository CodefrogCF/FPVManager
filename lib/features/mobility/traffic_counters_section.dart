import 'package:flutter/foundation.dart';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/osint/api_credential_vault.dart';
import '../../core/osint/osint_provider_state.dart';
import 'traffic_bulletin.dart' show trafficTime;
import 'traffic_counters_provider.dart';

class TrafficCountersSection extends StatefulWidget {
  const TrafficCountersSection({
    super.key,
    required this.provider,
    required this.onShowMap,
  });
  final TrafficCountersProvider provider;
  final Future<void> Function(Map<String, dynamic>) onShowMap;
  @override
  State<TrafficCountersSection> createState() => _TrafficCountersSectionState();
}

class _TrafficCountersSectionState extends State<TrafficCountersSection> {
  final _key = TextEditingController();
  final _vault = LocalApiCredentialVault.shared;
  TrafficCountersProvider get _provider => widget.provider;
  bool _terms = false, _saving = false;
  String? _message;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save(bool remove) async {
    setState(() => _saving = true);
    try {
      if (remove) {
        await _vault.remove(astraCountersAccess);
      } else {
        await _vault.save(astraCountersAccess, _key.text.trim());
      }
      _key.clear();
      if (mounted) {
        setState(
          () => _message = remove
              ? 'Zählstellen-Token entfernt.'
              : 'Zählstellen-Token gespeichert.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Token konnte nicht gespeichert werden.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    maintainState: true,
    title: Text(
      context.localized(
        "Live-Messwerte · Traffic Counters",
        (l10n) => l10n.mobilityLiveMesswerteTrafficCountersaee8a401,
      ),
    ),
    subtitle: Text(
      context.localized(
        "Geschwindigkeiten und Fahrzeugmengen an Messstellen",
        (l10n) => l10n.mobilityGeschwindigkeitenUndFahrzeugmengenAn522f5906,
      ),
    ),
    children: [
      Text(
        context.localized(
          "Eigener Zugang für Traffic Counters. Der Schlüssel für Verkehrsmeldungen wird dafür nicht wiederverwendet. Daten bleiben in dieser Sitzung.",
          (l10n) => l10n.mobilityEigenerZugangFuerTraffic1a7bd79b,
        ),
      ),
      if (kIsWeb)
        Text(
          context.localized(
            "Direkter Abruf auf Android verfügbar.",
            (l10n) => l10n.mobilityDirekterAbrufAufAndroid7c4ac605,
          ),
        ),
      if (!kIsWeb) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _terms,
          onChanged: (v) => setState(() => _terms = v ?? false),
          title: Text(
            context.localized(
              "Zählstellenzugang freigeschaltet und ASTRA-Bedingungen akzeptiert",
              (l10n) =>
                  l10n.mobilityZaehlstellenzugangFreigeschaltetUndAstraa64cddb1,
            ),
          ),
        ),
        TextField(
          controller: _key,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.localized(
              "Eigener Traffic-Counters-Token",
              (l10n) => l10n.mobilityEigenerTrafficCountersTokenff5ddb8b,
            ),
            helperText: context.localized(
              "Token verwenden, nicht Token Hash.",
              (l10n) => l10n.commonTokenVerwendenNichtToken28179d00,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving || !_terms ? null : () => _save(false),
              child: Text(
                context.localized(
                  "Zählstellen-Token speichern",
                  (l10n) => l10n.mobilityZaehlstellenTokenSpeichern6579a132,
                ),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : () => _save(true),
              child: Text(
                context.localized(
                  "Zählstellen-Token entfernen",
                  (l10n) => l10n.mobilityZaehlstellenTokenEntfernen15b8092b,
                ),
              ),
            ),
          ],
        ),
      ],
      if (_message != null) Text(_message!),
      TrafficCountersReadout(
        provider: _provider,
        allowRefresh: _terms && !kIsWeb,
        onShowMap: () => widget.onShowMap({
          'id': 'traffic-counters',
          'visible': true,
          'features': _provider.status.dataset?.data['features'] ?? [],
        }),
      ),
    ],
  );
}

class TrafficCountersReadout extends StatefulWidget {
  const TrafficCountersReadout({
    super.key,
    required this.provider,
    this.allowRefresh = true,
    this.onShowMap,
  });
  final TrafficCountersProvider provider;
  final bool allowRefresh;
  final Future<void> Function()? onShowMap;
  @override
  State<TrafficCountersReadout> createState() => _TrafficCountersReadoutState();
}

class _TrafficCountersReadoutState extends State<TrafficCountersReadout> {
  int _limit = 20;
  String? _mapError;
  Future<void> _refresh() async {
    try {
      await widget.provider.fetch(forceRefresh: true);
    } catch (_) {
      /* Provider retains the last valid dataset. */
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final provider = widget.provider,
          status = provider.status,
          dataset = status.dataset;
      final records = (dataset?.data['features'] as List?) ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.localizedWithArgs(
              "Gebiet: {0}, {1} · 30 km · maximal 100 Detektoren",
              [
                provider.center.latitude.toStringAsFixed(4),
                provider.center.longitude.toStringAsFixed(4),
              ],
              (l10n, value) => l10n.commonGebietKmMaximalDetektoren3b49fe28(
                value(0),
                value(1),
              ),
            ),
          ),
          Text(
            context.localized(
              "Punktuelle Messungen der Quelle. Fahrzeugmengen sind Raten in Fahrzeugen pro Stunde. Werte verschiedener Fahrstreifen und Fahrzeuggruppen werden nicht addiert. Keine durchgehende Staukarte.",
              (l10n) => l10n.mobilityPunktuelleMessungenDerQuellee6b23c9f,
            ),
          ),
          FilledButton.icon(
            onPressed:
                !widget.allowRefresh ||
                    !provider.canRefresh ||
                    status.update == OsintUpdateState.loading
                ? null
                : _refresh,
            icon: const Icon(Icons.speed),
            label: Text(
              status.update == OsintUpdateState.loading
                  ? context.localized(
                      "Messwerte werden geladen …",
                      (l10n) => l10n.mobilityMesswerteWerdenGeladence66c18a,
                    )
                  : context.localized(
                      "Messwerte aktualisieren",
                      (l10n) => l10n.mobilityMesswerteAktualisierendbc899d0,
                    ),
            ),
          ),
          if (status.error != null)
            Text(
              status.error!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (dataset != null) ...[
            Text(
              context.localizedWithArgs(
                "Abruf: {0} · Quellenpublikation: {1}",
                [
                  trafficTime(dataset.fetchedAtUtc),
                  trafficTime(dataset.publishedAtUtc),
                ],
                (l10n, value) => l10n.mobilityAbrufQuellenpublikation2c701097(
                  value(0),
                  value(1),
                ),
              ),
            ),
            Text(
              context.localizedWithArgs(
                "{0} zugeordnete Detektoren · {1} ohne passende Metadaten",
                [records.length, dataset.data['unknown']],
                (l10n, value) =>
                    l10n.mobilityZugeordneteDetektorenOhnePassende637e378d(
                      value(0),
                      value(1),
                    ),
              ),
            ),
            if (status.dataState != OsintDataState.fresh)
              Text(
                context.localized(
                  "Abruf veraltet oder fehlgeschlagen · Messzeit jedes Werts prüfen.",
                  (l10n) =>
                      l10n.mobilityAbrufVeraltetOderFehlgeschlagen4afc83f7,
                ),
              ),
            if (widget.onShowMap != null)
              OutlinedButton(
                onPressed: () async {
                  try {
                    await widget.onShowMap!();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _mapError = 'Messstellen konnten nicht auf der Karte angezeigt werden.',
                      );
                    }
                  }
                },
                child: Text(
                  context.localized(
                    "Messstellen auf Karte zeigen",
                    (l10n) => l10n.mobilityMessstellenAufKarteZeigen191576b4,
                  ),
                ),
              ),
            if (_mapError != null) Text(_mapError!),
            for (final raw in records.take(_limit))
              _record(Map<String, dynamic>.from(raw as Map)),
            if (records.length > _limit)
              TextButton(
                onPressed: () => setState(() => _limit += 20),
                child: Text(
                  context.localized(
                    "Weitere Messstellen",
                    (l10n) => l10n.mobilityWeitereMessstellene0dab34a,
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
  Widget _record(Map<String, dynamic> record) {
    final time = DateTime.tryParse(record['timestampUtc'] as String? ?? ''),
        now = widget.provider.nowUtc;
    final age = time == null ? null : now.difference(time);
    final current =
        age != null &&
        age >= const Duration(seconds: -5) &&
        age <= const Duration(minutes: 3);
    final values = (record['values'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => v['value'] is num)
        .toList();
    final light = values.where((v) => v['vehicle'] == 'car').toList();
    final summary = (light.isEmpty ? values : light).take(2).toList();
    return Card(
      child: ExpansionTile(
        title: Text(record['name'] as String),
        leading: Icon(
          Icons.speed,
          color: current ? null : Theme.of(context).colorScheme.error,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${current ? 'Messung' : 'Messzeit unbekannt / veraltet'}: ${trafficTime(time)}',
            ),
            if (summary.isEmpty)
              Text(
                context.localized(
                  "Keine auswertbaren Messwerte",
                  (l10n) => l10n.mobilityKeineAuswertbarenMesswerte4dc49063,
                ),
              ),
            for (final v in summary)
              Text(
                '${v['kind'] == 'trafficSpeed' ? 'Ø Geschwindigkeit' : 'Fahrzeugrate'}: ${(v['value'] as num).toStringAsFixed(v['kind'] == 'trafficSpeed' ? 1 : 0)} ${v['kind'] == 'trafficSpeed' ? 'km/h' : 'Fahrzeuge/h'} · ${v['vehicle'] == 'car' ? 'Leichte Fahrzeuge' : v['vehicle']}',
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localizedWithArgs(
                    "Detektor: {0} · Fahrstreifen: {1} · Fahrbahntyp: {2}",
                    [record['id'], record['lane'], record['carriageway']],
                    (l10n, value) =>
                        l10n.mobilityDetektorFahrstreifenFahrbahntype8312098(
                          value(0),
                          value(1),
                          value(2),
                        ),
                  ),
                ),
                for (final raw in record['values'] as List)
                  _value(Map<String, dynamic>.from(raw as Map), time),
                Text(
                  context.localized(
                    "ASTRA / VDP · Best-Effort-Messdaten, keine bestätigte Verkehrsprognose.",
                    (l10n) => l10n.commonAstraVdpBestEffort6d0423b7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _value(Map<String, dynamic> value, DateTime? fallback) {
    final vehicle = switch (value['vehicle']) {
      'car' => 'Leichte Fahrzeuge (car)',
      'lorry' => 'Schwere Fahrzeuge (lorry)',
      _ => 'Quellengruppe: ${value['vehicle']}',
    };
    final amount = value['value'] as num?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        context.localizedWithArgs(
          "{0} · {1}: {2} {3}\nMesszeit: {4} · Intervall: {5} s{6}",
          [
            vehicle,
            value['kind'] == 'trafficSpeed'
                ? 'Ø Geschwindigkeit'
                : 'Fahrzeugrate',
            amount == null
                ? 'nicht verfügbar'
                : amount.toStringAsFixed(
                    value['kind'] == 'trafficSpeed' ? 1 : 0,
                  ),
            value['kind'] == 'trafficSpeed' ? 'km/h' : 'Fahrzeuge/h',
            trafficTime(
              DateTime.tryParse(value['timeUtc'] as String? ?? '') ?? fallback,
            ),
            value['periodSeconds'] ?? "unbekannt",
            value['error'] == true ? ' · Quellenfehler' : '',
          ],
          (l10n, value) => l10n.mobilityMesszeitIntervallSd22c606f(
            value(0),
            value(1),
            value(2),
            value(3),
            value(4),
            value(5),
            value(6),
          ),
        ),
      ),
    );
  }
}
