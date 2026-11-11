import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/fpv_database.dart' show Spot;
import '../../globe/globe_controller.dart';
import '../../spots/data/spot_location_service.dart';
import '../../spots/data/spot_repository.dart';
import '../road_routing.dart';
import 'shared_mobility_models.dart';
import 'shared_mobility_service.dart';

String sharedMobilityStatusLabel(SharedMobilityStatus status) =>
    switch (status) {
      SharedMobilityStatus.available => 'Gemeldet verfügbar (Quelle aktuell)',
      SharedMobilityStatus.reserved => 'Reserviert',
      SharedMobilityStatus.disabled => 'Deaktiviert',
      SharedMobilityStatus.unavailable => 'Nicht verfügbar',
      SharedMobilityStatus.unknown => 'Aktueller Status unbekannt',
    };

class SharedMobilitySection extends StatefulWidget {
  const SharedMobilitySection({
    super.key,
    required this.spots,
    required this.globe,
    this.initialSpotId,
    this.initialMapPoint,
    this.service,
  });
  final SpotRepository spots;
  final GlobeController globe;
  final int? initialSpotId;
  final MobilityPoint? initialMapPoint;
  final SharedMobilityService? service;

  @override
  State<SharedMobilitySection> createState() => _SharedMobilitySectionState();
}

class _SharedMobilitySectionState extends State<SharedMobilitySection> {
  final _lat = TextEditingController(), _lon = TextEditingController();
  late final Future<List<Spot>> _spots = widget.spots.getAllSpots();
  late final SharedMobilityService _service =
      widget.service ?? SharedMobilityService();
  SharedMobilitySnapshot? _result;
  int _radius = 500;
  int? _spotId;
  String _provider = 'all', _type = 'all', _pickup = 'all';
  bool _consent = false, _working = false;
  String? _message;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _spotId = widget.initialMapPoint == null ? widget.initialSpotId : null;
    if (widget.initialMapPoint != null) {
      _setPoint(widget.initialMapPoint!);
    } else {
      unawaited(_startWithSpot());
    }
  }

  @override
  void didUpdateWidget(covariant SharedMobilitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = widget.initialMapPoint;
    final previous = oldWidget.initialMapPoint;
    if (latest != null &&
        (previous == null ||
            previous.latitude != latest.latitude ||
            previous.longitude != latest.longitude)) {
      _spotId = null;
      _setPoint(latest);
    }
  }

  Future<void> _startWithSpot() async {
    try {
      final spots = await _spots;
      if (!mounted || spots.isEmpty || _lat.text.isNotEmpty) {
        return;
      }
      final selected =
          spots.where((s) => s.id == widget.initialSpotId).firstOrNull ??
          spots.first;
      setState(() {
        _spotId = selected.id;
        _setPoint(MobilityPoint(selected.latitude, selected.longitude));
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Spots konnten nicht geladen werden. Koordinaten eingeben.',
        );
      }
    }
  }

  void _setPoint(MobilityPoint point) {
    _lat.text = '${point.latitude}';
    _lon.text = '${point.longitude}';
    _result = null;
    _provider = 'all';
    _type = 'all';
  }

  SharedMobilityArea _area() {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null) {
      throw const FormatException('Bitte gültige Suchkoordinaten eingeben.');
    }
    return SharedMobilityArea(
      latitude: lat,
      longitude: lon,
      radiusMeters: _radius,
    );
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (_working) {
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'Sharing-Daten konnten nicht geladen werden.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _load({bool refresh = false, bool offline = false}) =>
      _execute(() async {
        final area = _area();
        if (!offline && !_consent) {
          throw const FormatException(
            'Standortabfrage beim Anbieter zuerst bestätigen.',
          );
        }
        final generation = ++_generation;
        final loaded = offline
            ? await _service.offline(area)
            : await _service.search(area, refresh: refresh);
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          _result = loaded;
          _provider = 'all';
          _type = 'all';
          _message = loaded == null
              ? 'Kein gespeicherter Snapshot für diese Suchfläche.'
              : null;
        });
      });

  Future<void> _deviceLocation() => _execute(() async {
    final location = await const SpotLocationService().currentLocation();
    if (mounted) {
      setState(() {
        _spotId = null;
        _setPoint(
          MobilityPoint(
            location.position.latitude,
            location.position.longitude,
          ),
        );
      });
    }
  });

  Future<void> _selectedMapPoint() => _execute(() async {
    final point = widget.globe.selectedPoint;
    if (point == null) {
      throw const FormatException('Erst einen Punkt im Globus auswählen.');
    }
    if (mounted) {
      setState(() {
        _spotId = null;
        _setPoint(MobilityPoint(point.latitude, point.longitude));
      });
    }
  });

  List<SharedMobilityOffer> _filtered(SharedMobilitySnapshot snapshot) => [
    for (final offer in snapshot.offers)
      if ((_provider == 'all' || offer.providerId == _provider) &&
          (_pickup == 'all' || offer.pickup.name == _pickup) &&
          (_type == 'all' || offer.vehicleTypes.contains(_type)))
        offer,
  ];

  String _details(SharedMobilityOffer offer, SharedMobilitySnapshot snapshot) {
    final status = snapshot.status(offer, DateTime.now().toUtc());
    return [
      offer.providerName,
      'Quelle-ID: ${offer.id}',
      offer.pickup == SharedMobilityPickup.stationBased
          ? 'Stationsgebunden'
          : offer.pickup == SharedMobilityPickup.freeFloating
          ? 'Free-Floating'
          : 'Systemart unbekannt',
      if (offer.vehicleTypes.isNotEmpty) offer.vehicleTypes.join(', '),
      if (offer.availableCount != null)
        'Anzahl laut Quelle: ${offer.availableCount}',
      'Aktuell: ${sharedMobilityStatusLabel(status)}',
      'Gemeldeter Zustand: ${offer.reportedStatus.name}',
      'Abfrage: ${snapshot.fetchedUtc.toIso8601String()} UTC',
      'Quellendatum: ${offer.updatedUtc?.toIso8601String() ?? snapshot.feedUpdatedUtc?.toIso8601String() ?? 'unbekannt'}',
      if (snapshot.refreshFailed) 'Aktualisierung fehlgeschlagen',
      'Quelle: BFE / sharedmobility.ch · kein Anspruch auf Verfügbarkeit',
    ].join('\n');
  }

  String _boundedDetails(
    SharedMobilityOffer offer,
    SharedMobilitySnapshot snapshot,
  ) {
    final detail = _details(offer, snapshot);
    return detail.length > 1100 ? detail.substring(0, 1100) : detail;
  }

  Future<void> _showMap() => _execute(() async {
    final result = _result;
    if (result == null) {
      return;
    }
    final listed = _filtered(result).take(120).toList();
    await widget.globe.showSituationalOverlay({
      'id': 'shared-mobility',
      'visible': true,
      'features': [
        for (final offer in listed)
          {
            'id': 'sharing-${offer.id}',
            'name': (offer.name ?? offer.providerName).length > 180
                ? (offer.name ?? offer.providerName).substring(0, 180)
                : offer.name ?? offer.providerName,
            'detail': _boundedDetails(offer, result),
            'geometry': {
              'type': 'Point',
              'coordinates': [offer.longitude, offer.latitude],
            },
          },
      ],
    });
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  });

  Future<void> _openOperator(String? url) async {
    if (url == null) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(
          () => _message = 'Anbieter-Link konnte nicht geöffnet werden.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Anbieter-Link konnte nicht geöffnet werden.',
        );
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _lat.dispose();
    _lon.dispose();
    if (widget.service == null) {
      unawaited(_service.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final providers = <String, String>{
      for (final offer in result?.offers ?? <SharedMobilityOffer>[])
        offer.providerId: offer.providerName,
    };
    final types = <String>{
      for (final offer in result?.offers ?? <SharedMobilityOffer>[])
        ...offer.vehicleTypes,
    }.toList()..sort();
    final displayed = result == null
        ? <SharedMobilityOffer>[]
        : _filtered(result);
    final now = DateTime.now().toUtc();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.translate(
            "Shared Mobility (BFE / sharedmobility.ch). Punktuelle REST-Abfrage, ohne automatische Standortüberwachung oder Reservierung.",
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Spot>>(
          future: _spots,
          builder: (context, state) => DropdownButtonFormField<int>(
            key: ValueKey('sharing_spot_${_spotId ?? 'none'}'),
            initialValue: state.data?.any((s) => s.id == _spotId) == true
                ? _spotId
                : null,
            decoration: InputDecoration(
              labelText: context.translate("Gespeicherter Spot (optional)"),
            ),
            items: [
              for (final spot in state.data ?? <Spot>[])
                DropdownMenuItem(
                  value: spot.id,
                  child: Text(spot.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            isExpanded: true,
            onChanged: _working
                ? null
                : (id) {
                    final spot = state.data
                        ?.where((s) => s.id == id)
                        .firstOrNull;
                    if (spot != null) {
                      setState(() {
                        _spotId = id;
                        _setPoint(MobilityPoint(spot.latitude, spot.longitude));
                      });
                    }
                  },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('sharing_lat'),
                controller: _lat,
                enabled: !_working,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.translate("Latitude"),
                ),
                onChanged: (_) => setState(() {
                  _spotId = null;
                  _result = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('sharing_lon'),
                controller: _lon,
                enabled: !_working,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.translate("Longitude"),
                ),
                onChanged: (_) => setState(() {
                  _spotId = null;
                  _result = null;
                }),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _working ? null : _deviceLocation,
              icon: const Icon(Icons.my_location),
              label: Text(context.translate("Mein Standort")),
            ),
            OutlinedButton.icon(
              onPressed: _working ? null : _selectedMapPoint,
              icon: const Icon(Icons.map_outlined),
              label: Text(context.translate("Kartenpunkt")),
            ),
          ],
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('sharing_radius_$_radius'),
          initialValue: _radius,
          decoration: InputDecoration(
            labelText: context.translate("Suchradius"),
          ),
          items: [200, 500, 1000, 2000]
              .map(
                (radius) =>
                    DropdownMenuItem(value: radius, child: Text('$radius m')),
              )
              .toList(),
          onChanged: _working
              ? null
              : (value) => setState(() {
                  _radius = value ?? 500;
                  _result = null;
                }),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
          title: Text(
            context.translate(
              "Suchkoordinaten für eine Abfrage an sharedmobility.ch senden",
            ),
          ),
          subtitle: Text(
            context.translate(
              "Keine Kontakt-E-Mail nötig: REST-v1-Schnittstelle ohne Login.",
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _working || !_consent ? null : () => _load(),
              icon: const Icon(Icons.pedal_bike),
              label: Text(context.translate("Sharing-Angebote suchen")),
            ),
            OutlinedButton(
              onPressed: _working || !_consent
                  ? null
                  : () => _load(refresh: true),
              child: Text(context.translate("Aktualisieren")),
            ),
            OutlinedButton(
              onPressed: _working ? null : () => _load(offline: true),
              child: const Text('Offline-Snapshot'),
            ),
          ],
        ),
        if (_working) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (kIsWeb)
          Text(
            context.translate(
              "Web: CORS nicht verifiziert. Bei Browser-Sperre ist ein eigener Proxy erforderlich; keiner eingerichtet.",
            ),
          ),
        if (result != null) ...[
          const Divider(),
          Text(
            context.translate("{0} Einträge · Stand {1} · {2}{3}", [
              result.offers.length,
              result.fetchedUtc.toLocal(),
              result.sourceVersion,
              result.fromCache ? ' (Cache)' : '',
            ]),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (result.refreshFailed)
            Text(
              context.translate(
                "Aktualisierung fehlgeschlagen: gespeicherte Daten, aktueller Status unbekannt.",
              ),
            ),
          if (result.isOld(now))
            Text(
              context.translate(
                "Standortdaten älter als fünf Minuten; nicht live.",
              ),
            ),
          if (result.feedUpdatedUtc == null || result.maxAge == null)
            Text(
              context.translate(
                "Veröffentlichungszeit/TTL nicht belegt. Gemeldete Zustände werden angezeigt, aktuelle Verfügbarkeit bleibt unbekannt.",
              ),
            ),
          if (result.truncated)
            Text(
              context.translate(
                "Ergebnis begrenzt; kleinere Suchfläche wählen. Keine vollständige Abdeckung.",
              ),
            ),
          Text(
            context.translate(
              "Nicht alle Anbieter liefern Daten. Fehlende Treffer bedeuten keine vollständige Abdeckung.",
            ),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('sharing_provider_$_provider'),
            initialValue: _provider,
            decoration: InputDecoration(
              labelText: context.translate("Anbieter"),
            ),
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(context.translate("Alle Anbieter")),
              ),
              for (final entry in providers.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _provider = value ?? 'all'),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('sharing_type_$_type'),
            initialValue: _type,
            decoration: InputDecoration(
              labelText: context.translate("Fahrzeugtyp"),
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(context.translate("Alle Fahrzeugtypen")),
              ),
              for (final type in types)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'all'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _pickup,
            decoration: InputDecoration(
              labelText: context.translate("Angebotsart"),
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(context.translate("Alle Angebote")),
              ),
              DropdownMenuItem(
                value: 'stationBased',
                child: Text(context.translate("Stationen")),
              ),
              DropdownMenuItem(
                value: 'freeFloating',
                child: Text(context.translate("Free-Floating")),
              ),
            ],
            onChanged: (value) => setState(() => _pickup = value ?? 'all'),
          ),
          OutlinedButton.icon(
            onPressed: _working || displayed.isEmpty ? null : _showMap,
            icon: const Icon(Icons.map),
            label: Text(context.translate("Auf 3D-Karte zeigen (max. 120)")),
          ),
          Text(
            context.translate("{0} Treffer nach Filter", [displayed.length]),
          ),
          for (final offer in displayed.take(60))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name ?? offer.providerName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${offer.providerName} · ${offer.pickup == SharedMobilityPickup.stationBased
                          ? 'Station'
                          : offer.pickup == SharedMobilityPickup.freeFloating
                          ? 'Free-Floating'
                          : 'Typ unbekannt'}',
                    ),
                    if (offer.vehicleTypes.isNotEmpty)
                      Text(offer.vehicleTypes.join(', ')),
                    if (offer.availableCount != null)
                      Text(
                        context.translate("Fahrzeuge laut Anbieter: {0}", [
                          offer.availableCount,
                        ]),
                      ),
                    Text(sharedMobilityStatusLabel(result.status(offer, now))),
                    Text(
                      context.translate("Quellenmeldung: {0}", [
                        sharedMobilityStatusLabel(offer.reportedStatus),
                      ]),
                    ),
                    Text(
                      context.translate("Veröffentlicht: {0}", [
                        offer.updatedUtc?.toLocal().toString() ??
                            result.feedUpdatedUtc?.toLocal().toString() ??
                            'unbekannt',
                      ]),
                    ),
                    Text(
                      context.translate("Referenz: {0}", [offer.id]),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (offer.operatorUrl != null)
                      TextButton.icon(
                        onPressed: () => _openOperator(offer.operatorUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          context.translate(
                            "Anbieter öffnen (keine Reservierung)",
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (displayed.length > 60)
            Text(
              context.translate(
                "Liste auf 60 Einträge begrenzt. Filter oder Radius anpassen.",
              ),
            ),
        ],
        const Divider(),
        Text(
          context.translate(
            "Quelle: Bundesamt für Energie (BFE), sharedmobility.ch – Standorte und Verfügbarkeit von Shared-Mobility-Angeboten. Daten können verzögert oder unvollständig sein. Keine Buchung oder Reservierung.",
          ),
        ),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://github.com/SFOE/sharedmobility/blob/main/Access%20the%20data.md',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text(context.translate("Quelle und Nutzungsbedingungen")),
        ),
      ],
    );
  }
}
