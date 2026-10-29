import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'offline_map_store.dart';
import 'offline_region.dart';
import 'offline_region_package.dart';
import 'offline_package_files.dart';
import 'swiss_offline_sources.dart';
import 'offline_preparation_screen.dart';
import 'offline_preparation_options.dart';
import 'offline_center_picker.dart';

class OfflineRegionsSection extends StatefulWidget {
  const OfflineRegionsSection({
    super.key,
    this.latitude = 46.8,
    this.longitude = 8.3,
    required this.cachedMaps,
    required this.onCachedMaps,
    this.enabled = true,
    this.storage,
    this.onChanged,
    this.packageFiles = const OfflinePackageFiles(),
    this.sources,
    this.prepareSnapshots,
  });
  final double latitude, longitude;
  final bool cachedMaps, enabled;
  final ValueChanged<bool> onCachedMaps;
  final OfflineMapStorage? storage;
  final ValueChanged<OfflineRegion?>? onChanged;
  final OfflinePackageFiles packageFiles;
  final SwissOfflineSources? sources;
  final Future<String> Function(Set<String>)? prepareSnapshots;
  @override
  State<OfflineRegionsSection> createState() => _OfflineRegionsSectionState();
}

class _OfflineRegionsSectionState extends State<OfflineRegionsSection> {
  late final _store = widget.storage ?? openOfflineMapStore();
  late final _sources = widget.sources ?? SwissOfflineSources();
  Future<void>? _operation;
  String? _notice;
  late final _latitude = TextEditingController(
        text: widget.latitude.toStringAsFixed(5),
      ),
      _longitude = TextEditingController(
        text: widget.longitude.toStringAsFixed(5),
      );
  final _name = TextEditingController(text: 'Offline region');
  List<OfflineRegion> _regions = [];
  List<OfflineTileInfo> _tiles = [];
  double _radius = 1;
  int _detail = 14;
  int _terrainDetail = 16;
  String _style = 'topographic';
  bool _wholeSwitzerland = false, _includeTerrain = true;
  int _budgetGiB = 8;
  final _maps = <String>{'topographic'};
  final _snapshots = <String>{};
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _name.dispose();
    if (widget.sources == null) _sources.dispose();
    if (widget.storage == null) {
      final pending = _operation ?? Future<void>.value();
      pending.catchError((Object _) {}).then((_) => _store.close());
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final regions = await _store.regions(), tiles = await _store.tiles();
      if (mounted) {
        setState(() {
          _regions = regions;
          _tiles = tiles;
          _busy = false;
          _error = _store.rendererReady ? null : 'Reload this Web app online to enable its offline map worker. HTTPS or localhost is required.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Offline storage unavailable. Web requires HTTPS or localhost and browser storage access.';
        });
      }
    }
  }

  OfflineRegion _candidate() {
    final lat = double.parse(_latitude.text.replaceAll(',', '.')),
        lon = double.parse(_longitude.text.replaceAll(',', '.'));
    final dy = _radius / 111.195, dx = dy / math.cos(lat * math.pi / 180);
    return OfflineRegion(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      west: lon - dx,
      east: lon + dx,
      south: lat - dy,
      north: lat + dy,
      style: _style,
      imageryLevel: _detail,
      terrainLevel: _terrainDetail,
    );
  }

  OfflinePreparationOptions _options() => OfflinePreparationOptions(
    latitude: double.parse(_latitude.text.replaceAll(',', '.')),
    longitude: double.parse(_longitude.text.replaceAll(',', '.')),
    radiusKm: _radius,
    name: _name.text.trim(),
    maps: _maps.toList(),
    wholeSwitzerland: kIsWeb && _wholeSwitzerland,
    includeTerrain: _includeTerrain,
    imageryLevel: _detail,
    terrainLevel: _terrainDetail,
    budgetGiB: _budgetGiB,
  );

  Future<void> _pickCenter() async {
    final point = await Navigator.push<({double latitude, double longitude})>(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineCenterPicker(
          latitude: double.tryParse(_latitude.text) ?? widget.latitude,
          longitude: double.tryParse(_longitude.text) ?? widget.longitude,
        ),
      ),
    );
    if (point != null && mounted) {
      setState(() {
        _latitude.text = point.latitude.toStringAsFixed(5);
        _longitude.text = point.longitude.toStringAsFixed(5);
      });
    }
  }

  Future<void> _prepare([OfflineRegion? previous]) => _packageAction(() async {
    final snapshotStatus = _snapshots.isEmpty
        ? ''
        : await widget.prepareSnapshots?.call(_snapshots) ?? '';
    if (!mounted) return;
    final config = previous == null
        ? _options().request()
        : {
            ...OfflinePreparationOptions(
              latitude:
                  previous.centerLatitude ??
                  (previous.north + previous.south) / 2,
              longitude:
                  previous.centerLongitude ??
                  (previous.east + previous.west) / 2,
              radiusKm: previous.radiusKm ?? 1,
              name: previous.name,
              maps: previous.maps ?? [previous.style],
              wholeSwitzerland: previous.scope == 'switzerland',
              includeTerrain: previous.includeTerrain,
              imageryLevel: previous.imageryLevel,
              terrainLevel: previous.terrainLevel,
              budgetGiB: _budgetGiB,
            ).request(),
            'id': previous.id,
          };
    final region = await Navigator.push<OfflineRegion>(
      context,
      MaterialPageRoute(
        builder: (_) => OfflinePreparationScreen(config: config),
      ),
    );
    if (!mounted) {
      return;
    }
    if (region != null) {
      widget.onCachedMaps(true);
      widget.onChanged?.call(region);
      _notice =
          'Offline-Bereich gespeichert. Quellenlücken und fehlende Live-Daten bleiben erkennbar.\n$snapshotStatus';
    } else {
      _notice = 'Aufbereitung unterbrochen. Dieselbe Auswahl setzt vorbereitete Kacheln fort.';
    }
    await _load();
  });

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final region = _candidate();
      await _store.setRegions([..._regions, region]);
      widget.onChanged?.call(region);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Choose valid Swiss coordinates and a smaller area; at most 12 regions / 5,000 tiles per region.';
        });
      }
    }
  }

  Future<void> _packageAction(Future<void> Function() action) {
    if (_busy) return Future.value();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    return _operation = (() async {
      try {
        await action();
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = error is FormatException ? error.message : 'Offline-Paket konnte nicht verarbeitet werden. Vorhandene Daten bleiben erhalten.',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    })();
  }

  Future<void> _exportPlan([OfflineRegion? region]) => _packageAction(() async {
    final plan = await _sources.discover(region ?? _candidate());
    if (!mounted) return;
    final saved = await widget.packageFiles.savePlan(plan);
    if (mounted) {
      setState(
        () => _notice = saved
            ? 'Vorbereitungsdatei gespeichert. Auf dem Laptop mit dem Regionswerkzeug ein .fpvregion-Paket erstellen und hier importieren.'
            : 'Export abgebrochen.',
      );
    }
  });
  Future<void> _importPackage() => _packageAction(() async {
    final target = _store;
    if (target is! PreparedMapStorage) {
      throw const FormatException(
        'Paketimport ist in diesem Speicher nicht verfügbar.',
      );
    }
    final bytes = await widget.packageFiles.pick();
    if (bytes == null || !mounted) return;
    final package = await compute(decodeRegionPackage, bytes);
    if (!mounted) return;
    await (target as PreparedMapStorage).importPackage(package);
    if (!mounted) return;
    widget.onCachedMaps(true);
    widget.onChanged?.call(package.region);
    await _load();
    if (mounted) {
      setState(
        () => _notice = 'Offline-Paket importiert. Karte und Gelände sind für die vorbereitete Region lokal verfügbar; Live-Daten bleiben separat.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    OfflineRegion? estimate;
    ({int tiles, int bytes})? preparationEstimate;
    try {
      estimate = _options().region();
      preparationEstimate = _options().estimate();
    } catch (_) {}
    final size = _tiles.fold<int>(0, (total, t) => total + t.bytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offline map regions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Bereich bis 25 km Radius direkt auf diesem Gerät vorbereiten: Topografie, SWISSIMAGE-Satellitenbilder, neutrales Relief und 3D-Gelände aus offiziellen Downloadquellen. In der Webversion ist auch die gesamte Schweiz wählbar.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.enabled && !_busy && _store.rendererReady
              ? _importPackage
              : null,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Offline-Paket importieren'),
        ),
        const Text(
          'Ein Laptop ist für die Aufbereitung nicht erforderlich. Bereits erstellte .fpvregion-Pakete bis 64 MiB können weiterhin importiert werden. Quellenlücken, Landesgrenzen und der gewählte Detailgrad begrenzen die Abdeckung.',
        ),
        if (_notice != null) Text(_notice!),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use cached base map and terrain'),
          subtitle: const Text(
            'Missing tiles remain unavailable. Live data layers and API actions are separate and may still use the network.',
          ),
          value: widget.cachedMaps,
          onChanged: widget.enabled && !_busy && _store.rendererReady
              ? widget.onCachedMaps
              : null,
        ),
        Text(
          'Gespeicherte Kartendaten: ${(size / 1048576).toStringAsFixed(1)} MiB. Der zusätzliche Puffer für beim Betrachten geladene Kacheln ist auf 256 MiB begrenzt.',
        ),
        const Text(
          '© swisstopo · OGD terms. Retrieval age is not an official publication date. Cached maps do not supply live airspace, traffic or weather information.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextButton.icon(
          onPressed: widget.enabled && !_busy ? _load : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh storage status'),
        ),
        TextButton.icon(
          onPressed: widget.enabled && !_busy
              ? () => _packageAction(() async {
                  await _store.setRegions(_regions);
                  await _load();
                })
              : null,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Unterbrochene Aufbereitung verwerfen'),
        ),
        for (final region in _regions) _region(region),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Add offline region'),
          children: [
            if (kIsWeb)
              SwitchListTile(
                key: const Key('offline-whole-switzerland'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Gesamte Schweiz'),
                subtitle: const Text(
                  'Großer Download. Detail und Ebenen bestimmen den Speicherbedarf; der Browser prüft seinen verfügbaren Speicher vor dem Start.',
                ),
                value: _wholeSwitzerland,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _wholeSwitzerland = value;
                        if (value) {
                          _terrainDetail = 12;
                          _detail = 14;
                        }
                      }),
              ),
            TextField(
              controller: _name,
              enabled: widget.enabled && !_busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Region name'),
            ),
            TextField(
              controller: _latitude,
              enabled: widget.enabled && !_busy && !_wholeSwitzerland,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Centre latitude'),
            ),
            TextField(
              controller: _longitude,
              enabled: widget.enabled && !_busy && !_wholeSwitzerland,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Centre longitude'),
            ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy && !_wholeSwitzerland
                  ? _pickCenter
                  : null,
              icon: const Icon(Icons.public),
              label: const Text('Mittelpunkt auf Globe markieren'),
            ),
            Text('Radius: ${_radius.toStringAsFixed(2)} km'),
            Slider(
              value: _radius,
              min: .25,
              max: 25,
              divisions: 99,
              onChanged: widget.enabled && !_busy && !_wholeSwitzerland
                  ? (v) => setState(() => _radius = v)
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _style,
              decoration: const InputDecoration(labelText: 'Supported map'),
              items: const [
                DropdownMenuItem(
                  value: 'topographic',
                  child: Text('Topographic'),
                ),
                DropdownMenuItem(value: 'relief', child: Text('Relief')),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _style = v!)
                  : null,
            ),
            const Text('Offline verfügbare Kartenebenen'),
            for (final entry in const {
              'topographic': 'Topografische Karte',
              'satellite': 'Satellitenbilder · SWISSIMAGE 2 m',
              'relief': 'Neutrales Relief · für Tag/Nacht-Beleuchtung',
            }.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: _maps.contains(entry.key),
                onChanged: widget.enabled && !_busy
                    ? (value) => setState(() {
                        if (value == true) {
                          _maps.add(entry.key);
                        } else {
                          _maps.remove(entry.key);
                        }
                      })
                    : null,
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('3D-Gelände'),
              value: _includeTerrain,
              subtitle: const Text(
                'Höhen aus swissALTI3D; gewählte Detailstufe bestimmt die Auflösung im Globe.',
              ),
              onChanged: widget.enabled && !_busy
                  ? (value) => setState(() => _includeTerrain = value!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('imagery-$_wholeSwitzerland'),
              initialValue: _detail,
              decoration: const InputDecoration(
                labelText: 'Maximum imagery detail',
              ),
              items: [
                for (final level in [12, 13, 14, 15, 16, 17])
                  DropdownMenuItem(value: level, child: Text('Zoom $level')),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _detail = v!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('terrain-$_wholeSwitzerland'),
              initialValue: _terrainDetail,
              decoration: const InputDecoration(
                labelText: 'Geländedetail für Offline-Paket',
              ),
              items: [
                for (final level in [12, 13, 14, 15, 16])
                  DropdownMenuItem(
                    value: level,
                    child: Text('Stufe $level${level == 16 ? ' · fein' : ''}'),
                  ),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _terrainDetail = v!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _budgetGiB,
              decoration: const InputDecoration(
                labelText: 'Speicherlimit für diesen Download',
              ),
              items: [
                for (final value in [1, 2, 4, 8, 16, 32])
                  DropdownMenuItem(value: value, child: Text('$value GiB')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _budgetGiB = value!),
            ),
            if (preparationEstimate != null)
              Text(
                'Geschätzter lokaler Speicher: ${(preparationEstimate.bytes / 1048576).toStringAsFixed(0)} MiB · ${preparationEstimate.tiles} Kacheln. Originaldaten und Karteninhalt beeinflussen Downloadmenge und Dauer. Vorhandene Region bleibt bis zum erfolgreichen Abschluss aktiv.',
              ),
            FilledButton.icon(
              onPressed:
                  widget.enabled &&
                      !_busy &&
                      _store.rendererReady &&
                      preparationEstimate != null &&
                      preparationEstimate.bytes <=
                          _budgetGiB * 1024 * 1024 * 1024 &&
                      preparationEstimate.tiles <= 2000000
                  ? _prepare
                  : null,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(
                _wholeSwitzerland
                    ? 'Gesamte Schweiz offline vorbereiten'
                    : 'Bereich offline vorbereiten',
              ),
            ),
            const Text(
              'Eigene Spots, Fotos, Ausrüstung, Routen und Checklisten sind bereits lokal. Heruntergeladene UAS-Zonen, Vektorhindernisse und SLF-Bulletins bleiben als datierte Momentaufnahmen verfügbar. Diese Ebenen bei Bedarf vorher in den Kartenebenen aktualisieren. WMS-Bilder, gestreamte Gebäude/Bäume, Verkehr, Flugbewegungen und laufende Wetterdaten werden nicht als vollständige Offline-Datensätze zugesagt.',
            ),
            if (widget.prepareSnapshots != null) ...[
              const Text('Zusätzliche datierte Momentaufnahmen aktualisieren'),
              for (final entry in const {
                'uas': 'UAS-Zonen',
                'obstacles':
                    '3D-Vektorhindernisse · gesamter Schweizer Datensatz',
                'avalanche': 'SLF-Lawinenbulletin · nur bis zur veröffentlichten Gültigkeit',
              }.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: _snapshots.contains(entry.key),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _snapshots.add(entry.key);
                          } else {
                            _snapshots.remove(entry.key);
                          }
                        }),
                ),
            ],
            ExpansionTile(
              title: const Text('Ansichtspuffer und optionaler Laptop-Export'),
              children: [
                if (estimate != null && _style == 'topographic')
                  Text(
                    'Offline-Paket grob ${(estimate.preparedEstimatedBytes / 1048576).toStringAsFixed(1)} MiB (Karteninhalt variiert), maximal 64 MiB. Originaldateien für die Aufbereitung können deutlich größer sein.${estimate.preparedTerrainBytes + 1048576 > regionPackageMaxBytes ? ' Bereich oder Geländedetail reduzieren.' : ''}',
                  ),
                FilledButton.icon(
                  onPressed:
                      widget.enabled &&
                          !_busy &&
                          estimate != null &&
                          !_wholeSwitzerland &&
                          estimate.expectedTiles <= 5000
                      ? _save
                      : null,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Save region for caching'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      widget.enabled &&
                          !_busy &&
                          estimate != null &&
                          estimate.preparedTerrainBytes + 1048576 <=
                              regionPackageMaxBytes &&
                          _style == 'topographic' &&
                          !_wholeSwitzerland &&
                          estimate.expectedTiles <= 5000
                      ? () => _exportPlan()
                      : null,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Vorbereitungsdatei für Laptop speichern'),
                ),
                const Text(
                  'Der zusätzliche Ansichtspuffer enthält nur tatsächlich betrachtete Kacheln und kann unvollständig bleiben. Er ist unabhängig vom automatischen offiziellen Regionsdownload oben.',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _region(OfflineRegion region) {
    final tiles = _tiles.where((t) => region.includesKey(t.key)).toList();
    final size = tiles.fold<int>(0, (n, t) => n + t.bytes);
    final oldest = tiles.isEmpty
        ? null
        : tiles.map((t) => t.fetchedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final stale =
        oldest != null &&
        DateTime.now().toUtc().difference(oldest) > const Duration(days: 30);
    return ListTile(
      leading: region.packageId == null
          ? null
          : IconButton(
              tooltip: 'Paketinformationen',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(region.name),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      '© swisstopo\nAufbereitet: ${region.preparedAt!.toLocal()}\nQuellenausgaben: ${region.sourceDates ?? "unbekannt"}\nKatalog geprüft: ${region.provenance?["sourcePlanRetrievedAtUtc"] ?? "nicht angegeben"}\n\nHöhen: LN02 in Ellipsoidhöhen umgerechnet; ETRS89 als WGS84-Näherung. Gelände und Karten sind auf die Paketgrenzen und gewählte Detailstufen beschränkt.\n\n'
                      '${(region.provenance?["sources"] as List? ?? []).map((s) => "${s['assetId']}\nAusgabe: ${s['sourceTimeUtc']}\nQuellenaktualisierung: ${s['updatedAtUtc'] ?? 'nicht angegeben'}\n${s['url']}").join("\n\n")}',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.enabled && !_busy
                          ? () {
                              Navigator.pop(context);
                              if (region.preparationVersion == 2) {
                                _prepare(region);
                              } else {
                                _exportPlan(region);
                              }
                            }
                          : null,
                      child: Text(
                        region.preparationVersion == 2
                            ? 'Region aktualisieren'
                            : 'Neue Vorbereitungsdatei',
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                  ],
                ),
              ),
            ),
      onTap: widget.enabled && !_busy
          ? () => _packageAction(() async {
              await _store.setRegions(
                _regions
                    .map(
                      (r) => r.withPackageActive(
                        r.id == region.id && r.packageId != null,
                      ),
                    )
                    .toList(),
              );
              if (!mounted) return;
              if (region.packageId != null) widget.onCachedMaps(true);
              widget.onChanged?.call(region);
              await _load();
            })
          : null,
      contentPadding: EdgeInsets.zero,
      title: Text(region.name),
      subtitle: Text(
        '${tiles.length} / ${region.packageTiles ?? region.expectedTiles} tiles · ${(size / 1048576).toStringAsFixed(1)} MiB\n'
        '${region.packageId != null && tiles.length == region.packageTiles ? '${region.packageActive ? 'Aktives Offline-Paket' : 'Offline-Paket'} · abgeleitete Karte und Gelände' : 'Partial cache — missing tiles'} · ${region.style}\n'
        '${region.packageId != null
            ? 'Quellenausgaben: ${region.sourceDates ?? "nicht angegeben"} · ${stale ? "älteres Paket · " : ""}aufbereitet ${region.preparedAt!.toLocal()}'
            : oldest == null
            ? 'Not downloaded'
            : '${stale ? 'Outdated cache' : 'Cached snapshot'} · oldest retrieval ${oldest.toIso8601String()}'}',
      ),
      trailing: IconButton(
        tooltip: 'Remove cached region',
        icon: const Icon(Icons.delete_outline),
        onPressed: widget.enabled && !_busy
            ? () async {
                setState(() => _busy = true);
                try {
                  await _store.setRegions(
                    _regions.where((r) => r.id != region.id).toList(),
                  );
                  widget.onChanged?.call(null);
                  await _load();
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      _busy = false;
                      _error = 'Unable to remove cached region';
                    });
                  }
                }
              }
            : null,
      ),
    );
  }
}
