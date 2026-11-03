import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../globe/globe_controller.dart';
import '../road_routing.dart';
import 'prevention_models.dart';
import 'prevention_service.dart';

/// Details for a single requested coordinate. The independent WMS layer is
/// controlled by SituationalLayersSection, not by this lookup widget.
class WildfirePreventionSection extends StatefulWidget {
  const WildfirePreventionSection({
    super.key,
    required this.globe,
    this.initialCenter,
    this.service,
  });
  final GlobeController globe;
  final MobilityPoint? initialCenter;
  final PreventionService? service;

  @override
  State<WildfirePreventionSection> createState() =>
      _WildfirePreventionSectionState();
}

class _WildfirePreventionSectionState extends State<WildfirePreventionSection> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  PreventionService? _ownedService;
  PreventionService get _service =>
      widget.service ?? (_ownedService ??= PreventionService());
  PreventionSnapshot? _snapshot;
  bool _loading = false;
  bool _allowQuery = false;
  bool _expanded = false;
  String? _message;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final center = widget.initialCenter;
    final selected = widget.globe.selectedPoint;
    if (center != null) {
      _setPoint(center.latitude, center.longitude);
    } else if (selected != null) {
      _setPoint(selected.latitude, selected.longitude);
    }
  }

  void _setPoint(double latitude, double longitude) {
    _latitude.text = '$latitude';
    _longitude.text = '$longitude';
    _snapshot = null;
    _message = null;
  }

  (double, double) _point() {
    final lat = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null) {
      throw const FormatException('Enter latitude and longitude.');
    }
    preventionIdentifyUrl(lat, lon);
    return (lat, lon);
  }

  Future<void> _load({bool refresh = false, bool offline = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    final generation = ++_generation;
    try {
      final point = _point();
      if (!offline && !_allowQuery) {
        throw const FormatException(
          'Confirm that the chosen coordinate may be sent to geo.admin.ch.',
        );
      }
      final result = offline
          ? await _service.offline(point.$1, point.$2)
          : await _service.search(point.$1, point.$2, refresh: refresh);
      if (!mounted || generation != _generation) return;
      setState(() {
        _snapshot = result;
        if (result == null) {
          _message =
              'No stored snapshot for this coordinate. Not an all-clear.';
        }
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Measure data unavailable; no all-clear.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _official(String path) async {
    await launchUrl(
      Uri.parse('https://www.waldbrandgefahr.ch/de/$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    _generation++;
    _latitude.dispose();
    _longitude.dispose();
    if (_ownedService != null) {
      unawaited(_ownedService!.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final stale = snapshot == null || snapshot.isOutdated(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (value) => setState(() => _expanded = value),
          tilePadding: EdgeInsets.zero,
          title: const Text('Kantonale Waldbrand-Präventionsmassnahmen'),
          subtitle: const Text(
            'Offizielle Einzelabfrage · unabhängig von der Waldbrand-Gefahrenstufe',
          ),
          children: [
            const Text(
              'Die Kantone erlassen die verbindlichen Regeln. Eine Gefahrenstufe allein begründet kein Feuerverbot. Fehlende, veraltete oder unvollständige Daten bedeuten keine Entwarnung.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('fire_prevention_lat'),
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    onChanged: (_) => setState(() => _snapshot = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('fire_prevention_lon'),
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    onChanged: (_) => setState(() => _snapshot = null),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        final point = widget.globe.selectedPoint;
                        if (point == null) {
                          setState(
                            () => _message = 'No selected point on the globe.',
                          );
                        } else {
                          setState(
                            () => _setPoint(point.latitude, point.longitude),
                          );
                        }
                      },
                icon: const Icon(Icons.place_outlined),
                label: const Text('Ausgewählten Kartenpunkt übernehmen'),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _allowQuery,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _allowQuery = value ?? false),
              title: const Text(
                'Koordinaten für die Abfrage an geo.admin.ch senden',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  key: const ValueKey('fire_prevention_query'),
                  onPressed: _loading ? null : () => _load(refresh: true),
                  child: const Text('Amtliche Massnahmen abfragen'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _load(offline: true),
                  child: const Text('Gespeicherte Abfrage anzeigen'),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_message!),
              ),
            if (snapshot != null) ...[
              const SizedBox(height: 10),
              Text(
                'Abgerufen: ${snapshot.fetchedUtc.toIso8601String()} (UTC)'
                '${snapshot.fromCache ? ' · Cache' : ''}'
                '${snapshot.refreshFailed ? ' · Aktualisierung fehlgeschlagen' : ''}',
              ),
              Text(
                'Publikationsstand der Quelle: ${snapshot.publicationRaw ?? 'unbekannt'}',
              ),
              Text('Datenstatus: ${snapshot.freshnessLabel(DateTime.now())}'),
              if (stale)
                const Text(
                  'Aktualität nicht bestätigt – Angaben können überholt sein. '
                  'Lokale Anordnungen prüfen.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              if (snapshot.truncated)
                const Text(
                  'Abfrage begrenzt. Weitere oder überlappende Regeln möglich.',
                ),
              if (snapshot.measures.isEmpty)
                const Text(
                  'Keine datierten Massnahmen für diesen Punkt ermittelt. '
                  'Die Abdeckung kann unvollständig sein – KEINE Entwarnung.',
                ),
              if (snapshot.measures.length > 1)
                const Text(
                  'Mehrere amtliche Gebiete überlagern sich. Geltungsbereich '
                  'und Vorrang bitte bei den Kantonen prüfen.',
                ),
              for (final measure in snapshot.measures)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          measure.category == PreventionCategory.unknown
                              ? 'Nicht klassifiziert: ${measure.title}'
                              : preventionCategoryLabel(measure.category),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text('Amtlicher Titel: ${measure.title}'),
                        if (measure.description != null)
                          Text(measure.description!),
                        Text(
                          'Kanton: ${measure.canton ?? 'unbekannt'} · '
                          'Gebiet: ${measure.region ?? 'unbekannt'}',
                        ),
                        Text(
                          'Gültig seit: ${measure.validFromRaw ?? 'nicht angegeben'}'
                          ' · bis: ${measure.validUntilRaw ?? 'nicht angegeben'}',
                        ),
                        Text('BAFU Feature-ID: ${measure.sourceId}'),
                      ],
                    ),
                  ),
                ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _official('aktuelle-massnahmen'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Aktuelle amtliche Massnahmen'),
                ),
                TextButton.icon(
                  onPressed: () => _official('kantonale-fachstellen'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Kantonale Fachstellen'),
                ),
              ],
            ),
            const Text(
              'Quelle: BAFU / Kantone · geo.admin.ch · waldbrandgefahr.ch',
            ),
          ],
        ),
      ],
    );
  }
}
