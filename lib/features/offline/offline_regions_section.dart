import 'dart:async';
import 'dart:math' as math;

import '../../core/localization/app_localizations.dart';

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
  final FutureOr<void> Function(bool) onCachedMaps;
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
      await widget.onCachedMaps(true);
      if (!mounted) return;
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
    await widget.onCachedMaps(true);
    if (!mounted) return;
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
          context.localized(
            "Offline map regions",
            (l10n) => l10n.offlineOfflineMapRegionse6d5c4de,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          context.localized(
            "Bereich bis 25 km Radius direkt auf diesem Gerät vorbereiten: Topografie, SWISSIMAGE-Satellitenbilder, neutrales Relief und 3D-Gelände aus offiziellen Downloadquellen. In der Webversion ist auch die gesamte Schweiz wählbar.",
            (l10n) => l10n.commonBereichBisKmRadiusfecda995,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.enabled && !_busy && _store.rendererReady
              ? _importPackage
              : null,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(
            context.localized(
              "Offline-Paket importieren",
              (l10n) => l10n.offlineOfflinePaketImportieren3e6d35a5,
            ),
          ),
        ),
        Text(
          context.localized(
            "Ein Laptop ist für die Aufbereitung nicht erforderlich. Bereits erstellte .fpvregion-Pakete bis 64 MiB können weiterhin importiert werden. Quellenlücken, Landesgrenzen und der gewählte Detailgrad begrenzen die Abdeckung.",
            (l10n) => l10n.commonEinLaptopIstFuer32903d0e,
          ),
        ),
        if (_notice != null) Text(_notice!),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Use cached base map and terrain",
              (l10n) => l10n.offlineUseCachedBaseMapcac83b59,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Kein Online-Nachladen für Grundkarte und Gelände, auch nach Neustart. Live-Daten können weiterhin online sein.",
              (l10n) => l10n.commonKeinOnlineNachladenFuer3b0d241a,
            ),
          ),
          value: widget.cachedMaps,
          onChanged: widget.enabled && !_busy && _store.rendererReady
              ? (value) async => widget.onCachedMaps(value)
              : null,
        ),
        Text(
          context.localizedWithArgs(
            "Gespeicherte Kartendaten: {0} MiB. Der zusätzliche Puffer für beim Betrachten geladene Kacheln ist auf 256 MiB begrenzt.",
            [(size / 1048576).toStringAsFixed(1)],
            (l10n, value) =>
                l10n.offlineGespeicherteKartendatenMibDerf8af680d(value(0)),
          ),
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
          label: Text(
            context.localized(
              "Refresh storage status",
              (l10n) => l10n.offlineRefreshStorageStatus889bb274,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: widget.enabled && !_busy
              ? () => _packageAction(() async {
                  await _store.setRegions(_regions);
                  await _load();
                })
              : null,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(
            context.localized(
              "Unterbrochene Aufbereitung verwerfen",
              (l10n) => l10n.offlineUnterbrocheneAufbereitungVerwerfenf0149e36,
            ),
          ),
        ),
        for (final region in _regions) _region(region),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Add offline region",
              (l10n) => l10n.offlineAddOfflineRegion6d71cdd8,
            ),
          ),
          children: [
            if (kIsWeb)
              SwitchListTile(
                key: const Key('offline-whole-switzerland'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.localized(
                    "Gesamte Schweiz",
                    (l10n) => l10n.offlineGesamteSchweiz533dc2ed,
                  ),
                ),
                subtitle: Text(
                  context.localized(
                    "Großer Download. Detail und Ebenen bestimmen den Speicherbedarf; der Browser prüft seinen verfügbaren Speicher vor dem Start.",
                    (l10n) => l10n.offlineGrosserDownloadDetailUnd759ef111,
                  ),
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
              decoration: InputDecoration(
                labelText: context.localized(
                  "Centre latitude",
                  (l10n) => l10n.offlineCentreLatitudea76075f4,
                ),
              ),
            ),
            TextField(
              controller: _longitude,
              enabled: widget.enabled && !_busy && !_wholeSwitzerland,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.localized(
                  "Centre longitude",
                  (l10n) => l10n.offlineCentreLongitude1cbc4661,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy && !_wholeSwitzerland
                  ? _pickCenter
                  : null,
              icon: const Icon(Icons.public),
              label: Text(
                context.localized(
                  "Mittelpunkt auf Globe markieren",
                  (l10n) => l10n.offlineMittelpunktAufGlobeMarkierenec84f922,
                ),
              ),
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
              decoration: InputDecoration(
                labelText: context.localized(
                  "Supported map",
                  (l10n) => l10n.offlineSupportedMapb531fbb7,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'topographic',
                  child: Text(
                    context.localized(
                      "Topographic",
                      (l10n) => l10n.offlineTopographicd28af3fe,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'relief',
                  child: Text(
                    context.localized(
                      "Relief",
                      (l10n) => l10n.commonReliefbe53bb74,
                    ),
                  ),
                ),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _style = v!)
                  : null,
            ),
            Text(
              context.localized(
                "Offline verfügbare Kartenebenen",
                (l10n) => l10n.offlineOfflineVerfuegbareKartenebenen3eca4f37,
              ),
            ),
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
              title: Text(
                context.localized(
                  "3D-Gelände",
                  (l10n) => l10n.offlineDGelaende41d0aed9,
                ),
              ),
              value: _includeTerrain,
              subtitle: Text(
                context.localized(
                  "Höhen aus swissALTI3D; gewählte Detailstufe bestimmt die Auflösung im Globe.",
                  (l10n) => l10n.offlineHoehenAusSwissaltiD5966fff3,
                ),
              ),
              onChanged: widget.enabled && !_busy
                  ? (value) => setState(() => _includeTerrain = value!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('imagery-$_wholeSwitzerland'),
              initialValue: _detail,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Maximum imagery detail",
                  (l10n) => l10n.offlineMaximumImageryDetaile83a21f6,
                ),
              ),
              items: [
                for (final level in [12, 13, 14, 15, 16, 17])
                  DropdownMenuItem(
                    value: level,
                    child: Text(
                      context.localizedWithArgs("Zoom {0}", [
                        level,
                      ], (l10n, value) => l10n.offlineZoomb67baf86(value(0))),
                    ),
                  ),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _detail = v!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('terrain-$_wholeSwitzerland'),
              initialValue: _terrainDetail,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Geländedetail für Offline-Paket",
                  (l10n) => l10n.offlineGelaendedetailFuerOfflinePaketcbde183b,
                ),
              ),
              items: [
                for (final level in [12, 13, 14, 15, 16])
                  DropdownMenuItem(
                    value: level,
                    child: Text(
                      context.localizedWithArgs(
                        "Stufe {0}{1}",
                        [level, level == 16 ? ' · fein' : ''],
                        (l10n, value) =>
                            l10n.offlineStufed0ed7705(value(0), value(1)),
                      ),
                    ),
                  ),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _terrainDetail = v!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _budgetGiB,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Speicherlimit für diesen Download",
                  (l10n) => l10n.offlineSpeicherlimitFuerDiesenDownload142a1d01,
                ),
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
                context.localizedWithArgs(
                  "Geschätzter lokaler Speicher: {0} MiB · {1} Kacheln. Originaldaten und Karteninhalt beeinflussen Downloadmenge und Dauer. Vorhandene Region bleibt bis zum erfolgreichen Abschluss aktiv.",
                  [
                    (preparationEstimate.bytes / 1048576).toStringAsFixed(0),
                    preparationEstimate.tiles,
                  ],
                  (l10n, value) =>
                      l10n.offlineGeschaetzterLokalerSpeicherMibae938fa8(
                        value(0),
                        value(1),
                      ),
                ),
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
                    ? context.localized(
                        "Gesamte Schweiz offline vorbereiten",
                        (l10n) => l10n
                            .offlineGesamteSchweizOfflineVorbereiten7cb30202,
                      )
                    : context.localized(
                        "Bereich offline vorbereiten",
                        (l10n) => l10n.offlineBereichOfflineVorbereiten91421709,
                      ),
              ),
            ),
            Text(
              context.localized(
                "Eigene Spots, Fotos, Ausrüstung, Routen und Checklisten sind bereits lokal. Heruntergeladene UAS-Zonen, Vektorhindernisse und SLF-Bulletins bleiben als datierte Momentaufnahmen verfügbar. Diese Ebenen bei Bedarf vorher in den Kartenebenen aktualisieren. WMS-Bilder, gestreamte Gebäude/Bäume, Verkehr, Flugbewegungen und laufende Wetterdaten werden nicht als vollständige Offline-Datensätze zugesagt.",
                (l10n) => l10n.commonEigeneSpotsFotosAusruestunga83357cb,
              ),
            ),
            if (widget.prepareSnapshots != null) ...[
              Text(
                context.localized(
                  "Zusätzliche datierte Momentaufnahmen aktualisieren",
                  (l10n) => l10n
                      .offlineZusaetzlicheDatierteMomentaufnahmenAktualisieren66eddff9,
                ),
              ),
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
              title: Text(
                context.localized(
                  "Ansichtspuffer und optionaler Laptop-Export",
                  (l10n) =>
                      l10n.offlineAnsichtspufferUndOptionalerLaptop62f2efd5,
                ),
              ),
              children: [
                if (estimate != null && _style == 'topographic')
                  Text(
                    context.localizedWithArgs(
                      "Offline-Paket grob {0} MiB (Karteninhalt variiert), maximal 64 MiB. Originaldateien für die Aufbereitung können deutlich größer sein.{1}",
                      [
                        (estimate.preparedEstimatedBytes / 1048576)
                            .toStringAsFixed(1),
                        estimate.preparedTerrainBytes + 1048576 >
                                regionPackageMaxBytes
                            ? ' Bereich oder Geländedetail reduzieren.'
                            : '',
                      ],
                      (l10n, value) => l10n.commonOfflinePaketGrobMibeae634d2(
                        value(0),
                        value(1),
                      ),
                    ),
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
                  label: Text(
                    context.localized(
                      "Save region for caching",
                      (l10n) => l10n.offlineSaveRegionForCaching87de5600,
                    ),
                  ),
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
                  label: Text(
                    context.localized(
                      "Vorbereitungsdatei für Laptop speichern",
                      (l10n) => l10n
                          .offlineVorbereitungsdateiFuerLaptopSpeichern42dca4b8,
                    ),
                  ),
                ),
                Text(
                  context.localized(
                    "Der zusätzliche Ansichtspuffer enthält nur tatsächlich betrachtete Kacheln und kann unvollständig bleiben. Er ist unabhängig vom automatischen offiziellen Regionsdownload oben.",
                    (l10n) => l10n
                        .offlineDerZusaetzlicheAnsichtspufferEnthaeltb23a8c6c,
                  ),
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
                            ? context.localized(
                                "Region aktualisieren",
                                (l10n) =>
                                    l10n.offlineRegionAktualisieren789dbcf6,
                              )
                            : context.localized(
                                "Neue Vorbereitungsdatei",
                                (l10n) =>
                                    l10n.offlineNeueVorbereitungsdateif618c1fc,
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.localized(
                          "Schließen",
                          (l10n) => l10n.commonSchliessen44424b18,
                        ),
                      ),
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
              if (region.packageId != null) await widget.onCachedMaps(true);
              if (!mounted) return;
              widget.onChanged?.call(region);
              await _load();
            })
          : null,
      contentPadding: EdgeInsets.zero,
      title: Text(region.name),
      subtitle: Text(
        context.localizedWithArgs(
          "{0} / {1} tiles · {2} MiB\n{3} · {4}\n{5}",
          [
            tiles.length,
            region.packageTiles ?? region.expectedTiles,
            (size / 1048576).toStringAsFixed(1),
            region.packageId != null && tiles.length == region.packageTiles
                ? '${region.packageActive ? 'Aktives Offline-Paket' : 'Offline-Paket'} · abgeleitete Karte und Gelände'
                : 'Partial cache — missing tiles',
            region.style,
            region.packageId != null
                ? 'Quellenausgaben: ${region.sourceDates ?? "nicht angegeben"} · ${stale ? "älteres Paket · " : ""}aufbereitet ${region.preparedAt!.toLocal()}'
                : oldest == null
                ? 'Not downloaded'
                : '${stale ? 'Outdated cache' : 'Cached snapshot'} · oldest retrieval ${oldest.toIso8601String()}',
          ],
          (l10n, value) => l10n.offlineTilesMib2f032565(
            value(0),
            value(1),
            value(2),
            value(3),
            value(4),
            value(5),
          ),
        ),
      ),
      trailing: IconButton(
        tooltip: context.localized(
          "Remove cached region",
          (l10n) => l10n.offlineRemoveCachedRegion3fb1230e,
        ),
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
