import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/osint/osint_provider_state.dart';
import '../../globe/globe_controller.dart';
import 'drought_metadata.dart';
import 'drought_metadata_service.dart';

/// Independent map imagery, without deriving permissions or local measurements.
class DroughtConditionSection extends StatefulWidget {
  const DroughtConditionSection({
    super.key,
    required this.globe,
    this.metadataService,
  });

  final GlobeController globe;
  final DroughtMetadataService? metadataService;

  @override
  State<DroughtConditionSection> createState() =>
      _DroughtConditionSectionState();
}

class _DroughtConditionSectionState extends State<DroughtConditionSection> {
  DroughtTimeStep _step = DroughtTimeStep.current;
  bool _expanded = false, _checking = false;
  String? _message;
  DroughtVhiMetadata? _metadata;
  int _generation = 0;
  DroughtMetadataService? _ownedService;

  DroughtMetadataService get _service =>
      widget.metadataService ?? (_ownedService ??= DroughtMetadataService());

  Future<void> _set(
    String id,
    bool visible, {
    double? opacity,
    bool retry = false,
  }) async {
    try {
      await widget.globe.showSituationalOverlay({
        'id': id,
        'visible': visible,
        'opacity': opacity ?? widget.globe.situationalOpacity(id),
        if (id == 'drought-index') 'timeStep': _step.value,
        if (retry) 'retry': true,
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Kartenebene konnte nicht geändert werden.');
      }
    }
  }

  Future<void> _check({bool offline = false, bool refresh = false}) async {
    if (_checking) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final result = offline
          ? await _service.offline()
          : await _service.check(refresh: refresh);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _metadata = result;
        if (result == null) {
          _message = 'Kein gespeicherter Metadatenstand vorhanden. Datenstand unbekannt.';
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Offizielle STAC-Metadaten nicht erreichbar; Datenstand nicht bestätigt.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Offizieller Link konnte nicht geöffnet werden.',
        );
      }
    }
  }

  String _date(DateTime? date) =>
      date?.toLocal().toIso8601String() ?? 'unbekannt';

  Widget _layer(String id, String title, String caption, String legendUrl) {
    final enabled = widget.globe.situationalVisible(id);
    final status = widget.globe.situationalStatus(id) ?? 'off';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: (value) => _set(id, value),
          title: Text(title),
          subtitle: Text(
            context.localizedWithArgs(
              "{0}\nKacheln: {1} · Quelldatum nicht durch Kachelladen bestätigt",
              [caption, status],
              (l10n, value) => l10n.mobilityKachelnQuelldatumNichtDurch5d14a5bc(
                value(0),
                value(1),
              ),
            ),
          ),
        ),
        if (id == 'drought-index')
          DropdownButtonFormField<DroughtTimeStep>(
            key: const ValueKey('drought_index_step'),
            initialValue: _step,
            decoration: InputDecoration(
              labelText: context.localized(
                "CDI-Zeitstand (offizieller WMS-Parameter)",
                (l10n) => l10n.mobilityCdiZeitstandOffiziellerWms68eccda7,
              ),
            ),
            items: [
              for (final step in DroughtTimeStep.values)
                DropdownMenuItem(value: step, child: Text(step.label)),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _step = value);
              if (enabled) {
                unawaited(_set(id, true));
              }
            },
          ),
        if (id == 'drought-index' && _step.isForecast)
          Text(
            context.localized(
              "Prognosezeitstand: keine direkte Beobachtung.",
              (l10n) =>
                  l10n.mobilityPrognosezeitstandKeineDirekteBeobachtungbef744b1,
            ),
          ),
        if (enabled) ...[
          Slider(
            value: widget.globe.situationalOpacity(id),
            label: '${(widget.globe.situationalOpacity(id) * 100).round()}%',
            onChanged: (value) => _set(id, true, opacity: value),
          ),
          if (status == 'failed')
            TextButton.icon(
              onPressed: () => _set(id, true, retry: true),
              icon: const Icon(Icons.refresh),
              label: Text(
                context.localized(
                  "Kacheln erneut versuchen",
                  (l10n) => l10n.mobilityKachelnErneutVersuchenc1fb6d60,
                ),
              ),
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _open(legendUrl),
            label: Text(
              context.localized(
                "Amtliche Legende / Produktinformation",
                (l10n) =>
                    l10n.mobilityAmtlicheLegendeProduktinformation73ec6293,
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  @override
  void dispose() {
    _generation++;
    if (_ownedService != null) {
      unawaited(_ownedService!.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _metadata;
    final state = data?.state(DateTime.now());
    return ListenableBuilder(
      listenable: widget.globe,
      builder: (context, _) => ExpansionTile(
        key: const ValueKey('drought_condition_section'),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        title: Text(
          context.localized(
            "Trockenheit & Vegetationszustand (BAFU / swissEO)",
            (l10n) =>
                l10n.mobilityTrockenheitVegetationszustandBafuSwisseoa63812c2,
          ),
        ),
        subtitle: Text(
          context.localized(
            "Drei unabhängige amtliche Kartenebenen · optional",
            (l10n) => l10n.mobilityDreiUnabhaengigeAmtlicheKartenebenen6c0dfad0,
          ),
        ),
        children: [
          Text(
            context.localized(
              "Regionale Indikatoren und satellitengestützte Modelle, keine Messung der lokalen Bodenfeuchte. Weder Feuerverbote noch Wasserentnahmebeschränkungen werden aus diesen Karten abgeleitet. Fehlende Kacheln sind keine Entwarnung.",
              (l10n) => l10n
                  .commonRegionaleIndikatorenUndSatellitengestuetzte10059e46,
            ),
          ),
          const SizedBox(height: 8),
          _layer(
            'drought-warning',
            'Amtliche Trockenheitswarnkarte',
            'BAFU · WMTS · amtliche Warnklassierung; keine rechtsverbindliche Verfügung · '
                'Veröffentlichungs- und Gültigkeitszeit unbekannt, sofern nicht separat bestätigt',
            'https://api3.geo.admin.ch/rest/services/api/MapServer/ch.bafu.trockenheitswarnkarte/legend',
          ),
          _layer(
            'drought-index',
            'Kombinierter Trockenheitsindex (CDI)',
            'BAFU · WMS · klassierter Index / Wochenzeitstände · modellierter Indikator',
            'https://api3.geo.admin.ch/rest/services/api/MapServer/ch.bafu.trockenheitsindex/legend',
          ),
          _layer(
            'vegetation-vhi',
            'swissEO Vegetation Health Index (VHI)',
            'swisstopo · WMS · relativer Vegetationsstressindex · '
                'Satellitendaten der letzten sieben Tage, Wolken-/Schattenmasken',
            'https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-vhi',
          ),
          _layer(
            'vegetation-vhi-all',
            'swissEO VHI – alle Vegetationsflächen',
            'swisstopo · WMS · relativer Vegetationsstressindex · '
                'landwirtschaftliche Flächen können nutzungsbedingt abweichen',
            'https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-vhi',
          ),
          Text(
            context.localized(
              "VHI v100 wird laut swisstopo bis Ende 2026 durch v200 ersetzt. Bis zur verifizierten Umstellung ist der aktuelle Layer eine Übergangslösung.",
              (l10n) => l10n.mobilityVhiVWirdLaute6dca0e6,
            ),
          ),
          Text(
            context.localized(
              "STAC-Metadaten für swissEO VHI werden nur auf Wunsch abgefragt. Der Abrufzeitpunkt und der Beobachtungszeitraum werden getrennt gespeichert. WMS-/WMTS-Kacheln werden nicht als Offline-Datensatz archiviert.",
              (l10n) => l10n.mobilityStacMetadatenFuerSwisseofe06af42,
            ),
          ),
          if (_checking) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                key: const ValueKey('drought_offline_metadata'),
                onPressed: _checking ? null : () => _check(offline: true),
                child: Text(
                  context.localized(
                    "Gespeicherten Stand",
                    (l10n) => l10n.mobilityGespeichertenStand0b0b171e,
                  ),
                ),
              ),
              FilledButton.tonal(
                key: const ValueKey('drought_refresh_metadata'),
                onPressed: _checking ? null : () => _check(refresh: true),
                child: Text(
                  context.localized(
                    "STAC-Datenstand prüfen",
                    (l10n) => l10n.mobilityStacDatenstandPruefen445b5f79,
                  ),
                ),
              ),
            ],
          ),
          if (_message != null) Text(_message!),
          if (data != null) ...[
            Text(
              context.localizedWithArgs(
                "swissEO VHI · Datenstatus: {0}",
                [state?.label ?? 'unbekannt'],
                (l10n, value) =>
                    l10n.mobilitySwisseoVhiDatenstatus0fe52fab(value(0)),
              ),
            ),
            Text(
              context.localizedWithArgs(
                "Beobachtungszeit: {0}",
                [_date(data.observedUtc)],
                (l10n, value) =>
                    l10n.mobilityBeobachtungszeite60e71e7(value(0)),
              ),
            ),
            Text(
              context.localizedWithArgs(
                "Beobachtungszeitraum (STAC): {0} – {1}",
                [_date(data.periodStartUtc), _date(data.periodEndUtc)],
                (l10n, value) => l10n.mobilityBeobachtungszeitraumStac7f2d19f8(
                  value(0),
                  value(1),
                ),
              ),
            ),
            Text(
              context.localizedWithArgs(
                "Quellenveröffentlichung: {0}",
                [_date(data.publishedUtc)],
                (l10n, value) =>
                    l10n.mobilityQuellenveroeffentlichung5456a71d(value(0)),
              ),
            ),
            Text(
              context.localizedWithArgs(
                "Metadaten heruntergeladen: {0}",
                [_date(data.fetchedUtc)],
                (l10n, value) =>
                    l10n.mobilityMetadatenHeruntergeladen4f8bd0e0(value(0)),
              ),
            ),
            if (data.incompletePage)
              Text(
                context.localized(
                  "Nur begrenzte STAC-Auswahl geprüft; Vollständigkeit nicht bestätigt.",
                  (l10n) => l10n.mobilityNurBegrenzteStacAuswahla9abd316,
                ),
              ),
            if (data.fromCache)
              Text(
                context.localized(
                  "Gespeicherter Metadatenstand – keine aktuelle Live-Bestätigung.",
                  (l10n) => l10n
                      .mobilityGespeicherterMetadatenstandKeineAktuelle17c89c8f,
                ),
              ),
            if (data.refreshFailed)
              Text(
                context.localized(
                  "Aktualisierung fehlgeschlagen; vorheriger Stand wird beibehalten.",
                  (l10n) => l10n
                      .mobilityAktualisierungFehlgeschlagenVorherigerStand6cb8348b,
                ),
              ),
          ],
          const Text(
            'Datenquellen: BAFU / Nationale Trockenheitsplattform · '
            '© swisstopo, Contains modified Copernicus Sentinel data [Jahr gemäss Produkt]. '
            'Für rechtlich verbindliche Einschränkungen kantonale Behörden prüfen.',
          ),
        ],
      ),
    );
  }
}
