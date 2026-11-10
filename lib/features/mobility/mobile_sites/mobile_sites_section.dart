import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../globe/globe_controller.dart';
import '../road_routing.dart';
import 'mobile_site_models.dart';
import 'mobile_site_service.dart';
import 'mobile_site_stac.dart';

/// An opt-in, locally bounded BAKOM stations overlay. NEVER an obstruction
/// or field-strength layer: station heights and coverage are unknown.
class MobileSitesSection extends StatefulWidget {
  const MobileSitesSection({
    super.key,
    required this.globe,
    this.initialCenter,
    this.service,
  });
  final GlobeController globe;
  final MobilityPoint? initialCenter;
  final MobileSitesService? service;
  @override
  State<MobileSitesSection> createState() => _MobileSitesSectionState();
}

class _MobileSitesSectionState extends State<MobileSitesSection> {
  // Expansion state and editable scroll offsets must not overwrite the map
  // tab's PageStorageKey with incompatible bool/double values.
  final _formStorage = PageStorageBucket();
  final _lat = TextEditingController(), _lon = TextEditingController();
  MobileSitesService? _owned;
  MobileSitesService get _service =>
      widget.service ?? (_owned ??= MobileSitesService());
  MobileSiteSnapshot? _snapshot;
  MobileSiteCatalog? _catalog;
  int _radius = 2000;
  bool _allow = false, _busy = false, _open = false;
  String? _message;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    final point =
        widget.initialCenter ??
        (widget.globe.selectedPoint == null
            ? null
            : MobilityPoint(
                widget.globe.selectedPoint!.latitude,
                widget.globe.selectedPoint!.longitude,
              ));
    if (point != null) {
      _center(point);
    }
  }

  void _center(MobilityPoint p) {
    _lat.text = '${p.latitude}';
    _lon.text = '${p.longitude}';
    _snapshot = null;
  }

  MobileSiteArea _area() {
    final a = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final b = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
    if (a == null || b == null) {
      throw const FormatException('Enter latitude and longitude.');
    }
    return MobileSiteArea(a, b, _radius);
  }

  Future<void> _load({bool refresh = false, bool offline = false}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final op = ++_operation;
    try {
      final area = _area();
      if (!offline && !_allow) {
        throw const FormatException(
          'Confirm sending the search area to geo.admin.ch.',
        );
      }
      final snapshot = offline
          ? await _service.offline(area)
          : await _service.search(area, refresh: refresh);
      if (!mounted || op != _operation) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        if (snapshot == null) {
          _message = 'No stored area snapshot. This does not prove that no stations exist.';
        }
      });
    } catch (error) {
      if (mounted && op == _operation) {
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'BAKOM query unavailable. No coverage conclusion is possible.',
        );
      }
    } finally {
      if (mounted && op == _operation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _discover() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final op = ++_operation;
    try {
      final metadata = await _service.discover();
      if (mounted && op == _operation) {
        setState(() => _catalog = metadata);
      }
    } catch (_) {
      if (mounted && op == _operation) {
        setState(
          () => _message = 'STAC metadata unavailable; the bounded GeoAdmin station query remains separate.',
        );
      }
    } finally {
      if (mounted && op == _operation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _map() async {
    final snapshot = _snapshot;
    if (snapshot == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // SQLite performs the area/viewport filter, not the Cesium renderer.
      final sites = await _service.store.viewport(
        snapshot.area,
        snapshot.area.wgs84Envelope,
        limit: 180,
      );
      final features = [
        for (final s in sites)
          {
            'id': s.id,
            'name': s.station,
            'detail': '${s.description}\n${snapshot.ageDescription}',
            'geometry': {
              'type': 'Point',
              'coordinates': [s.longitude, s.latitude],
            },
          },
      ];
      await widget.globe.showSituationalOverlay({
        'id': 'mobile-sites',
        'visible': true,
        'features': features,
      });
      if (mounted) {
        if (snapshot.stations.length > 180) {
          setState(
            () => _message =
                'Only 180 sites are shown. Zoom in / select a smaller area.',
          );
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to display BAKOM stations on the globe.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _hide() async {
    try {
      await widget.globe.showSituationalOverlay({
        'id': 'mobile-sites',
        'visible': false,
      });
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to hide the layer.');
      }
    }
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _operation++;
    _lat.dispose();
    _lon.dispose();
    if (_owned != null) {
      unawaited(_owned!.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return PageStorage(
      bucket: _formStorage,
      child: ExpansionTile(
        key: const ValueKey('mobile_sites_expansion'),
        title: const Text('BAKOM Mobilfunk-Basisstationen'),
        subtitle: const Text(
          'Optional · Stationspunkte, keine Masthöhen oder Signalabdeckung',
        ),
        initiallyExpanded: _open,
        onExpansionChanged: (open) => setState(() => _open = open),
        children: [
          const Text(
            'Offizielle BAKOM-Standorte. Stationstyp, Leistungsklasse und Technologie '
            'werden nur nach Quellenangabe angezeigt. Die Koordinaten bezeichnen den ersten '
            'Mast einer Station. Sie sind keine Hindernisgeometrie und messen keine FPV-Abdeckung.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('mobile_sites_lat'),
                  controller: _lat,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  onChanged: (_) => setState(() => _snapshot = null),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('mobile_sites_lon'),
                  controller: _lon,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  onChanged: (_) => setState(() => _snapshot = null),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      final p = widget.globe.selectedPoint;
                      if (p == null) {
                        setState(() => _message = 'No selected 3D map point.');
                      } else {
                        setState(() {
                          _center(MobilityPoint(p.latitude, p.longitude));
                          _message = null;
                        });
                      }
                    },
              icon: const Icon(Icons.place_outlined),
              label: const Text('Ausgewählten Kartenpunkt verwenden'),
            ),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('mobile_sites_radius_$_radius'),
            initialValue: _radius,
            decoration: const InputDecoration(labelText: 'Suchradius'),
            items: [500, 1000, 2000, 5000]
                .map(
                  (n) => DropdownMenuItem(
                    value: n,
                    child: Text(n < 1000 ? '$n m' : '${n ~/ 1000} km'),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (n) => setState(() {
                    _radius = n ?? 2000;
                    _snapshot = null;
                  }),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _allow,
            title: const Text('Suchkoordinaten an geo.admin.ch senden'),
            subtitle: const Text(
              'Nur nach manuellem Start · begrenzte Abfrage, keine nationalen Downloads',
            ),
            onChanged: _busy
                ? null
                : (value) => setState(() => _allow = value ?? false),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('mobile_sites_search'),
                onPressed: _busy || !_allow ? null : () => _load(),
                icon: const Icon(Icons.cell_tower),
                label: const Text('Stationen suchen'),
              ),
              OutlinedButton(
                onPressed: _busy || !_allow ? null : () => _load(refresh: true),
                child: const Text('Aktualisieren'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _load(offline: true),
                child: const Text('Offline-Snapshot'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _discover,
                child: const Text('STAC-Assets prüfen'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (_catalog != null) ...[
            const Divider(),
            Text(
              'STAC-Stand: ${_catalog!.updatedUtc?.toIso8601String() ?? 'unbekannt'}',
            ),
            Text(
              'Lizenz-Metadaten: ${_catalog!.licence} · '
              '${_catalog!.assets.length} Asset-Verweise; davon '
              '${_catalog!.assets.where((a) => a.supported).length} als JSON/CSV klassifiziert.',
            ),
            if (_catalog!.assets.any((asset) => !asset.supported))
              const Text(
                'Nicht unterstützte Datei-Assets (z. B. GeoPackage) werden nicht automatisch importiert.',
              ),
            if (_catalog!.termsUrl != null)
              TextButton(
                onPressed: () => _openUrl(_catalog!.termsUrl.toString()),
                child: const Text('Offizielle Nutzungsbedingungen'),
              ),
          ],
          if (snapshot != null) ...[
            const Divider(),
            Text(
              '${snapshot.stations.length} Stationen · ${snapshot.ageDescription}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (snapshot.fromCache)
              const Text('Gespeicherte Daten · Aktualität nicht live geprüft'),
            if (snapshot.refreshFailed)
              const Text(
                'Aktualisierung fehlgeschlagen: vorhandener Stand bleibt erhalten.',
              ),
            if (snapshot.isOld(DateTime.now()))
              const Text('Datenabruf älter als 24 Stunden.'),
            if (snapshot.truncated)
              const Text(
                'Trefferlimit erreicht: keine vollständige Gebietserfassung. Suchradius verkleinern.',
              ),
            const Text(
              'Keine Treffer bedeuten nicht, dass keine Anlage vorhanden ist.',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _map,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Stationen auf dem 3D-Globus'),
                ),
                if (widget.globe.situationalVisible('mobile-sites'))
                  TextButton(
                    onPressed: _busy ? null : _hide,
                    child: const Text('Stationslayer ausblenden'),
                  ),
              ],
            ),
            for (final site in snapshot.stations.take(50))
              ExpansionTile(
                key: ValueKey('mobile_site_${site.id}'),
                title: Text(site.station),
                subtitle: Text(site.technology ?? 'Technologie unbekannt'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      '${site.description}\n${snapshot.ageDescription}',
                    ),
                  ),
                ],
              ),
          ],
          TextButton.icon(
            onPressed: () => _openUrl(
              'https://www.bakom.admin.ch/de/erlaeuterungen-zur-ubersichtskarte',
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('BAKOM-Erklärungen und amtliche Quelle'),
          ),
          TextButton.icon(
            onPressed: () => _openUrl(
              'https://data.geo.admin.ch/api/stac/v1/collections/$mobileSiteCollectionId',
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Offizielle STAC-Collection'),
          ),
        ],
      ),
    );
  }
}
