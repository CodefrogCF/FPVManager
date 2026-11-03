import 'dart:async';

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
        title: Text(start ? 'Start wählen' : 'Ziel wählen'),
        children: [
          if (selected != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'map'),
              child: const Text('Gewählten Kartenpunkt übernehmen'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'search'),
            child: const Text('Ort oder Koordinaten suchen'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'spot'),
            child: const Text('Gespeicherten Ort auswählen'),
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
            title: const Text('Ungespeicherten Entwurf verlassen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Weiter bearbeiten'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Verwerfen'),
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
        title: const Text('GPX-Bodenrouten importieren?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in preview.routes)
                Text('${r.name} · ${r.mode.label} · ${r.points.length} Punkte'),
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
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await widget.repository.importAll(preview.routes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${preview.routes.length} Bodenrouten gespeichert'),
        ),
      );
    }
  }

  Future<void> _delete(GroundRouteSummary route) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${route.name}“ löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
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
      appBar: AppBar(title: const Text('Bodenrouten')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<GroundTravelMode>(
              key: ValueKey(mode),
              initialValue: mode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Routenmodus ausdrücklich wählen',
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
              title: Text(origin?.name ?? 'Start wählen'),
              subtitle: origin == null
                  ? null
                  : Text(
                      '${origin!.point.latitude.toStringAsFixed(5)}, ${origin!.point.longitude.toStringAsFixed(5)}',
                    ),
              onTap: busy ? null : () => _run(() => _point(true)),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(destination?.name ?? 'Ziel wählen'),
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
              label: const Text('ÖV-Anreise zum Bodenrouten-Start planen'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Start und Ziel zur Berechnung an FOSSGIS / OSRM senden',
              ),
              subtitle: const Text(
                'Passendes Fuß- oder Veloprofil · OpenStreetMap-Grundlage',
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
                  label: const Text('Bodenroute berechnen'),
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
                  label: const Text('Neue Route'),
                ),
                OutlinedButton.icon(
                  onPressed: mode == null || busy ? null : () => _run(_import),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('GPX importieren'),
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
                        'Angezeigte Route: ${route.mode.label}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${route.points.length} Punkte · ${route.distanceMeters == null ? 'Distanz unbekannt' : '${(route.distanceMeters! / 1000).toStringAsFixed(2)} km'} · ${route.durationSeconds == null ? 'Dauer unbekannt' : '${(route.durationSeconds! / 60).round()} min Schätzung'}',
                      ),
                      Text(
                        'Quelle: ${route.source}\nBerechnet: ${route.calculatedAtUtc?.toLocal() ?? 'nicht angegeben'}',
                      ),
                      if (mode != route.mode ||
                          origin?.point.latitude != route.origin.latitude ||
                          origin?.point.longitude != route.origin.longitude ||
                          destination?.point.latitude !=
                              route.destination.latitude ||
                          destination?.point.longitude !=
                              route.destination.longitude)
                        const Text(
                          'Die angezeigte Route gehört zu den vorherigen Eingaben. Für die neuen Eingaben erneut berechnen.',
                        ),
                      TextFormField(
                        controller: name,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Name der Bodenroute',
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
                                  ? 'Bodenroute speichern'
                                  : 'Änderungen speichern',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _run(
                              () => widget.globe.showSituationalOverlay(
                                route.toGlobe(),
                              ),
                            ),
                            child: const Text('Auf Globe anzeigen'),
                          ),
                          TextButton(
                            onPressed: () => _run(
                              () => widget.globe.showSituationalOverlay({
                                'id': 'ground-route',
                                'visible': false,
                              }),
                            ),
                            child: const Text('Kartenvorschau ausblenden'),
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
                            child: const Text(
                              'Messstationen entlang der Route',
                            ),
                          ),
                          TextButton(
                            onPressed: () => showOutdoorContext(
                              context,
                              globe: widget.globe,
                              path: route.points,
                            ),
                            child: const Text('Sperrungen im Routenumfeld'),
                          ),
                        ],
                      ),
                      Text(
                        'Oberfläche: ${route.attributes['surface'] ?? 'nicht bereitgestellt'} · Zugang: ${route.attributes['access'] ?? 'nicht bereitgestellt'}\nHöhen: ${route.elevations == null ? 'nicht bereitgestellt' : 'Quelldaten; Referenz: ${route.attributes['elevationReference'] ?? 'unbekannt'}'}',
                      ),
                    ],
                  ),
                ),
              ),
            const GuideLink(GuideTopic.outdoor),
            const Divider(),
            const Text('Lokal gespeicherte Bodenrouten'),
            TextField(
              controller: search,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Gespeicherte Bodenrouten suchen',
              ),
              onChanged: (_) => setState(_watch),
            ),
            StreamBuilder<List<GroundRouteSummary>>(
              stream: _saved,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Gespeicherte Bodenrouten konnten nicht geladen werden.',
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
                        subtitle: Text('${r.mode.label} · lokal gespeichert'),
                        onTap: busy ? null : () => _run(() => _open(r.id)),
                        trailing: IconButton(
                          tooltip: 'Bodenroute löschen',
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
                        child: const Text('Weitere Bodenrouten anzeigen'),
                      ),
                    if (records.length >= 500)
                      const Text(
                        '500 Treffer angezeigt. Bitte die Suche eingrenzen.',
                      ),
                    if (snapshot.hasData && records.isEmpty)
                      const Text('Keine gespeicherten Bodenrouten gefunden'),
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
