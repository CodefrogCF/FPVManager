import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/osint/osint_provider.dart';
import 'road_routing.dart';
import 'route_traffic_evaluation.dart';

class RoadRouteComparison extends StatefulWidget {
  const RoadRouteComparison({
    super.key,
    required this.routes,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.onEnabled,
    this.traffic,
    this.counters,
    this.onOpenTraffic,
    this.now,
  });
  final List<RoadRoute> routes;
  final RoadRoute selected;
  final bool enabled;
  final ValueChanged<RoadRoute> onSelected;
  final ValueChanged<bool> onEnabled;
  final OsintProvider<Map<String, dynamic>>? traffic, counters;
  final VoidCallback? onOpenTraffic;
  final DateTime Function()? now;
  @override
  State<RoadRouteComparison> createState() => _ComparisonState();
}

class _ComparisonState extends State<RoadRouteComparison> {
  RouteTrafficEvaluation? _result;
  bool _busy = false, _again = false;
  String? _error;
  int _epoch = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _listen(true);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }

  void _listen(bool add) {
    for (final p in [widget.traffic, widget.counters]) {
      if (add) {
        p?.addListener(_changed);
      } else {
        p?.removeListener(_changed);
      }
    }
  }

  void _changed() {
    ++_epoch;
    if (mounted) setState(() => _result = null);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(RoadRouteComparison old) {
    super.didUpdateWidget(old);
    old.traffic?.removeListener(_changed);
    old.counters?.removeListener(_changed);
    _listen(true);
    if (!listEquals(old.routes, widget.routes) ||
        old.enabled != widget.enabled ||
        old.traffic != widget.traffic ||
        old.counters != widget.counters) {
      ++_epoch;
      _result = null;
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (!mounted || !widget.enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (_busy) {
      _again = true;
      ++_epoch;
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await compute(
        evaluateRouteTraffic,
        RouteTrafficInput(
          widget.routes,
          (widget.now ?? DateTime.now)().toUtc(),
          traffic: widget.traffic?.status,
          counters: widget.counters?.status,
        ),
      );
      if (mounted && epoch == _epoch && widget.enabled) {
        setState(() => _result = result);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = 'Verkehrsbewertung nicht verfügbar. OSRM-Basiszeiten bleiben erhalten.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_again) {
          _again = false;
          unawaited(_refresh());
        }
      }
    }
  }

  @override
  void dispose() {
    ++_epoch;
    _listen(false);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.localized(
            "Verkehr bei der Routenbewertung berücksichtigen",
            (l10n) => l10n.mobilityVerkehrBeiDerRoutenbewertung65a144f1,
          ),
        ),
        subtitle: Text(
          context.localized(
            "Nutzt vorhandene Daten. Beeinflusst auch spätere Neuberechnungen; die Fahrzeit bleibt eine OSRM-Basisschätzung.",
            (l10n) => l10n.mobilityNutztVorhandeneDatenBeeinflusst7a5969ac,
          ),
        ),
        value: widget.enabled,
        onChanged: widget.onEnabled,
      ),
      if (widget.onOpenTraffic != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: widget.onOpenTraffic,
            child: Text(
              context.localized(
                "Verkehrsdaten laden / prüfen",
                (l10n) => l10n.mobilityVerkehrsdatenLadenPruefen27aded3f,
              ),
            ),
          ),
        ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      for (var i = 0; i < widget.routes.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: () => widget.onSelected(widget.routes[i]),
                  icon: Icon(
                    identical(widget.selected, widget.routes[i])
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  label: Text(
                    'Route ${i + 1}${widget.enabled && _result?.recommendedIndex == i ? (_result!.trafficInfluenced ? ' · Empfehlung' : ' · OSRM-Basis') : ''} · ${(widget.routes[i].distanceMeters / 1000).toStringAsFixed(1)} km · ${(widget.routes[i].durationSeconds / 60).ceil()} min OSRM',
                  ),
                ),
                if (widget.enabled && _result != null)
                  RouteTrafficAssessmentView(
                    assessment: _result!.assessments[i],
                  ),
              ],
            ),
          ),
        ),
      if (widget.enabled && _result != null)
        RouteTrafficExplanation(evaluation: _result!),
      if (widget.routes.first.omittedAlternatives > 0)
        Text(
          context.localizedWithArgs(
            "{0} weitere / ungültige Alternativen nicht dargestellt.",
            [widget.routes.first.omittedAlternatives],
            (l10n, value) => l10n
                .mobilityWeitereUngueltigeAlternativenNichtc1e16f33(value(0)),
          ),
        ),
      Text(
        context.localized(
          "OSRM liefert nicht immer Alternativen. Fehlende Meldungen oder Messungen bestätigen keinen freien Verkehrsfluss.",
          (l10n) => l10n.mobilityOsrmLiefertNichtImmer92919ffd,
        ),
      ),
    ],
  );
}

class RouteTrafficAssessmentView extends StatelessWidget {
  const RouteTrafficAssessmentView({super.key, required this.assessment});
  final RouteTrafficAssessment assessment;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.localizedWithArgs(
          "{0} zugeordnete Sperrmeldungen · {1} zugeordnete Quellenhinweise",
          [assessment.closures, assessment.evidence.length],
          (l10n, value) => l10n
              .mobilityZugeordneteSperrmeldungenZugeordneteQuellenhinweiseee632e99(
                value(0),
                value(1),
              ),
        ),
      ),
      if (assessment.reportedDelaySeconds != null)
        Text(
          context.localizedWithArgs(
            "Größte publizierte Verzögerung: {0} min · Vergleichswert, nicht zur Ankunftszeit addiert",
            [(assessment.reportedDelaySeconds! / 60).ceil()],
            (l10n, value) =>
                l10n.commonGroesstePublizierteVerzoegerungMinc0ec7c7c(value(0)),
          ),
        ),
      if (assessment.incomplete)
        Text(
          context.localized(
            "Bewertung unvollständig · keine verkehrsbasierte Empfehlung",
            (l10n) => l10n
                .mobilityBewertungUnvollstaendigKeineVerkehrsbasierte655a9750,
          ),
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          context.localized(
            "Zuordnung und Quellen",
            (l10n) => l10n.mobilityZuordnungUndQuellend088f13c,
          ),
        ),
        children: [
          Text(
            context.localizedWithArgs(
              "{0} Datensätze nicht sicher zugeordnet / nicht gewichtet. Fehlende Straßenkennung, Richtung, Ortsauflösung oder Gültigkeit bleiben unbekannt.",
              [assessment.ignored],
              (l10n, value) =>
                  l10n.commonDatensaetzeNichtSicherZugeordnet393f5548(value(0)),
            ),
          ),
          for (final e in assessment.evidence.take(30))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${e.road} · ${e.title}'),
              subtitle: Text(
                '${e.kind} · ${e.time.toLocal()}${e.speedKmh == null ? '' : ' · ${e.speedKmh!.toStringAsFixed(0)} km/h (punktuell)'}${e.delaySeconds == null ? '' : ' · ${(e.delaySeconds! / 60).ceil()} min publizierte Verzögerung'}${e.locationReference == null ? '' : '\n${e.locationReference}'}',
              ),
            ),
          if (assessment.evidence.length > 30)
            Text(
              context.localizedWithArgs(
                "{0} weitere zugeordnete Hinweise",
                [assessment.evidence.length - 30],
                (l10n, value) =>
                    l10n.mobilityWeitereZugeordneteHinweise883d2761(value(0)),
              ),
            ),
        ],
      ),
    ],
  );
}

class RouteTrafficExplanation extends StatelessWidget {
  const RouteTrafficExplanation({super.key, required this.evaluation});
  final RouteTrafficEvaluation evaluation;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(
      context.localized(
        "Datenstand und Bewertungsregeln",
        (l10n) => l10n.mobilityDatenstandUndBewertungsregeln47599d2e,
      ),
    ),
    children: [
      Text(
        context.localizedWithArgs("Vergleich: {0}", [
          evaluation.evaluatedAt.toLocal(),
        ], (l10n, value) => l10n.mobilityVergleichd42555f6(value(0))),
      ),
      Text(evaluation.trafficStatus),
      Text(evaluation.counterStatus),
      Text(
        context.localized(
          "Zuerst werden Routen mit zugeordneten Sperrmeldungen nachrangig angezeigt. Danach zählen OSRM-Basiszeit und der größte publizierte Verzögerungswert. Verzögerungen werden nicht summiert und verändern die angezeigte Ankunftszeit nicht.",
          (l10n) => l10n.mobilityZuerstWerdenRoutenMit9d2c4bb2,
        ),
      ),
      Text(
        evaluation.speedCompared
            ? context.localized(
                "Vergleichbare Gesamtverkehrs-Messungen aller Alternativen beeinflussen den Vergleich geringfügig (höchstens ein Vergleichspunkt).",
                (l10n) => l10n
                    .mobilityVergleichbareGesamtverkehrsMessungenAller0e5faa9f,
              )
            : context.localized(
                "Punktuelle Geschwindigkeiten werden ohne vergleichbare Messungen aller Alternativen nicht gewichtet.",
                (l10n) =>
                    l10n.mobilityPunktuelleGeschwindigkeitenWerdenOhne74f8b6a6,
              ),
      ),
      const Text(
        'Zuordnung: explizite Straßenkennung, unterstützte Richtung und eindeutige Quellenposition nahe der Straße. TMC-Abschnitte erfordern die exakte Ortstabelle, geordnete Anker entlang derselben Straße und passende Fahrtrichtung; Offsets werden entlang der Route gemessen. Dateiimporte der Ortstabelle bleiben ohne Online-Bestätigung Information. Gerade Ankerverbindungen werden nicht als Straßenverlauf gewertet. Quellen: ASTRA / VDP; Routing: FOSSGIS / OSRM / © OpenStreetMap contributors.',
      ),
    ],
  );
}
