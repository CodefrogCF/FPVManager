import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart' show Spot;
import '../globe/globe_controller.dart';
import '../help/guides_screen.dart';
import '../home/coordinates_dialog.dart';
import '../mobility/destination_search.dart';
import '../mobility/road_routing.dart';
import '../mobility/mobility_preferences.dart';
import '../mobility/ojp/public_transport_section.dart';
import '../observations/observations_screen.dart';
import '../outdoor/outdoor_layers_section.dart';
import '../spots/data/spot_repository.dart';
import '../spots/spots_screen.dart';
import 'ground_route.dart';
import 'ground_route_files.dart';
import 'ground_route_repository.dart';
import 'ground_router.dart';

class GroundRoutesScreen extends StatefulWidget {
  const GroundRoutesScreen({
    super.key,
    required this.repository,
    required this.spots,
    required this.globe,
    this.router,
    this.files = const GroundRouteFiles(),
  });
  final GroundRouteRepository repository;
  final SpotRepository spots;
  final GlobeController globe;
  final GroundRouter? router;
  final GroundRouteFiles files;
  @override
  State<GroundRoutesScreen> createState() => _GroundRoutesScreenState();
}

class _GroundRoutesScreenState extends State<GroundRoutesScreen> {
  late final router = widget.router ?? GroundRouter();
  final name = TextEditingController(), search = TextEditingController();
  RoadDestination? origin, destination;
  GroundTravelMode? mode;
  GroundRoutePlan? displayed;
  int? recordId;
  bool consent = false, busy = false, dirty = false;
  String? error;
  int revision = 0, limit = 50;
  Stream<List<GroundRouteSummary>>? _saved;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _saved = widget.repository.watch(limit: limit, query: search.text);
  }

  @override
  void dispose() {
    revision++;
    if (widget.router == null) router.dispose();
    name.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException ? e.message : '$e');
      }
    }
  }

  Future<void> _point(bool start) async {
    final selected = widget.globe.selectedPoint;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          start
              ? context.localized(
                  "Start wählen",
                  (l10n) => l10n.groundroutesStartWaehlendb986579,
                )
              : context.localized(
                  "Ziel wählen",
                  (l10n) => l10n.groundroutesZielWaehlenaaa64252,
                ),
        ),
        children: [
          if (selected != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'map'),
              child: Text(
                context.localized(
                  "Gewählten Kartenpunkt übernehmen",
                  (l10n) =>
                      l10n.groundroutesGewaehltenKartenpunktUebernehmen1c0caa9a,
                ),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'search'),
            child: Text(
              context.localized(
                "Ort oder Koordinaten suchen",
                (l10n) => l10n.commonOrtOderKoordinatenSuchen6904cb89,
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'spot'),
            child: Text(
              context.localized(
                "Gespeicherten Ort auswählen",
                (l10n) => l10n.groundroutesGespeichertenOrtAuswaehlenf23d82e2,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    RoadDestination? value;
    if (choice == 'map') {
      value = RoadDestination(
        'Kartenpunkt',
        MobilityPoint(selected!.latitude, selected.longitude),
      );
    }
    if (choice == 'search') {
      value = await showDialog<RoadDestination>(
        context: context,
        builder: (_) => const CoordinatesDialog(),
      );
    }
    if (choice == 'spot') {
      if (!mounted) return;
      final spot = await Navigator.push<Spot>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SpotsScreen(repository: widget.spots, title: 'Ort auswählen'),
        ),
      );
      if (spot != null) {
        value = RoadDestination(
          spot.name,
          MobilityPoint(spot.latitude, spot.longitude),
        );
      }
    }
    if (value != null && mounted) {
      setState(() {
        start ? origin = value : destination = value;
        dirty = true;
      });
    }
  }

  Future<void> _calculate() async {
    if (busy ||
        !consent ||
        mode == null ||
        origin == null ||
        destination == null) {
      return;
    }
    final operation = ++revision;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final route = await router.calculate(
        origin!.point,
        destination!.point,
        mode!,
      );
      if (!mounted || operation != revision) return;
      setState(() {
        displayed = route.withName(
          name.text.trim().isEmpty ? route.name : name.text.trim(),
        );
        if (name.text.trim().isEmpty) name.text = route.name;
        dirty = true;
      });
    } catch (e) {
      if (mounted && operation == revision) {
        setState(
          () => error = '$e · Eine zuvor berechnete Route bleibt erhalten.',
        );
      }
    } finally {
      if (mounted && operation == revision) setState(() => busy = false);
    }
  }

  Future<bool> _discard() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.localized(
                "Ungespeicherten Entwurf verlassen?",
                (l10n) =>
                    l10n.groundroutesUngespeichertenEntwurfVerlassenff7b8bc6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  context.localized(
                    "Weiter bearbeiten",
                    (l10n) => l10n.commonWeiterBearbeitencc234070,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  context.localized(
                    "Verwerfen",
                    (l10n) => l10n.commonVerwerfen24cc57bc,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _open(int id) async {
    if (busy) return;
    if (!await _discard()) return;
    final route = await widget.repository.read(id);
    if (route == null || !mounted) return;
    setState(() {
      recordId = id;
      displayed = route;
      mode = route.mode;
      name.text = route.name;
      origin = RoadDestination('Gespeicherter Start', route.origin);
      destination = RoadDestination('Gespeichertes Ziel', route.destination);
      dirty = false;
      error = null;
    });
  }

  Future<void> _save() async {
    final route = displayed;
    if (route == null) return;
    if (name.text.trim().isEmpty || name.text.trim().length > 120) {
      throw const FormatException(
        'Bitte einen Routennamen mit 1–120 Zeichen eingeben',
      );
    }
    final saved = route.withName(name.text.trim());
    final id = await widget.repository.save(saved, id: recordId);
    if (mounted) {
      setState(() {
        recordId = id;
        displayed = saved;
        dirty = false;
      });
    }
  }

  Future<void> _import() async {
    if (mode == null) return;
    final preview = await widget.files.pick(mode!);
    if (preview == null || !mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.localized(
            "GPX-Bodenrouten importieren?",
            (l10n) => l10n.groundroutesGpxBodenroutenImportierenbc579b06,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in preview.routes)
                Text(
                  context.localizedWithArgs(
                    "{0} · {1} · {2} Punkte",
                    [r.name, r.mode.label, r.points.length],
                    (l10n, value) => l10n.groundroutesPunkte525d4984(
                      value(0),
                      value(1),
                      value(2),
                    ),
                  ),
                ),
              for (final warning in preview.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(warning),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.localized(
                "Abbrechen",
                (l10n) => l10n.commonAbbrechen07af7cb3,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.localized(
                "Importieren",
                (l10n) => l10n.commonImportieren7d4a3f2a,
              ),
            ),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await widget.repository.importAll(preview.routes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedWithArgs(
              "{0} Bodenrouten gespeichert",
              [preview.routes.length],
              (l10n, value) =>
                  l10n.groundroutesBodenroutenGespeichert7c176a33(value(0)),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _delete(GroundRouteSummary route) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.localizedWithArgs("„{0}“ löschen?", [
            route.name,
          ], (l10n, value) => l10n.groundroutesLoeschen42c1810b(value(0))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.localized(
                "Abbrechen",
                (l10n) => l10n.commonAbbrechen07af7cb3,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.localized(
                "Löschen",
                (l10n) => l10n.commonLoeschenffa5a8a7,
              ),
            ),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await widget.repository.delete(route.id);
      if (mounted && recordId == route.id) setState(() => recordId = null);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await _discard() && mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Bodenrouten",
            (l10n) => l10n.commonBodenroutenfc34e044,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<GroundTravelMode>(
              key: ValueKey(mode),
              initialValue: mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Routenmodus ausdrücklich wählen",
                  (l10n) =>
                      l10n.groundroutesRoutenmodusAusdruecklichWaehlen420b0d52,
                ),
              ),
              items: [
                for (final m in GroundTravelMode.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      mode = v;
                      dirty = true;
                    }),
            ),
            ListTile(
              leading: const Icon(Icons.trip_origin),
              title: Text(
                origin?.name ??
                    context.localized(
                      "Start wählen",
                      (l10n) => l10n.groundroutesStartWaehlendb986579,
                    ),
              ),
              subtitle: origin == null
                  ? null
                  : Text(
                      '${origin!.point.latitude.toStringAsFixed(5)}, ${origin!.point.longitude.toStringAsFixed(5)}',
                    ),
              onTap: busy ? null : () => _run(() => _point(true)),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(
                destination?.name ??
                    context.localized(
                      "Ziel wählen",
                      (l10n) => l10n.groundroutesZielWaehlenaaa64252,
                    ),
              ),
              subtitle: destination == null
                  ? null
                  : Text(
                      '${destination!.point.latitude.toStringAsFixed(5)}, ${destination!.point.longitude.toStringAsFixed(5)}',
                    ),
              onTap: busy ? null : () => _run(() => _point(false)),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicTransportScreen(
                          spots: widget.spots,
                          preferences: MobilityPreferences(
                            widget.repository.database,
                          ),
                          globe: widget.globe,
                          destination: origin?.point ?? displayed?.origin,
                          destinationName: origin?.name ?? 'Bodenrouten-Start',
                        ),
                      ),
                    ),
              icon: const Icon(Icons.directions_transit),
              label: Text(
                context.localized(
                  "ÖV-Anreise zum Bodenrouten-Start planen",
                  (l10n) => l10n.groundroutesOvAnreiseZumBodenrouten39acd10e,
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.localized(
                  "Start und Ziel zur Berechnung an FOSSGIS / OSRM senden",
                  (l10n) => l10n.groundroutesStartUndZielZur5a6b9fef,
                ),
              ),
              subtitle: Text(
                context.localized(
                  "Passendes Fuß- oder Veloprofil · OpenStreetMap-Grundlage",
                  (l10n) =>
                      l10n.groundroutesPassendesFussOderVeloprofilc351a9b0,
                ),
              ),
              value: consent,
              onChanged: busy ? null : (v) => setState(() => consent = v!),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      busy ||
                          !consent ||
                          mode == null ||
                          origin == null ||
                          destination == null
                      ? null
                      : _calculate,
                  icon: const Icon(Icons.route),
                  label: Text(
                    context.localized(
                      "Bodenroute berechnen",
                      (l10n) => l10n.groundroutesBodenrouteBerechnena780689a,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          if (await _discard() && mounted) {
                            setState(() {
                              recordId = null;
                              displayed = null;
                              name.clear();
                              dirty = false;
                            });
                          }
                        }),
                  icon: const Icon(Icons.add),
                  label: Text(
                    context.localized(
                      "Neue Route",
                      (l10n) => l10n.groundroutesNeueRoutec6a2c583,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: mode == null || busy ? null : () => _run(_import),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(
                    context.localized(
                      "GPX importieren",
                      (l10n) => l10n.groundroutesGpxImportieren08a786c6,
                    ),
                  ),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (displayed case final route?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.localizedWithArgs(
                          "Angezeigte Route: {0}",
                          [route.mode.label],
                          (l10n, value) => l10n
                              .groundroutesAngezeigteRouteeceb9858(value(0)),
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.localizedWithArgs(
                          "{0} Punkte · {1} · {2}",
                          [
                            route.points.length,
                            route.distanceMeters == null
                                ? 'Distanz unbekannt'
                                : '${(route.distanceMeters! / 1000).toStringAsFixed(2)} km',
                            route.durationSeconds == null
                                ? 'Dauer unbekannt'
                                : '${(route.durationSeconds! / 60).round()} min Schätzung',
                          ],
                          (l10n, value) => l10n.groundroutesPunkte9b66050f(
                            value(0),
                            value(1),
                            value(2),
                          ),
                        ),
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Quelle: {0}\nBerechnet: {1}",
                          [
                            route.source,
                            route.calculatedAtUtc?.toLocal() ??
                                'nicht angegeben',
                          ],
                          (l10n, value) =>
                              l10n.groundroutesQuelleBerechnet7150764e(
                                value(0),
                                value(1),
                              ),
                        ),
                      ),
                      if (mode != route.mode ||
                          origin?.point.latitude != route.origin.latitude ||
                          origin?.point.longitude != route.origin.longitude ||
                          destination?.point.latitude !=
                              route.destination.latitude ||
                          destination?.point.longitude !=
                              route.destination.longitude)
                        Text(
                          context.localized(
                            "Die angezeigte Route gehört zu den vorherigen Eingaben. Für die neuen Eingaben erneut berechnen.",
                            (l10n) => l10n
                                .groundroutesDieAngezeigteRouteGehoert7159dcb8,
                          ),
                        ),
                      TextFormField(
                        controller: name,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Name der Bodenroute",
                            (l10n) =>
                                l10n.groundroutesNameDerBodenroute997555dc,
                          ),
                        ),
                        onChanged: (_) => setState(() => dirty = true),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : () => _run(_save),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              recordId == null
                                  ? context.localized(
                                      "Bodenroute speichern",
                                      (l10n) => l10n
                                          .groundroutesBodenrouteSpeichern5b0ba694,
                                    )
                                  : context.localized(
                                      "Änderungen speichern",
                                      (l10n) => l10n
                                          .groundroutesAnderungenSpeichern00fe8153,
                                    ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _run(
                              () => widget.globe.showSituationalOverlay(
                                route.toGlobe(),
                              ),
                            ),
                            child: Text(
                              context.localized(
                                "Auf Globe anzeigen",
                                (l10n) =>
                                    l10n.groundroutesAufGlobeAnzeigenb40c4518,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _run(
                              () => widget.globe.showSituationalOverlay({
                                'id': 'ground-route',
                                'visible': false,
                              }),
                            ),
                            child: Text(
                              context.localized(
                                "Kartenvorschau ausblenden",
                                (l10n) => l10n
                                    .groundroutesKartenvorschauAusblenden048fe407,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _run(() async {
                              await widget.files.save(
                                route.withName(
                                  name.text.trim().isEmpty
                                      ? route.name
                                      : name.text.trim(),
                                ),
                              );
                            }),
                            child: const Text('GPX exportieren'),
                          ),
                          TextButton(
                            onPressed: () => _run(() async {
                              await widget.globe.observations.setContext(
                                route.points,
                              );
                              if (!context.mounted) return;
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ObservationsScreen(
                                    controller: widget.globe.observations,
                                  ),
                                ),
                              );
                            }),
                            child: Text(
                              context.localized(
                                "Messstationen entlang der Route",
                                (l10n) => l10n
                                    .groundroutesMessstationenEntlangDerRouted9e511cf,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showOutdoorContext(
                              context,
                              globe: widget.globe,
                              path: route.points,
                            ),
                            child: Text(
                              context.localized(
                                "Sperrungen im Routenumfeld",
                                (l10n) => l10n
                                    .groundroutesSperrungenImRoutenumfeld41a77f10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Oberfläche: {0} · Zugang: {1}\nHöhen: {2}",
                          [
                            route.attributes['surface'] ??
                                'nicht bereitgestellt',
                            route.attributes['access'] ??
                                'nicht bereitgestellt',
                            route.elevations == null
                                ? 'nicht bereitgestellt'
                                : 'Quelldaten; Referenz: ${route.attributes['elevationReference'] ?? 'unbekannt'}',
                          ],
                          (l10n, value) =>
                              l10n.groundroutesOberflaecheZugangHoehen28c32a79(
                                value(0),
                                value(1),
                                value(2),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const GuideLink(GuideTopic.outdoor),
            const Divider(),
            Text(
              context.localized(
                "Lokal gespeicherte Bodenrouten",
                (l10n) => l10n.groundroutesLokalGespeicherteBodenrouten5824582d,
              ),
            ),
            TextField(
              controller: search,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Gespeicherte Bodenrouten suchen",
                  (l10n) =>
                      l10n.groundroutesGespeicherteBodenroutenSuchenf43e3c82,
                ),
              ),
              onChanged: (_) => setState(_watch),
            ),
            StreamBuilder<List<GroundRouteSummary>>(
              stream: _saved,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    context.localized(
                      "Gespeicherte Bodenrouten konnten nicht geladen werden.",
                      (l10n) => l10n
                          .groundroutesGespeicherteBodenroutenKonntenNicht88267d75,
                    ),
                  );
                }
                final records = snapshot.data ?? [];
                return Column(
                  children: [
                    for (final r in records)
                      ListTile(
                        leading: Icon(
                          r.mode == GroundTravelMode.walking
                              ? Icons.hiking
                              : Icons.directions_bike,
                        ),
                        title: Text(r.name),
                        subtitle: Text(
                          context.localizedWithArgs(
                            "{0} · lokal gespeichert",
                            [r.mode.label],
                            (l10n, value) => l10n
                                .groundroutesLokalGespeichertdafc6ec0(value(0)),
                          ),
                        ),
                        onTap: busy ? null : () => _run(() => _open(r.id)),
                        trailing: IconButton(
                          tooltip: context.localized(
                            "Bodenroute löschen",
                            (l10n) =>
                                l10n.groundroutesBodenrouteLoeschen3c5c9ab7,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: busy ? null : () => _run(() => _delete(r)),
                        ),
                      ),
                    if (records.length >= limit && limit < 500)
                      TextButton(
                        onPressed: () => setState(() {
                          limit += 50;
                          _watch();
                        }),
                        child: Text(
                          context.localized(
                            "Weitere Bodenrouten anzeigen",
                            (l10n) => l10n
                                .groundroutesWeitereBodenroutenAnzeigen6060cffc,
                          ),
                        ),
                      ),
                    if (records.length >= 500)
                      Text(
                        context.localized(
                          "500 Treffer angezeigt. Bitte die Suche eingrenzen.",
                          (l10n) =>
                              l10n.groundroutesTrefferAngezeigtBitteDiefb7ecafc,
                        ),
                      ),
                    if (snapshot.hasData && records.isEmpty)
                      Text(
                        context.localized(
                          "Keine gespeicherten Bodenrouten gefunden",
                          (l10n) => l10n
                              .groundroutesKeineGespeichertenBodenroutenGefunden7adb49f7,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
