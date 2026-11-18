import 'dart:async';

import '../../../core/localization/app_localizations.dart';

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
  final _formStorage = PageStorageBucket();
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
            Text(
              context.localizedWithArgs(
                "Produkt: {0} · {1}",
                [item.product.label, item.id],
                (l10n, value) =>
                    l10n.mobilityProduktbc93422a(value(0), value(1)),
              ),
            ),
            Text(
              context.localizedWithArgs("Aufnahme (UTC): {0}", [
                _date(item.acquiredUtc),
              ], (l10n, value) => l10n.mobilityAufnahmeUtc809df7be(value(0))),
            ),
            if (item.product == DatedImageryProduct.swissEo)
              Text(
                '© swisstopo, Contains modified Copernicus Sentinel data '
                '${item.acquiredUtc.toUtc().year}',
              ),
            Text(
              context.localizedWithArgs(
                "Veröffentlicht: {0}",
                [_date(item.publishedUtc)],
                (l10n, value) => l10n.mobilityVeroeffentlichtf559efaf(value(0)),
              ),
            ),
            if (item.missionContext != null)
              Text(
                context.localizedWithArgs(
                  "Ereignis / Einsatz: {0}",
                  [item.missionContext],
                  (l10n, value) =>
                      l10n.mobilityEreignisEinsatzac1a3fa0(value(0)),
                ),
              ),
            Text(
              context.localizedWithArgs("Abdeckung (WGS84): {0}", [
                item.bbox.map((x) => x.toStringAsFixed(4)).join(', '),
              ], (l10n, value) => l10n.mobilityAbdeckungWgsc9cd562f(value(0))),
            ),
            Text(
              item.cloudCoverPercent == null
                  ? context.localized(
                      "Wolkenanteil: nicht angegeben",
                      (l10n) => l10n.mobilityWolkenanteilNichtAngegeben76ffb608,
                    )
                  : context.localizedWithArgs(
                      "Wolkenanteil gemäss Quelle: {0} %",
                      [item.cloudCoverPercent!.toStringAsFixed(1)],
                      (l10n, value) => l10n
                          .mobilityWolkenanteilGemaessQuelle15e9a8e3(value(0)),
                    ),
            ),
            Text(
              item.qualityAssetAvailable
                  ? context.localized(
                      "Qualitäts-/Wolkenmaske als eigenes Datenasset vorhanden; nicht automatisch als wolkenfrei interpretiert.",
                      (l10n) =>
                          l10n.mobilityQualitaetsWolkenmaskeAlsEigenes3ad85811,
                    )
                  : context.localized(
                      "Keine überprüfte Qualitätsmaske – Wolken und Bildlücken können vorhanden sein.",
                      (l10n) => l10n
                          .mobilityKeineUeberpruefteQualitaetsmaskeWolken490d3ea2,
                    ),
            ),
            if (outside)
              Text(
                context.localized(
                  "Für dieses Einsatzprodukt ist kein georeferenzierter, begrenzt lesbarer RGB-GeoTIFF mit bestätigter Projektion hinterlegt. Kein Kartenbild erfunden.",
                  (l10n) => l10n.commonFuerDiesesEinsatzproduktIst01b0accb,
                ),
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
                    label: Text(
                      context.localized(
                        "Datierte Aufnahme anzeigen",
                        (l10n) => l10n.mobilityDatierteAufnahmeAnzeigen461270db,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _open(
                    item.viewerUrl ??
                        (item.product == DatedImageryProduct.swissEo
                            ? 'https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-s2-sr'
                            : 'https://www.swisstopo.admin.ch/en/service-rapid-mapping'),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    context.localized(
                      "Amtliche Quelle / Ansicht",
                      (l10n) => l10n.mobilityAmtlicheQuelleAnsicht283a8bdd,
                    ),
                  ),
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
  Widget build(BuildContext context) => PageStorage(
    bucket: _formStorage,
    child: ListenableBuilder(
      listenable: widget.globe,
      builder: (context, _) => ExpansionTile(
        key: const ValueKey('dated_imagery_section'),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        title: Text(
          context.localized(
            "Datierte Satelliten- & Rapid-Mapping-Bilder",
            (l10n) => l10n.mobilityDatierteSatellitenRapidMappingf807e800,
          ),
        ),
        subtitle: Text(
          context.localized(
            "swissEO Sentinel-2 v200 / amtliche Ereignisaufnahmen · optional",
            (l10n) => l10n.mobilitySwisseoSentinelVAmtlichedcab45cb,
          ),
        ),
        children: [
          Text(
            context.localized(
              "Ausgewählte Aufnahmen sind historische bzw. verzögert veröffentlichte Bilddaten. Keine Live-Beobachtung. Es werden nur kleine STAC-Metadaten gespeichert, keine Rohbilddateien. Wolken, Schatten und fehlende Bilddeckung sind keine leeren Flächen.",
              (l10n) => l10n.commonAusgewaehlteAufnahmenSindHistorische73e77349,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<DatedImageryProduct>(
            key: const ValueKey('dated_imagery_product'),
            isExpanded: true,
            initialValue: _product,
            decoration: InputDecoration(
              labelText: context.localized(
                "Amtliche Collection",
                (l10n) => l10n.mobilityAmtlicheCollectiond0ebbd40,
              ),
            ),
            items: [
              for (final product in DatedImageryProduct.values)
                DropdownMenuItem(
                  value: product,
                  child: Text(
                    product.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Breite (WGS84)",
                      (l10n) => l10n.mobilityBreiteWgsbf85fa1c,
                    ),
                  ),
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
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Länge (WGS84)",
                      (l10n) => l10n.mobilityLaengeWgs7a5b794e,
                    ),
                  ),
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
            decoration: InputDecoration(
              labelText: context.localized(
                "Suchradius",
                (l10n) => l10n.mobilitySuchradius51fb2797,
              ),
            ),
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
                child: Text(
                  context.localized(
                    "Datierte Bilder suchen",
                    (l10n) => l10n.mobilityDatierteBilderSuchen2f4ff702,
                  ),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('dated_imagery_offline'),
                onPressed: _busy ? null : () => _fetch(offline: true),
                child: Text(
                  context.localized(
                    "Letzten Katalogstand öffnen",
                    (l10n) => l10n.mobilityLetztenKatalogstandOeffnene2aafc7e,
                  ),
                ),
              ),
              if (widget.globe.datedImageryVisible)
                TextButton.icon(
                  key: const ValueKey('dated_imagery_restore'),
                  onPressed: _hide,
                  icon: const Icon(Icons.layers_clear),
                  label: Text(
                    context.localized(
                      "Bildebene entfernen / Basiskarte",
                      (l10n) =>
                          l10n.mobilityBildebeneEntfernenBasiskarte8d450df2,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            context.localizedWithArgs(
              "Bildlayer: {0}{1}",
              [
                widget.globe.datedImageryStatus,
                widget.globe.datedImageryItemId == null
                    ? ''
                    : ' · ${widget.globe.datedImageryItemId}',
              ],
              (l10n, value) =>
                  l10n.mobilityBildlayer7779aa56(value(0), value(1)),
            ),
          ),
          if (widget.globe.datedImageryError != null)
            Text(
              context.localizedWithArgs(
                "Darstellungsfehler: {0}",
                [widget.globe.datedImageryError],
                (l10n, value) =>
                    l10n.mobilityDarstellungsfehler750531ab(value(0)),
              ),
            ),
          if (_message != null) Text(_message!),
          if (_snapshot case final snapshot?) ...[
            Text(
              context.localizedWithArgs(
                "STAC abgefragt: {0} · {1} Treffer in begrenzter Stichprobe",
                [_date(snapshot.fetchedUtc), snapshot.items.length],
                (l10n, value) => l10n.mobilityStacAbgefragtTrefferIn004b3edc(
                  value(0),
                  value(1),
                ),
              ),
            ),
            if (snapshot.fromCache)
              Text(
                context.localized(
                  "Offline-/Cache-Katalog – keine Live-Bestätigung.",
                  (l10n) => l10n.mobilityOfflineCacheKatalogKeine803aa9f6,
                ),
              ),
            if (snapshot.isOld(DateTime.now()))
              Text(
                context.localized(
                  "Metadaten älter als 24 h / Uhrzeit unplausibel.",
                  (l10n) => l10n.mobilityMetadatenAelterAlsHfcd2d03c,
                ),
              ),
            if (snapshot.refreshFailed)
              Text(
                context.localized(
                  "Letzte Aktualisierung fehlgeschlagen; letzter Stand wird angezeigt.",
                  (l10n) => l10n
                      .mobilityLetzteAktualisierungFehlgeschlagenLetzterf5121616,
                ),
              ),
            if (snapshot.incomplete)
              Text(
                context.localized(
                  "Weitere STAC-Seiten vorhanden bzw. Trefferlimit erreicht. Abdeckung unvollständig.",
                  (l10n) => l10n.mobilityWeitereStacSeitenVorhanden8ac44f7a,
                ),
              ),
            for (final item in snapshot.items) _record(item),
          ],
          const Text(
            'Rapid Mapping: Source: FOEN, swisstopo. '
            'Einsatzbezogene Bilder sind nicht kontinuierliche schweizweite Beobachtungen. '
            'Große GeoTIFFs, nicht unterstützte Projektionen und Einzel-/Schrägbilder nur über amtliche Quelle öffnen.',
          ),
        ],
      ),
    ),
  );
}
