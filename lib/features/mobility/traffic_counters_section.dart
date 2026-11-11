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
    title: Text(context.translate("Live-Messwerte · Traffic Counters")),
    subtitle: Text(
      context.translate("Geschwindigkeiten und Fahrzeugmengen an Messstellen"),
    ),
    children: [
      Text(
        context.translate(
          "Eigener Zugang für Traffic Counters. Der Schlüssel für Verkehrsmeldungen wird dafür nicht wiederverwendet. Daten bleiben in dieser Sitzung.",
        ),
      ),
      if (kIsWeb)
        Text(context.translate("Direkter Abruf auf Android verfügbar.")),
      if (!kIsWeb) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _terms,
          onChanged: (v) => setState(() => _terms = v ?? false),
          title: Text(
            context.translate(
              "Zählstellenzugang freigeschaltet und ASTRA-Bedingungen akzeptiert",
            ),
          ),
        ),
        TextField(
          controller: _key,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.translate("Eigener Traffic-Counters-Token"),
            helperText: context.translate("Token verwenden, nicht Token Hash."),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving || !_terms ? null : () => _save(false),
              child: Text(context.translate("Zählstellen-Token speichern")),
            ),
            TextButton(
              onPressed: _saving ? null : () => _save(true),
              child: Text(context.translate("Zählstellen-Token entfernen")),
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
            context.translate(
              "Gebiet: {0}, {1} · 30 km · maximal 100 Detektoren",
              [
                provider.center.latitude.toStringAsFixed(4),
                provider.center.longitude.toStringAsFixed(4),
              ],
            ),
          ),
          Text(
            context.translate(
              "Punktuelle Messungen der Quelle. Fahrzeugmengen sind Raten in Fahrzeugen pro Stunde. Werte verschiedener Fahrstreifen und Fahrzeuggruppen werden nicht addiert. Keine durchgehende Staukarte.",
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
                  ? context.translate("Messwerte werden geladen …")
                  : context.translate("Messwerte aktualisieren"),
            ),
          ),
          if (status.error != null)
            Text(
              status.error!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (dataset != null) ...[
            Text(
              context.translate("Abruf: {0} · Quellenpublikation: {1}", [
                trafficTime(dataset.fetchedAtUtc),
                trafficTime(dataset.publishedAtUtc),
              ]),
            ),
            Text(
              context.translate(
                "{0} zugeordnete Detektoren · {1} ohne passende Metadaten",
                [records.length, dataset.data['unknown']],
              ),
            ),
            if (status.dataState != OsintDataState.fresh)
              Text(
                context.translate(
                  "Abruf veraltet oder fehlgeschlagen · Messzeit jedes Werts prüfen.",
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
                child: Text(context.translate("Messstellen auf Karte zeigen")),
              ),
            if (_mapError != null) Text(_mapError!),
            for (final raw in records.take(_limit))
              _record(Map<String, dynamic>.from(raw as Map)),
            if (records.length > _limit)
              TextButton(
                onPressed: () => setState(() => _limit += 20),
                child: Text(context.translate("Weitere Messstellen")),
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
              Text(context.translate("Keine auswertbaren Messwerte")),
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
                  context.translate(
                    "Detektor: {0} · Fahrstreifen: {1} · Fahrbahntyp: {2}",
                    [record['id'], record['lane'], record['carriageway']],
                  ),
                ),
                for (final raw in record['values'] as List)
                  _value(Map<String, dynamic>.from(raw as Map), time),
                Text(
                  context.translate(
                    "ASTRA / VDP · Best-Effort-Messdaten, keine bestätigte Verkehrsprognose.",
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
        context.translate(
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
        ),
      ),
    );
  }
}
