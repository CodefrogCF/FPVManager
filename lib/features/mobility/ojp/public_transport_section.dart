import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/fpv_database.dart' show Spot;
import '../../../core/osint/api_credential_vault.dart';
import '../../airspace/api_credentials_section.dart';
import '../../globe/globe_controller.dart';
import '../../spots/data/spot_location_service.dart';
import '../../spots/data/spot_repository.dart';
import '../destination_search.dart';
import '../mobility_preferences.dart';
import '../road_routing.dart';
import 'ojp_client.dart';
import 'ojp_models.dart';

/// OJP 2.0 only; coordinate destinations never silently switch to parking.
class PublicTransportSection extends StatefulWidget {
  const PublicTransportSection({
    super.key,
    required this.spots,
    required this.preferences,
    required this.globe,
    this.initialSpotId,
    this.initialMapPoint,
    this.initialOrigin,
    this.initialDestination,
    this.initialOriginName,
    this.initialDestinationName,
    this.client,
    this.onShowNearbyMobility,
  });
  final SpotRepository spots;
  final MobilityPreferences preferences;
  final GlobeController globe;
  final int? initialSpotId;
  final MobilityPoint? initialMapPoint, initialOrigin, initialDestination;
  final String? initialOriginName, initialDestinationName;
  final OjpTripClient? client;
  final void Function(MobilityPoint destination)? onShowNearbyMobility;

  @override
  State<PublicTransportSection> createState() => _PublicTransportSectionState();
}

class _PublicTransportSectionState extends State<PublicTransportSection> {
  final _fields = {
    for (final key in [
      'originLat',
      'originLon',
      'destinationLat',
      'destinationLon',
    ])
      key: TextEditingController(),
  };
  late final OjpTripClient _client =
      widget.client ??
      OjpTripClient(
        readKey: () =>
            LocalApiCredentialVault.shared.readForProvider(ojp20Access),
      );
  late final Future<List<Spot>> _spots = widget.spots.getAllSpots();
  DateTime _localTime = DateTime.now().add(const Duration(minutes: 15));
  OjpTimeMode _mode = OjpTimeMode.departure;
  String _originName = 'Koordinaten', _destinationName = 'Koordinaten';
  int? _originSpotId, _destinationSpotId;
  bool _consent = false, _busy = false, _savedResult = false;
  String? _message;
  OjpJourneySnapshot? _result;
  List<OjpJourneySnapshot> _saved = [];
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _setPoint('origin', widget.initialOrigin, widget.initialOriginName);
    _setPoint(
      'destination',
      widget.initialDestination ?? widget.initialMapPoint,
      widget.initialDestinationName ??
          (widget.initialMapPoint == null ? null : 'Kartenpunkt'),
    );
    unawaited(_initData());
  }

  Future<void> _initData() async {
    try {
      final snapshots = await widget.preferences.loadOjpSnapshots();
      if (mounted) setState(() => _saved = snapshots);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Gespeicherte ÖV-Verbindungen konnten nicht geladen werden.',
        );
      }
    }
    try {
      final spots = await _spots;
      if (!mounted || spots.isEmpty) return;
      if (widget.initialDestination == null &&
          widget.initialMapPoint == null &&
          _fields['destinationLat']!.text.isEmpty) {
        final selected =
            spots
                .where((spot) => spot.id == widget.initialSpotId)
                .firstOrNull ??
            spots.first;
        _selectSpot('destination', selected);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Gespeicherte Spots sind nicht verfügbar.');
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    if (widget.client == null) _client.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setPoint(String kind, MobilityPoint? point, String? name) {
    if (point == null) return;
    _fields['${kind}Lat']!.text = '${point.latitude}';
    _fields['${kind}Lon']!.text = '${point.longitude}';
    if (kind == 'origin') {
      _originName = name ?? 'Koordinaten';
    } else {
      _destinationName = name ?? 'Koordinaten';
    }
  }

  void _selectSpot(String kind, Spot spot) {
    setState(() {
      _setPoint(kind, MobilityPoint(spot.latitude, spot.longitude), spot.name);
      if (kind == 'origin') {
        _originSpotId = spot.id;
      } else {
        _destinationSpotId = spot.id;
      }
      _result = null;
    });
  }

  MobilityPoint _point(String kind) {
    final latitude = double.tryParse(
      _fields['${kind}Lat']!.text.trim().replaceAll(',', '.'),
    );
    final longitude = double.tryParse(
      _fields['${kind}Lon']!.text.trim().replaceAll(',', '.'),
    );
    if (latitude == null || longitude == null) {
      throw const FormatException(
        'Start- und Zielkoordinaten vollständig eingeben.',
      );
    }
    return MobilityPoint(latitude, longitude);
  }

  Widget _coordinates(String kind) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        kind == 'origin' ? 'Start' : context.translate("Ziel"),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 6),
      FutureBuilder<List<Spot>>(
        future: _spots,
        builder: (context, snapshot) => DropdownButtonFormField<int>(
          key: ValueKey(
            'ojp_${kind}_spot_${kind == 'origin' ? _originSpotId : _destinationSpotId}',
          ),
          initialValue: kind == 'origin' ? _originSpotId : _destinationSpotId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.translate(
              "Gespeicherten Spot übernehmen (optional)",
            ),
          ),
          items: [
            for (final spot in snapshot.data ?? <Spot>[])
              DropdownMenuItem(
                value: spot.id,
                child: Text(spot.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy || !snapshot.hasData
              ? null
              : (id) {
                  final spot = snapshot.data!
                      .where((spot) => spot.id == id)
                      .firstOrNull;
                  if (spot != null) _selectSpot(kind, spot);
                },
        ),
      ),
      const SizedBox(height: 8),
      RoadDestinationSearch(
        onSelected: (place) => setState(() {
          _setPoint(kind, place.point, place.name);
          if (kind == 'origin') {
            _originSpotId = null;
          } else {
            _destinationSpotId = null;
          }
          _result = null;
        }),
      ),
      Row(
        children: [
          for (final axis in ['Lat', 'Lon'])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  key: ValueKey('ojp_$kind$axis'),
                  controller: _fields['$kind$axis'],
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: axis == 'Lat'
                        ? context.translate("Breitengrad")
                        : context.translate("Längengrad"),
                  ),
                  onChanged: (_) => setState(() {
                    if (kind == 'origin') {
                      _originName = 'Koordinaten';
                      _originSpotId = null;
                    } else {
                      _destinationName = 'Koordinaten';
                      _destinationSpotId = null;
                    }
                    _result = null;
                  }),
                ),
              ),
            ),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    final selected = widget.globe.selectedPoint;
                    if (selected == null) {
                      setState(
                        () => _message =
                            'Zuerst einen Punkt auf der Karte auswählen.',
                      );
                      return;
                    }
                    setState(() {
                      _setPoint(
                        kind,
                        MobilityPoint(selected.latitude, selected.longitude),
                        'Kartenpunkt',
                      );
                      if (kind == 'origin') {
                        _originSpotId = null;
                      } else {
                        _destinationSpotId = null;
                      }
                      _result = null;
                    });
                  },
            icon: const Icon(Icons.map_outlined),
            label: Text(context.translate("Kartenpunkt")),
          ),
          if (kind == 'origin')
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        final location = await const SpotLocationService()
                            .currentLocation();
                        if (mounted) {
                          setState(() {
                            _setPoint(
                              'origin',
                              MobilityPoint(
                                location.position.latitude,
                                location.position.longitude,
                              ),
                              'Gerätestandort',
                            );
                            _originSpotId = null;
                            _result = null;
                          });
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _message = 'Standortfreigabe oder Positionsbestimmung fehlgeschlagen.',
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.my_location),
              label: Text(context.translate("Gerätestandort")),
            ),
        ],
      ),
      Text(
        kind == 'origin'
            ? 'Start: $_originName'
            : context.translate("Ziel: {0}", [_destinationName]),
      ),
    ],
  );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _localTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2037),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_localTime),
    );
    if (!mounted || time == null) return;
    final chosen = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (chosen.year != date.year ||
        chosen.month != date.month ||
        chosen.day != date.day ||
        chosen.hour != time.hour ||
        chosen.minute != time.minute) {
      setState(
        () => _message =
            'Diese lokale Uhrzeit existiert wegen der Zeitumstellung nicht.',
      );
      return;
    }
    setState(() {
      _localTime = chosen;
      _result = null;
      _message = null;
    });
  }

  Future<void> _calculate() async {
    if (_busy || !_consent) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final query = OjpTripQuery(
        origin: _point('origin'),
        destination: _point('destination'),
        timeUtc: _localTime.toUtc(),
        mode: _mode,
      );
      final snapshot = await _client.search(
        query,
        originName: _originName,
        destinationName: _destinationName,
      );
      if (mounted && _revision == revision) {
        setState(() {
          _result = snapshot;
          _savedResult = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted && _revision == revision) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted && _revision == revision) {
        setState(
          () => _message = kIsWeb
              ? 'OJP-Webzugriff fehlgeschlagen. Direkte Browseranfragen können durch CORS blockiert werden. Kein Proxy eingerichtet.'
              : 'OJP nicht erreichbar. Internetzugriff und API-Zugang prüfen.',
        );
      }
    } finally {
      if (mounted && _revision == revision) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_result == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.preferences.saveOjpSnapshot(_result!);
      final saved = await widget.preferences.loadOjpSnapshots();
      if (mounted) {
        setState(() {
          _saved = saved;
          _message =
              'Verbindung als datierte Momentaufnahme lokal gespeichert.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Verbindung konnte nicht gespeichert werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _format(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)} (${local.timeZoneName})';
  }

  Widget _timeRow(String label, OjpServiceTime time) {
    if (time.timetableUtc == null && time.estimatedUtc == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (time.timetableUtc != null)
          Text(
            context.translate("{0} Fahrplan: {1}", [
              label,
              _format(time.timetableUtc!),
            ]),
          ),
        if (time.estimatedUtc != null)
          Text(
            '$label Prognose: ${_format(time.estimatedUtc!)}'
            '${time.hasRealtimeChange ? ' · Änderung' : ''}',
          ),
      ],
    );
  }

  Widget _results() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          _savedResult
              ? context.translate("Gespeicherter Stand (offline nutzbar)")
              : context.translate("OJP-Abfrageergebnis"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.translate("Abgerufen am {0} · {1} → {2}", [
            _format(result.fetchedAtUtc),
            result.originName,
            result.destinationName,
          ]),
        ),
        Text(
          context.translate(
            "Fahrplan ist nicht garantiert. Prognosen nur, wenn vom Datenlieferanten verfügbar. Gespeicherte Daten sind niemals live.",
          ),
        ),
        if (result.journeys.isEmpty)
          Text(
            context.translate(
              "Für diese Anfrage wurden keine Verbindungen gefunden.",
            ),
          ),
        for (var i = 0; i < result.journeys.length; i++)
          Card(
            child: ExpansionTile(
              title: Text(
                context.translate("Verbindung {0}: {1} – {2}", [
                  i + 1,
                  _format(result.journeys[i].startUtc),
                  _format(result.journeys[i].endUtc),
                ]),
              ),
              subtitle: Text(
                context.translate("{0} Umstiege · {1} Fußwege", [
                  result.journeys[i].transfers,
                  result.journeys[i].legs
                      .where((leg) => leg.kind == OjpLegKind.walk)
                      .length,
                ]),
              ),
              children: [
                for (final leg in result.journeys[i].legs)
                  ListTile(
                    leading: Icon(
                      leg.kind == OjpLegKind.walk
                          ? Icons.directions_walk
                          : leg.kind == OjpLegKind.publicTransport
                          ? Icons.train_outlined
                          : Icons.transfer_within_a_station,
                    ),
                    title: Text(
                      '${switch (leg.kind) {
                        OjpLegKind.walk => 'Fußweg',
                        OjpLegKind.publicTransport => 'ÖV ${leg.line ?? leg.mode ?? ''}',
                        OjpLegKind.transfer => 'Umstieg',
                        OjpLegKind.other => leg.mode ?? 'Abschnitt',
                      }} · ${leg.from} → ${leg.to}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leg.duration != null || leg.distanceMetres != null)
                          Text(
                            '${leg.duration == null ? '' : '${leg.duration!.inMinutes} min'}'
                            '${leg.distanceMetres == null ? '' : ' · ${leg.distanceMetres!.round()} m'}',
                          ),
                        _timeRow('Abfahrt', leg.departure),
                        _timeRow('Ankunft', leg.arrival),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (!_savedResult && result.journeys.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              context.translate(
                "Verbindungen offline als Momentaufnahme speichern",
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.translate(
          "Offizieller Open Journey Planner 2.0 (Schweiz). Verbindungssuche bis zum tatsächlichen gewählten Punkt; Parkplatz- und Autokoordinaten werden nicht eingesetzt.",
        ),
      ),
      const SizedBox(height: 8),
      Text(
        context.translate(
          "Erforderlich: eigener OJP-2.0-API-Schlüssel mit freigeschaltetem Produkt. Zugangsdaten bleiben in lokalem Secure Storage (Web: nur Arbeitsspeicher dieser Sitzung).",
        ),
      ),
      ApiCredentialsSection(policies: [ojp20Access]),
      if (kIsWeb)
        Text(
          context.translate(
            "Web: OJP-CORS und Browser-Zugriff nicht verifiziert. Direkte Anfrage kann fehlschlagen. Kein Relay/Proxy vorhanden; Keys im Browser sind gegenüber Seitenskripten nicht geschützt.",
          ),
        ),
      const SizedBox(height: 12),
      _coordinates('origin'),
      const SizedBox(height: 16),
      _coordinates('destination'),
      const SizedBox(height: 12),
      SegmentedButton<OjpTimeMode>(
        segments: [
          ButtonSegment(
            value: OjpTimeMode.departure,
            label: Text(context.translate("Abfahrt")),
          ),
          ButtonSegment(
            value: OjpTimeMode.arrival,
            label: Text(context.translate("Ankunft")),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: _busy
            ? null
            : (values) => setState(() {
                _mode = values.first;
                _result = null;
              }),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _pickDateTime,
        icon: const Icon(Icons.schedule),
        label: Text(
          context.translate("{0} {1} (Gerätezeit)", [
            _mode == OjpTimeMode.departure ? 'Abfahrt ab' : 'Ankunft bis',
            _format(_localTime.toUtc()),
          ]),
        ),
      ),
      DropdownButtonFormField<OjpApiPlan>(
        initialValue: _client.plan,
        decoration: InputDecoration(
          labelText: context.translate("Aktiver OJP-API-Plan (Sitzung)"),
        ),
        items: [
          for (final plan in OjpApiPlan.values)
            DropdownMenuItem(value: plan, child: Text(plan.label)),
        ],
        onChanged: _busy
            ? null
            : (plan) {
                if (plan != null) setState(() => _client.plan = plan);
              },
      ),
      Text(
        context.translate(
          "Anfragebudget gilt nur für diese App-Sitzung. Die offiziellen Quoten gelten gemeinsam für alle Geräte mit demselben Schlüssel; HTTP 429 wird respektiert.",
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _consent,
        onChanged: _busy
            ? null
            : (value) => setState(() => _consent = value ?? false),
        title: Text(
          context.translate(
            "Start, Ziel und Reisezeit für die Abfrage an opentransportdata.swiss senden.",
          ),
        ),
      ),
      FilledButton.icon(
        onPressed: !_consent || _busy ? null : _calculate,
        icon: const Icon(Icons.directions_transit),
        label: Text(context.translate("ÖV-Verbindungen suchen")),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_saved.isNotEmpty)
        ExpansionTile(
          title: Text(
            context.translate("Gespeicherte Verbindungen ({0})", [
              _saved.length,
            ]),
          ),
          children: [
            for (final snapshot in _saved)
              ListTile(
                title: Text(
                  '${snapshot.originName} → ${snapshot.destinationName}',
                ),
                subtitle: Text(
                  context.translate("Stand {0} · offline, nicht live", [
                    _format(snapshot.fetchedAtUtc),
                  ]),
                ),
                onTap: () => setState(() {
                  _result = snapshot;
                  _savedResult = true;
                }),
              ),
          ],
        ),
      _results(),
      if (widget.onShowNearbyMobility != null &&
          _result != null &&
          _result!.journeys.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () {
            try {
              widget.onShowNearbyMobility!(_result!.query.destination);
            } on FormatException catch (error) {
              setState(() => _message = error.message);
            }
          },
          icon: const Icon(Icons.pedal_bike),
          label: Text(context.translate("Sharing-Angebote am ÖV-Ziel suchen")),
        ),
      TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(
            'https://opentransportdata.swiss/en/cookbook/open-journey-planner-ojp-landing-page/',
          ),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.open_in_new),
        label: Text(context.translate("OJP-Dokumentation und Quelle")),
      ),
    ],
  );
}

/// Direct entry point for ground routes without reinterpreting their endpoints.
class PublicTransportScreen extends StatelessWidget {
  const PublicTransportScreen({
    super.key,
    required this.spots,
    required this.preferences,
    required this.globe,
    this.origin,
    this.destination,
    this.originName,
    this.destinationName,
  });
  final SpotRepository spots;
  final MobilityPreferences preferences;
  final GlobeController globe;
  final MobilityPoint? origin, destination;
  final String? originName, destinationName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.translate("ÖV-Verbindungen · OJP 2.0"))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PublicTransportSection(
          spots: spots,
          preferences: preferences,
          globe: globe,
          initialOrigin: origin,
          initialDestination: destination,
          initialOriginName: originName,
          initialDestinationName: destinationName,
        ),
      ],
    ),
  );
}
