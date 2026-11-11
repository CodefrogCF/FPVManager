import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../globe/globe_controller.dart';
import 'wind_field.dart';

Future<void> showWindSettings(BuildContext context, GlobeController globe) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WindSettings(globe: globe),
    );

class WindControlsLauncher extends StatelessWidget {
  const WindControlsLauncher({
    super.key,
    required this.globe,
    this.flight = false,
  });
  final GlobeController globe;
  final bool flight;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: globe.wind,
    builder: (context, _) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.air),
      title: Text(
        flight
            ? context.translate("Wind im Flug")
            : context.translate("3D-Wind und Prognose"),
      ),
      subtitle: Text(
        globe.wind.snapshot == null
            ? context.translate("Optional · Winddaten noch nicht geladen")
            : globe.wind.expired
            ? context.translate("Winddaten abgelaufen")
            : globe.wind.affectFlight
            ? context.translate("Wind beeinflusst den Simulator")
            : globe.wind.visible
            ? context.translate("3D-Pfeile aktiv")
            : context.translate("Winddarstellung und Einfluss aus"),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showWindSettings(context, globe),
    ),
  );
}

class _WindSettings extends StatefulWidget {
  const _WindSettings({required this.globe});
  final GlobeController globe;
  @override
  State<_WindSettings> createState() => _WindSettingsState();
}

class _WindSettingsState extends State<_WindSettings> {
  late var _mode = widget.globe.wind.mode;
  late DateTime _time =
      widget.globe.wind.forecastUtc?.toLocal() ?? DateTime.now();
  late double _radius = widget.globe.wind.snapshot?.radiusMeters ?? 1500;
  String? _error;
  bool _locating = false;
  Future<void> _choose() async {
    final now = DateTime.now(),
        end = DateTime.now().add(const Duration(days: 7));
    final initial = _time.isBefore(now)
        ? now
        : _time.isAfter(end)
        ? end
        : _time;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: end,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null && mounted) {
      setState(
        () => _time = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _load() async {
    if (_locating) return;
    setState(() {
      _error = null;
      _locating = true;
    });
    try {
      await widget.globe.loadWindAtSelection(
        mode: _mode,
        timeUtc: _mode == WindTimeMode.forecast ? _time.toUtc() : null,
        radiusMeters: _radius,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: widget.globe.wind,
      builder: (context, _) {
        final wind = widget.globe.wind, field = wind.snapshot;
        String time(DateTime value) =>
            '${MaterialLocalizations.of(context).formatCompactDate(value.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()), alwaysUse24HourFormat: true)} ${value.toLocal().timeZoneName}';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.translate("3D-Wind und Flugwind")),
                trailing: IconButton(
                  tooltip: context.translate("Schließen"),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.translate("3D-Windpfeile anzeigen")),
                value: wind.visible,
                onChanged: (v) => wind.flags(arrows: v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.translate("Wind im Flugsimulator berücksichtigen"),
                ),
                subtitle: Text(
                  context.translate(
                    "Angle/Acro: Abdrift. GPS: Gegenhalten bis zur Leistungsgrenze.",
                  ),
                ),
                value: wind.affectFlight,
                onChanged: (v) => wind.flags(physics: v),
              ),
              DropdownButtonFormField<WindTimeMode>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: context.translate("Windquelle / Zeit"),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: WindTimeMode.current,
                    child: Text(context.translate("Aktueller Modellwind")),
                  ),
                  DropdownMenuItem(
                    value: WindTimeMode.forecast,
                    child: Text('Windprognose'),
                  ),
                ],
                onChanged: wind.loading
                    ? null
                    : (v) {
                        if (v != null) setState(() => _mode = v);
                      },
              ),
              if (_mode == WindTimeMode.forecast)
                TextButton.icon(
                  onPressed: wind.loading ? null : _choose,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(time(_time)),
                ),
              DropdownButtonFormField<double>(
                initialValue: _radius,
                decoration: InputDecoration(
                  labelText: context.translate(
                    "Ausschnitt um den gewählten Punkt",
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1500, child: Text('3 × 3 km')),
                  DropdownMenuItem(value: 5000, child: Text('10 × 10 km')),
                ],
                onChanged: wind.loading
                    ? null
                    : (v) {
                        if (v != null) setState(() => _radius = v);
                      },
              ),
              const SizedBox(height: 12),
              Text(
                context.translate(
                  "Beim Abruf werden die gewählten Kartenkoordinaten an Open-Meteo gesendet. „Aktuell“ sind Modellwerte, keine Live-Messung vor Ort. Daten und Auswahl gelten für diese Sitzung.",
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: wind.loading || _locating ? null : _load,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  context.translate("Winddaten für Punkt / Ansicht laden"),
                ),
              ),
              if (wind.loading) const LinearProgressIndicator(),
              if (_error ?? wind.error case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (field != null) ...[
                Text(
                  '${field.mode == WindTimeMode.current ? 'Aktiver Modellwind' : 'Aktive Prognose'}: ${time(field.validAtUtc)}',
                ),
                Text(
                  context.translate("Abgerufen: {0} · {1}/9 Rasterpunkte", [
                    time(field.retrievedUtc),
                    field.usableNodes,
                  ]),
                ),
                if (wind.expired)
                  Text(
                    context.translate(
                      "Abgelaufen: Pfeile und Windeinfluss sind ausgesetzt.",
                    ),
                  ),
                if (wind.visible && wind.rendererState == 'terrainPending')
                  Text(
                    context.translate(
                      "Windpfeile warten auf geladenes 3D-Gelände.",
                    ),
                  ),
                if (wind.refreshFailed)
                  Text(
                    context.translate(
                      "Letzte Aktualisierung fehlgeschlagen. Die vorherigen Daten bleiben bis zum Ablauf verfügbar.",
                    ),
                  ),
                TextButton.icon(
                  onPressed: wind.loading ? null : wind.refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    context.translate("Diesen Ausschnitt aktualisieren"),
                  ),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.translate("Daten und Grenzen")),
                children: [
                  Text(
                    context.translate(
                      "Open-Meteo · CC BY 4.0; kostenloser Zugang für nicht kommerzielle Nutzung. Aktueller Modellwind wird bei aktiver Darstellung oder im Flug alle 15 Minuten aktualisiert. Prognosen verwenden den nächsten verfügbaren Stundenwert. Sonnenzeit und Windzeit sind unabhängig. Zwischen Rasterpunkten und Modellhöhen (10, 80, 120, 180 m AGL) werden Windvektoren interpoliert. Außerhalb bekannter Höhen wird die nächste Schicht konstant fortgesetzt. Außerhalb des geladenen Ausschnitts oder bei fehlenden Daten gibt es keinen Windeinfluss. Keine zusätzlichen künstlichen Böen und keine Berechnung von Gebäudeverwirbelungen, Thermik oder kleinräumiger Geländeströmung.",
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
