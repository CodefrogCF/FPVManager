import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../globe/globe_controller.dart';
import '../road_routing.dart';
import 'dated_imagery_models.dart';
import 'dated_imagery_service.dart';

/// STAC discovery is exclusively user-initiated. Date-labelled imagery is
/// additional to (not a replacement for) the existing globe basemap.
class DatedImagerySection extends StatefulWidget {
  const DatedImagerySection({
    super.key,
    required this.globe,
    this.initialCenter,
    this.service,
  });
  final GlobeController globe;
  final MobilityPoint? initialCenter;
  final DatedImageryService? service;

  @override
  State<DatedImagerySection> createState() => _DatedImagerySectionState();
}

class _DatedImagerySectionState extends State<DatedImagerySection> {
  late final _lat = TextEditingController(
    text: widget.initialCenter == null
        ? ''
        : '${widget.initialCenter!.latitude}',
  );
  late final _lon = TextEditingController(
    text: widget.initialCenter == null
        ? ''
        : '${widget.initialCenter!.longitude}',
  );
  DatedImageryProduct _product = DatedImageryProduct.swissEo;
  int _radius = 2000;
  bool _expanded = false, _busy = false;
  String? _message;
  DatedImagerySnapshot? _snapshot;
  DatedImageryService? _ownedService;
  int _generation = 0;

  DatedImageryService get _service =>
      widget.service ?? (_ownedService ??= DatedImageryService());

  Future<void> _fetch({bool offline = false, bool refresh = false}) async {
    if (_busy) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      DatedImagerySnapshot? result;
      if (offline) {
        result = await _service.offline(_product);
      } else {
        final latitude = double.tryParse(_lat.text.replaceAll(',', '.').trim());
        final longitude = double.tryParse(
          _lon.text.replaceAll(',', '.').trim(),
        );
        if (latitude == null || longitude == null) {
          throw const FormatException('Latitude und Longitude eingeben.');
        }
        result = await _service.search(
          product: _product,
          latitude: latitude,
          longitude: longitude,
          radiusMetres: _radius,
          refresh: refresh,
        );
      }
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _snapshot = result;
        if (result == null) {
          _message = 'Kein gespeicherter Katalogstand vorhanden.';
        }
        if (result != null && result.items.isEmpty) {
          _message =
              'Keine Einträge in dieser begrenzten Abfrage. '
              'Das ist kein Nachweis vollständiger Abdeckung.';
        }
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _message = 'Katalogabfrage fehlgeschlagen: $error');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _display(DatedImageryItem item) async {
    final asset = item.displayAsset;
    if (asset == null || _snapshot == null) {
      return;
    }
    setState(() {
      _message = null;
    });
    try {
      await widget.globe.showDatedImagery({
        'type': 'set-dated-imagery',
        'visible': true,
        'id': item.id,
        'product': item.product.collection,
        'acquiredUtc': item.acquiredUtc.toUtc().toIso8601String(),
        'bbox': item.bbox,
        'opacity': 0.75,
        'mode': asset.renderKind == DatedImageryRenderKind.swissEoWms
            ? 'swiss-eo-wms'
            : 'rapid-cog',
        if (asset.renderKind == DatedImageryRenderKind.rapidCog) ...{
          'assetUrl': asset.href,
          'projection': asset.projection,
          'searchBounds': _snapshot!.area,
        },
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Bild nicht darstellbar: $error');
      }
    }
  }

  Future<void> _hide() async {
    try {
      await widget.globe.clearDatedImagery();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Bildebene konnte nicht entfernt werden.');
      }
    }
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https') {
        throw const FormatException('Unsafe link');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Link could not be opened');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Offizieller Link konnte nicht geöffnet werden.',
        );
      }
    }
  }

  String _date(DateTime? date) =>
      date == null ? 'nicht veröffentlicht' : date.toUtc().toIso8601String();

  Widget _record(DatedImageryItem item) {
    final asset = item.displayAsset;
    final outside =
        item.product == DatedImageryProduct.rapidMapping && asset == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleSmall),
            Text('Produkt: ${item.product.label} · ${item.id}'),
            Text('Aufnahme (UTC): ${_date(item.acquiredUtc)}'),
            Text('Veröffentlicht: ${_date(item.publishedUtc)}'),
            if (item.missionContext != null)
              Text('Ereignis / Einsatz: ${item.missionContext}'),
            Text(
              'Abdeckung (WGS84): ${item.bbox.map((x) => x.toStringAsFixed(4)).join(', ')}',
            ),
            Text(
              item.cloudCoverPercent == null
                  ? 'Wolkenanteil: nicht angegeben'
                  : 'Wolkenanteil gemäss Quelle: ${item.cloudCoverPercent!.toStringAsFixed(1)} %',
            ),
            Text(
              item.qualityAssetAvailable
                  ? 'Qualitäts-/Wolkenmaske als eigenes Datenasset vorhanden; nicht automatisch als wolkenfrei interpretiert.'
                  : 'Keine überprüfte Qualitätsmaske – Wolken und Bildlücken können vorhanden sein.',
            ),
            if (outside)
              const Text(
                'Für dieses Einsatzprodukt ist kein georeferenzierter, begrenzt lesbarer '
                'RGB-GeoTIFF mit bestätigter Projektion hinterlegt. Kein Kartenbild erfunden.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (asset != null)
                  FilledButton.tonalIcon(
                    key: ValueKey('dated_show_${item.id}'),
                    onPressed: _busy ? null : () => _display(item),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Datierte Aufnahme anzeigen'),
                  ),
                TextButton.icon(
                  onPressed: () => _open(
                    item.viewerUrl ??
                        (item.product == DatedImageryProduct.swissEo
                            ? 'https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-s2-sr'
                            : 'https://www.swisstopo.admin.ch/en/service-rapid-mapping'),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Amtliche Quelle / Ansicht'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ++_generation;
    _lat.dispose();
    _lon.dispose();
    if (_ownedService != null) {
      unawaited(_ownedService!.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.globe,
    builder: (context, _) => ExpansionTile(
      key: const ValueKey('dated_imagery_section'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: _expanded,
      onExpansionChanged: (value) => setState(() => _expanded = value),
      title: const Text('Datierte Satelliten- & Rapid-Mapping-Bilder'),
      subtitle: const Text(
        'swissEO Sentinel-2 v200 / amtliche Ereignisaufnahmen · optional',
      ),
      children: [
        const Text(
          'Ausgewählte Aufnahmen sind historische bzw. verzögert '
          'veröffentlichte Bilddaten. Keine Live-Beobachtung. '
          'Es werden nur kleine STAC-Metadaten gespeichert, keine Rohbilddateien. '
          'Wolken, Schatten und fehlende Bilddeckung sind keine leeren Flächen.',
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<DatedImageryProduct>(
          key: const ValueKey('dated_imagery_product'),
          initialValue: _product,
          decoration: const InputDecoration(labelText: 'Amtliche Collection'),
          items: [
            for (final product in DatedImageryProduct.values)
              DropdownMenuItem(value: product, child: Text(product.label)),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _product = value;
                    _snapshot = null;
                    _message = null;
                  });
                },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('dated_lat'),
                controller: _lat,
                decoration: const InputDecoration(labelText: 'Breite (WGS84)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('dated_lon'),
                controller: _lon,
                decoration: const InputDecoration(labelText: 'Länge (WGS84)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<int>(
          key: const ValueKey('dated_imagery_radius'),
          initialValue: _radius,
          decoration: const InputDecoration(labelText: 'Suchradius'),
          items: [
            for (final r in [500, 1000, 2000, 5000])
              DropdownMenuItem(value: r, child: Text('$r m')),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _radius = value);
                  }
                },
        ),
        if (_busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              key: const ValueKey('dated_imagery_search'),
              onPressed: _busy ? null : () => _fetch(refresh: true),
              child: const Text('Datierte Bilder suchen'),
            ),
            OutlinedButton(
              key: const ValueKey('dated_imagery_offline'),
              onPressed: _busy ? null : () => _fetch(offline: true),
              child: const Text('Letzten Katalogstand öffnen'),
            ),
            if (widget.globe.datedImageryVisible)
              TextButton.icon(
                key: const ValueKey('dated_imagery_restore'),
                onPressed: _hide,
                icon: const Icon(Icons.layers_clear),
                label: const Text('Bildebene entfernen / Basiskarte'),
              ),
          ],
        ),
        Text(
          'Bildlayer: ${widget.globe.datedImageryStatus}'
          '${widget.globe.datedImageryItemId == null ? '' : ' · ${widget.globe.datedImageryItemId}'}',
        ),
        if (widget.globe.datedImageryError != null)
          Text('Darstellungsfehler: ${widget.globe.datedImageryError}'),
        if (_message != null) Text(_message!),
        if (_snapshot case final snapshot?) ...[
          Text(
            'STAC abgefragt: ${_date(snapshot.fetchedUtc)} · '
            '${snapshot.items.length} Treffer in begrenzter Stichprobe',
          ),
          if (snapshot.fromCache)
            const Text('Offline-/Cache-Katalog – keine Live-Bestätigung.'),
          if (snapshot.isOld(DateTime.now()))
            const Text('Metadaten älter als 24 h / Uhrzeit unplausibel.'),
          if (snapshot.refreshFailed)
            const Text(
              'Letzte Aktualisierung fehlgeschlagen; letzter Stand wird angezeigt.',
            ),
          if (snapshot.incomplete)
            const Text(
              'Weitere STAC-Seiten vorhanden bzw. Trefferlimit erreicht. Abdeckung unvollständig.',
            ),
          for (final item in snapshot.items) _record(item),
        ],
        const Text(
          'swissEO: © swisstopo · Contains modified Copernicus Sentinel data. '
          'Rapid Mapping: Source: FOEN, swisstopo. '
          'Einsatzbezogene Bilder sind nicht kontinuierliche schweizweite Beobachtungen. '
          'Große GeoTIFFs, nicht unterstützte Projektionen und Einzel-/Schrägbilder nur über amtliche Quelle öffnen.',
        ),
      ],
    ),
  );
}
