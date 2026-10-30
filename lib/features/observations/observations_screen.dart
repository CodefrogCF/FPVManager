import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/osint/osint_provider_state.dart';
import '../help/guides_screen.dart';
import 'observation_controller.dart';

class ObservationsScreen extends StatelessWidget {
  const ObservationsScreen({
    super.key,
    required this.controller,
    this.onChooseLocation,
  });
  final ObservationController controller;
  final Future<void> Function()? onChooseLocation;
  String _date(BuildContext context, DateTime value) {
    final local = value.toLocal(), labels = MaterialLocalizations.of(context);
    return '${labels.formatCompactDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)} ${local.timeZoneName}';
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messstationen')),
    body: SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'MeteoSwiss · Wetter'),
                Tab(text: 'BAFU · Gewässer'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in StationKind.values)
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        final provider = controller.provider(kind),
                            status = provider?.status,
                            data = status?.dataset,
                            stations = controller.stations(kind),
                            busy = status?.update == OsintUpdateState.loading;
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Gemessene Stationswerte · keine Prognose',
                            ),
                            if (controller.path.isNotEmpty)
                              Text(
                                'Bezug: ${controller.path.length == 1 ? 'Kartenpunkt' : 'Route'} · ${controller.path.first.latitude.toStringAsFixed(4)}, ${controller.path.first.longitude.toStringAsFixed(4)}',
                              ),
                            if (onChooseLocation != null)
                              TextButton.icon(
                                onPressed: () =>
                                    _run(context, onChooseLocation!),
                                icon: const Icon(Icons.place_outlined),
                                label: const Text(
                                  'Kartenpunkt, Ort oder Route wählen',
                                ),
                              ),
                            const Text(
                              'Abrufen sendet bei BAFU eine Auswahl naher Stationsnummern; MeteoSwiss wird als landesweite Datei geladen.',
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Stationen auf der Karte'),
                              value: controller.visible.contains(kind),
                              onChanged: controller.path.isEmpty
                                  ? null
                                  : (v) => _run(
                                      context,
                                      () => controller.setVisible(kind, v),
                                    ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: busy || controller.path.isEmpty
                                      ? null
                                      : () => _run(
                                          context,
                                          () => controller.refresh(kind),
                                        ),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Messwerte abrufen'),
                                ),
                                if (data != null)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => _run(context, () async {
                                            await provider!.clearCache();
                                            await controller.restoreRenderer();
                                          }),
                                    child: const Text(
                                      'Lokalen Snapshot löschen',
                                    ),
                                  ),
                              ],
                            ),
                            if (busy) const LinearProgressIndicator(),
                            Text(
                              status?.dataState.label ??
                                  'Daten nicht verfügbar',
                            ),
                            if (data != null)
                              Text(
                                'Abgerufen: ${_date(context, data.fetchedAtUtc)}\nZuletzt geprüft: ${_date(context, data.lastCheckedAtUtc ?? data.fetchedAtUtc)}',
                              ),
                            if (status?.error != null)
                              Text(
                                '${status!.error}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (status?.cacheError != null)
                              Text(status!.cacheError!),
                            if (controller.renderErrors[kind] != null)
                              Text(controller.renderErrors[kind]!),
                            Text(
                              kind == StationKind.meteo
                                  ? 'Quelle: MeteoSchweiz · SwissMetNet · CC BY 4.0. Wind/Böen in km/h; Niederschlag als 10-Minuten-Summe.'
                                  : 'Quelle: BAFU · Hydrologische Beobachtungen. Live ist unkorrigiert; 10-Minuten-Mittel und Freigabestatus bleiben getrennt.',
                            ),
                            if (data != null) Text('${data.data['coverage']}'),
                            if (data?.data['incomplete'] == true)
                              const Text(
                                'Unvollständiger Datenauszug; weitere Messwerte können fehlen.',
                              ),
                            if ((data?.data['unlocated'] as int? ?? 0) > 0)
                              Text(
                                '${data!.data['unlocated']} Stationen ohne zuordenbare Metadaten.',
                              ),
                            if (data != null && stations.isEmpty)
                              const Text(
                                'Keine verfügbaren Messstationen im gewählten Umfeld. Fehlende Werte bedeuten keine Entwarnung.',
                              ),
                            for (final station in stations)
                              ExpansionTile(
                                title: Text(station.name),
                                subtitle: Text(
                                  '${station.id} · ${station.readings.length} verfügbare Werte'
                                  '${station.readings.isEmpty ? " · Messwerte nicht verfügbar" : "\nLetzte Messung: ${_date(context, station.readings.map((r) => r.atUtc).reduce((a, b) => a.isAfter(b) ? a : b))}"}'
                                  '${station.readings.isNotEmpty && station.readings.every((r) => r.outdated(DateTime.now().toUtc(), controller.maxAge(kind))) ? " · veraltet" : ""}',
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SelectableText(
                                      station.detail(
                                        DateTime.now().toUtc(),
                                        controller.maxAge(kind),
                                      ),
                                    ),
                                  ),
                                  if (station.metadata['reference']
                                      case final String ref)
                                    TextButton(
                                      onPressed: () => _reference(ref),
                                      child: const Text(
                                        'Offizielle Stationsdetails',
                                      ),
                                    ),
                                ],
                              ),
                            TextButton.icon(
                              onPressed: provider == null
                                  ? null
                                  : () => launchUrl(
                                      provider.source.metadataUri,
                                      mode: LaunchMode.externalApplication,
                                    ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text(
                                'Quelle und Produktbeschreibung',
                              ),
                            ),
                            const GuideLink(GuideTopic.outdoor),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _reference(String reference) async {
    final uri = Uri.tryParse(reference);
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        {
          'www.meteoschweiz.admin.ch',
          'www.meteoswiss.admin.ch',
        }.contains(uri.host)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
