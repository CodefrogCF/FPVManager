import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/fpv_database.dart' show Spot;
import '../../globe/globe_controller.dart';
import '../../spots/data/spot_location_service.dart';
import '../../spots/data/spot_repository.dart';
import '../road_routing.dart';
import 'ev_charging_models.dart';
import 'ev_charging_service.dart';

/// Optional manual EV search: loading the tab never makes a remote request.
class EvChargingSection extends StatefulWidget {
  const EvChargingSection({
    super.key,
    required this.spots,
    required this.globe,
    required this.onDriveTo,
    this.initialMapPoint,
    this.initialSpotId,
    this.route,
    this.service,
  });
  final SpotRepository spots;
  final GlobeController globe;
  final void Function(EvChargingStation) onDriveTo;
  final MobilityPoint? initialMapPoint;
  final int? initialSpotId;
  final RoadRoute? route;
  final EvChargingService? service;
  @override
  State<EvChargingSection> createState() => _EvChargingSectionState();
}

class _EvChargingSectionState extends State<EvChargingSection> {
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  late final Future<List<Spot>> _spots = widget.spots.getAllSpots();
  late final EvChargingService _service = widget.service ?? EvChargingService();
  EvChargingSnapshot? _snapshot;
  int _radius = 2000;
  int? _spotId;
  bool _agree = false;
  bool _working = false;
  String? _message;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _spotId = widget.initialMapPoint == null ? widget.initialSpotId : null;
    if (widget.initialMapPoint != null) {
      _setCenter(widget.initialMapPoint!);
    } else {
      unawaited(_initialSpot());
    }
  }

  Future<void> _initialSpot() async {
    try {
      final all = await _spots;
      if (!mounted || all.isEmpty || _lat.text.isNotEmpty) return;
      final selected =
          all.where((s) => s.id == widget.initialSpotId).firstOrNull ??
          all.first;
      setState(() {
        _spotId = selected.id;
        _setCenter(MobilityPoint(selected.latitude, selected.longitude));
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Spots unavailable: enter coordinates.');
      }
    }
  }

  void _setCenter(MobilityPoint point) {
    _lat.text = '${point.latitude}';
    _lon.text = '${point.longitude}';
    _snapshot = null;
  }

  EvChargingArea _area() {
    final a = double.tryParse(_lat.text.replaceAll(',', '.').trim());
    final b = double.tryParse(_lon.text.replaceAll(',', '.').trim());
    if (a == null || b == null) {
      throw const FormatException('Enter latitude and longitude.');
    }
    return EvChargingArea(latitude: a, longitude: b, radiusMeters: _radius);
  }

  Future<void> _execute(Future<void> Function() fn) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await fn();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'Charging data unavailable; try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _load({bool refresh = false, bool offline = false}) =>
      _execute(() async {
        final area = _area();
        if (!offline && !_agree) {
          throw const FormatException(
            'Confirm that you permit a location query to the BFE service.',
          );
        }
        final generation = ++_requestGeneration;
        final snapshot = offline
            ? await _service.offline(area)
            : await _service.search(area, refresh: refresh);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _snapshot = snapshot;
          if (snapshot == null) _message = 'No saved snapshot for this area.';
        });
      });

  Future<void> _deviceLocation() => _execute(() async {
    final position = await const SpotLocationService().currentLocation();
    if (mounted) {
      setState(() {
        _spotId = null;
        _setCenter(
          MobilityPoint(
            position.position.latitude,
            position.position.longitude,
          ),
        );
      });
    }
  });

  Future<void> _onMap() => _execute(() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final now = DateTime.now().toUtc();
    await widget.globe.showSituationalOverlay({
      'id': 'ev-charging',
      'visible': true,
      'features': [
        for (final indexed in snapshot.stations.take(150).indexed)
          {
            'id': 'bfe-station-${indexed.$1}',
            'name': indexed.$2.name.length > 200
                ? indexed.$2.name.substring(0, 200)
                : indexed.$2.name,
            'detail': _description(indexed.$2, snapshot, now),
            'geometry': {
              'type': 'Point',
              'coordinates': [indexed.$2.longitude, indexed.$2.latitude],
            },
          },
      ],
    });
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  });

  String _description(
    EvChargingStation station,
    EvChargingSnapshot snapshot,
    DateTime now,
  ) {
    final lines = <String>[
      station.address ?? '',
      'Quellen-ID: ${station.id}',
      ...station.connectors
          .take(8)
          .map(
            (c) =>
                '${c.type} ${c.powerKw == null ? '' : '${c.powerKw!.toStringAsFixed(1)} kW'}',
          ),
      ...station.evseIds
          .take(8)
          .map(
            (id) =>
                '${snapshot.refreshFailed ? 'Unbekannt (failed refresh)' : snapshot.statuses[id]?.label(now) ?? 'Unbekannt'} · $id',
          ),
      'Stand: ${snapshot.fetchedUtc.toIso8601String()} UTC${snapshot.fromCache ? ' (Cache)' : ''}',
      'Quelle: Bundesamt für Energie (BFE) / geo.admin.ch · O-By-Ask',
      'Keine garantierte Ladepunkt-Verfügbarkeit.',
    ];
    final text = lines.join('\n');
    return text.length > 1200 ? text.substring(0, 1200) : text;
  }

  @override
  void dispose() {
    _requestGeneration++;
    _lat.dispose();
    _lon.dispose();
    if (widget.service == null) unawaited(_service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    final now = DateTime.now().toUtc();
    final route = widget.route;
    final routePoints = route?.points ?? const <MobilityPoint>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.localized(
            "Ladestationen in der Schweiz · BFE / geo.admin.ch. Freie Plätze sind nur eine datierte Meldung und keine Reservierung. Ergebnisse können unvollständig sein.",
            (l10n) => l10n.mobilityLadestationenInDerSchweiza8bd739c,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Spot>>(
          future: _spots,
          builder: (context, state) => DropdownButtonFormField<int>(
            key: ValueKey('ev_selected_spot_${_spotId ?? 'none'}'),
            initialValue: state.data?.any((s) => s.id == _spotId) == true
                ? _spotId
                : null,
            decoration: InputDecoration(
              labelText: context.localized(
                "Suchzentrum: gespeicherter Spot (optional)",
                (l10n) =>
                    l10n.mobilitySuchzentrumGespeicherterSpotOptional8f6f54a7,
              ),
            ),
            isExpanded: true,
            items: [
              for (final s in state.data ?? <Spot>[])
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _working
                ? null
                : (id) {
                    final chosen = state.data
                        ?.where((s) => s.id == id)
                        .firstOrNull;
                    if (chosen != null) {
                      setState(() {
                        _spotId = id;
                        _setCenter(
                          MobilityPoint(chosen.latitude, chosen.longitude),
                        );
                      });
                    }
                  },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('ev_lat'),
                controller: _lat,
                decoration: InputDecoration(
                  labelText: context.localized(
                    "Latitude",
                    (l10n) => l10n.mobilityLatitudeced3905e,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (_) => setState(() {
                  _spotId = null;
                  _snapshot = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('ev_lon'),
                controller: _lon,
                decoration: InputDecoration(
                  labelText: context.localized(
                    "Longitude",
                    (l10n) => l10n.mobilityLongitude6f9f011c,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (_) => setState(() {
                  _spotId = null;
                  _snapshot = null;
                }),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: _working ? null : _deviceLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                context.localized(
                  "Mein Standort",
                  (l10n) => l10n.commonMeinStandort98425c52,
                ),
              ),
            ),
            if (routePoints.isNotEmpty)
              for (final item in [
                (label: 'Routenstart', point: routePoints.first),
                (
                  label: 'Routenmitte',
                  point: routePoints[routePoints.length ~/ 2],
                ),
                (label: 'Routenziel', point: routePoints.last),
              ])
                OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => setState(() {
                          _spotId = null;
                          _setCenter(item.point);
                        }),
                  child: Text(item.label),
                ),
          ],
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('ev_radius_$_radius'),
          initialValue: _radius,
          decoration: InputDecoration(
            labelText: context.localized(
              "Suchradius",
              (l10n) => l10n.mobilitySuchradius51fb2797,
            ),
          ),
          items: [500, 1000, 2000, 5000]
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text('${(v / 1000).toStringAsFixed(1)} km'),
                ),
              )
              .toList(),
          onChanged: _working
              ? null
              : (v) => setState(() {
                  _radius = v ?? 2000;
                  _snapshot = null;
                }),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          title: Text(
            context.localized(
              "Suchkoordinaten beim BFE / geo.admin.ch abfragen",
              (l10n) => l10n.mobilitySuchkoordinatenBeimBfeGeo298d1eb7,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Nur durch ausdrückliches Suchen; keine Standortüberwachung.",
              (l10n) => l10n.mobilityNurDurchAusdruecklichesSuchen62af35c2,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _working || !_agree ? null : () => _load(),
              icon: const Icon(Icons.ev_station),
              label: Text(
                context.localized(
                  "Ladestationen suchen",
                  (l10n) => l10n.mobilityLadestationenSuchen805f1685,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _working || !_agree
                  ? null
                  : () => _load(refresh: true),
              child: Text(
                context.localized(
                  "Aktualisieren",
                  (l10n) => l10n.mobilityAktualisieren87c65f26,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _working ? null : () => _load(offline: true),
              child: const Text('Offline-Snapshot'),
            ),
          ],
        ),
        if (_working) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (snap != null) ...[
          const Divider(),
          Text(
            context.localizedWithArgs(
              "{0} Ladestandorte · Abruf {1}{2}",
              [
                snap.stations.length,
                snap.fetchedUtc.toLocal(),
                snap.fromCache ? ' · lokal gespeichert' : '',
              ],
              (l10n, value) => l10n.mobilityLadestandorteAbrufe451a0c3(
                value(0),
                value(1),
                value(2),
              ),
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (snap.refreshFailed)
            Text(
              context.localized(
                "Aktualisierung fehlgeschlagen: alte Standortdaten; Verfügbarkeit unbekannt.",
                (l10n) => l10n
                    .mobilityAktualisierungFehlgeschlagenAlteStandortdatenb2f09fc6,
              ),
            ),
          if (snap.truncated)
            Text(
              context.localized(
                "Maximale Trefferzahl erreicht: nicht alle Standorte erfasst. Radius verkleinern.",
                (l10n) => l10n.mobilityMaximaleTrefferzahlErreichtNichtcbd9a35f,
              ),
            ),
          if (snap.isOld(now))
            Text(
              context.localized(
                "Gespeicherter Abruf ist älter als 15 Minuten.",
                (l10n) => l10n.mobilityGespeicherterAbrufIstAelterc7e97b86,
              ),
            ),
          Text(
            context.localized(
              "Keine Treffer bedeuten nicht, dass es keine Ladestationen gibt.",
              (l10n) => l10n.commonKeineTrefferBedeutenNicht4cb792ac,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _working ? null : _onMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              context.localized(
                "Auf 3D-Karte anzeigen (max. 150)",
                (l10n) => l10n.mobilityAufDKarteAnzeigen2ad897d8,
              ),
            ),
          ),
          for (final station in snap.stations.take(60))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (station.address != null) Text(station.address!),
                    Text(
                      '${station.latitude.toStringAsFixed(5)}, ${station.longitude.toStringAsFixed(5)}',
                    ),
                    if (station.connectors.isNotEmpty)
                      Text(
                        station.connectors
                            .take(10)
                            .map(
                              (c) =>
                                  '${c.type}'
                                  '${c.powerKw == null ? '' : ' · ${c.powerKw!.toStringAsFixed(1)} kW'}',
                            )
                            .join(' | '),
                      ),
                    if (station.connectors.isEmpty)
                      Text(
                        context.localized(
                          "Anschlüsse: nicht veröffentlicht",
                          (l10n) => l10n
                              .mobilityAnschluesseNichtVeroeffentlicht1584b8b8,
                        ),
                      ),
                    for (final id in station.evseIds.take(5))
                      Text(
                        '${snap.refreshFailed ? 'Unbekannt / Refresh fehlgeschlagen' : snap.statuses[id]?.label(now) ?? 'Verfügbarkeit unbekannt'}'
                        ' · ${snap.statuses[id]?.updatedUtc?.toLocal().toString() ?? 'kein Statuszeitpunkt'}',
                      ),
                    Text(
                      context.localizedWithArgs("Quelle: {0}", [
                        station.id,
                      ], (l10n, value) => l10n.commonQuelle25cfc7b8(value(0))),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => widget.onDriveTo(station),
                        icon: const Icon(Icons.directions_car),
                        label: Text(
                          context.localized(
                            "Als Fahrziel wählen",
                            (l10n) => l10n.mobilityAlsFahrzielWaehlen89ab104c,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (snap.stations.length > 60)
            Text(
              context.localized(
                "Liste auf 60 Einträge begrenzt; Radius verkleinern.",
                (l10n) => l10n.mobilityListeAufEintraegeBegrenzt47537bf9,
              ),
            ),
        ],
        const Divider(),
        Text(
          context.localized(
            "Datenquelle: Bundesamt für Energie (BFE), Ladepunkte Elektromobilität, geo.admin.ch · O-By-Ask. Nutzung mit Quellenangabe; kommerzielle Nutzung nur mit vorheriger Erlaubnis des Dateninhabers.",
            (l10n) => l10n.commonDatenquelleBundesamtFuerEnergieb3a50654,
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/SFOE/ichtankestrom_Documentation'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(
            context.localized(
              "BFE-Dokumentation und Nutzungsbedingungen",
              (l10n) =>
                  l10n.mobilityBfeDokumentationUndNutzungsbedingungen58dca300,
            ),
          ),
        ),
      ],
    );
  }
}
