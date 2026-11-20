import 'dart:async';

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
            ? context.localized(
                "Wind im Flug",
                (l10n) => l10n.weatherWindImFlugeffc2149,
              )
            : context.localized(
                "3D-Wind und Prognose",
                (l10n) => l10n.weatherDWindUndPrognose6efb0829,
              ),
      ),
      subtitle: Text(
        globe.wind.snapshot == null
            ? context.localized(
                "Optional · Winddaten noch nicht geladen",
                (l10n) => l10n.weatherOptionalWinddatenNochNicht638f2548,
              )
            : globe.wind.expired
            ? context.localized(
                "Winddaten abgelaufen",
                (l10n) => l10n.weatherWinddatenAbgelaufend96548ce,
              )
            : globe.wind.affectFlight
            ? context.localized(
                "Wind beeinflusst den Simulator",
                (l10n) => l10n.weatherWindBeeinflusstDenSimulator0792a00b,
              )
            : globe.wind.visible
            ? context.localized(
                "3D-Pfeile aktiv",
                (l10n) => l10n.weatherDPfeileAktivbfcd3c26,
              )
            : context.localized(
                "Winddarstellung und Einfluss aus",
                (l10n) => l10n.weatherWinddarstellungUndEinflussAus5d5ce187,
              ),
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
  final Map<String, double> _environmentDraft = {};

  String _windText(String german, String english) =>
      Localizations.localeOf(context).languageCode == 'de' ? german : english;

  Widget _environmentSlider({
    required String key,
    required String titleDe,
    required String titleEn,
    required double max,
    double min = 0,
    int divisions = 20,
    int decimals = 1,
  }) {
    final wind = widget.globe.wind;
    final value =
        _environmentDraft[key] ?? (wind.environment[key] as num).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_windText(titleDe, titleEn)}: ${value.toStringAsFixed(decimals)}',
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(decimals),
          onChanged: (v) => setState(() {
            _environmentDraft[key] = v;
          }),
          onChangeEnd: (v) {
            setState(() {
              _environmentDraft.remove(key);
            });
            unawaited(wind.updateEnvironment({key: v}));
          },
        ),
      ],
    );
  }

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
                title: Text(
                  context.localized(
                    "3D-Wind und Flugwind",
                    (l10n) => l10n.weatherDWindUndFlugwinda2d72644,
                  ),
                ),
                trailing: IconButton(
                  tooltip: context.localized(
                    "Schließen",
                    (l10n) => l10n.commonSchliessen44424b18,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.localized(
                    "3D-Windpfeile anzeigen",
                    (l10n) => l10n.weatherDWindpfeileAnzeigenbc5f17dc,
                  ),
                ),
                value: wind.visible,
                onChanged: (v) => wind.flags(arrows: v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.localized(
                    "Wind im Flugsimulator berücksichtigen",
                    (l10n) =>
                        l10n.weatherWindImFlugsimulatorBeruecksichtigen2a47223c,
                  ),
                ),
                subtitle: Text(
                  context.localized(
                    "Angle/Acro: Abdrift. GPS: Gegenhalten bis zur Leistungsgrenze.",
                    (l10n) => l10n.weatherAngleAcroAbdriftGps88b761bf,
                  ),
                ),
                value: wind.affectFlight,
                onChanged: (v) => wind.flags(physics: v),
              ),
              DropdownButtonFormField<WindTimeMode>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: context.localized(
                    "Windquelle / Zeit",
                    (l10n) => l10n.weatherWindquelleZeitfc844a65,
                  ),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: WindTimeMode.current,
                    child: Text(
                      context.localized(
                        "Aktueller Modellwind",
                        (l10n) => l10n.weatherAktuellerModellwind402bf323,
                      ),
                    ),
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
                  labelText: context.localized(
                    "Ausschnitt um den gewählten Punkt",
                    (l10n) => l10n.weatherAusschnittUmDenGewaehlten25af0329,
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
                context.localized(
                  "Beim Abruf werden die gewählten Kartenkoordinaten an Open-Meteo gesendet. „Aktuell“ sind Modellwerte, keine Live-Messung vor Ort. Daten und Auswahl gelten für diese Sitzung.",
                  (l10n) => l10n.commonBeimAbrufWerdenDiecd3b9e12,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: wind.loading || _locating ? null : _load,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  context.localized(
                    "Winddaten für Punkt / Ansicht laden",
                    (l10n) => l10n.weatherWinddatenFuerPunktAnsichtfa5e2d66,
                  ),
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
                  context.localizedWithArgs(
                    "Abgerufen: {0} · {1}/9 Rasterpunkte",
                    [time(field.retrievedUtc), field.usableNodes],
                    (l10n, value) => l10n.weatherAbgerufenRasterpunkte7532c53d(
                      value(0),
                      value(1),
                    ),
                  ),
                ),
                if (wind.expired)
                  Text(
                    (wind.environment['fallbackSpeedMs'] as num) > 0
                        ? _windText(
                            'Wetterdaten abgelaufen: Der konfigurierte Ersatzwind bleibt aktiv; Windpfeile sind ausgesetzt.',
                            'Weather data expired: configured fallback wind remains active; wind arrows are suspended.',
                          )
                        : context.localized(
                            'Abgelaufen: Pfeile und Windeinfluss sind ausgesetzt.',
                            (l10n) => l10n
                                .weatherAbgelaufenPfeileUndWindeinfluss1572fe42,
                          ),
                  ),
                if (wind.visible && wind.rendererState == 'terrainPending')
                  Text(
                    context.localized(
                      "Windpfeile warten auf geladenes 3D-Gelände.",
                      (l10n) =>
                          l10n.weatherWindpfeileWartenAufGeladenes9bd078a7,
                    ),
                  ),
                if (wind.refreshFailed)
                  Text(
                    context.localized(
                      "Letzte Aktualisierung fehlgeschlagen. Die vorherigen Daten bleiben bis zum Ablauf verfügbar.",
                      (l10n) => l10n
                          .weatherLetzteAktualisierungFehlgeschlagenDie140dfc53,
                    ),
                  ),
                TextButton.icon(
                  onPressed: wind.loading ? null : wind.refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    context.localized(
                      "Diesen Ausschnitt aktualisieren",
                      (l10n) =>
                          l10n.weatherDiesenAusschnittAktualisierenf0435deb,
                    ),
                  ),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  _windText(
                    'Regionale Wind- und Geländeeffekte',
                    'Regional wind and terrain effects',
                  ),
                ),
                subtitle: Text(
                  _windText(
                    'Simulationsannahmen außerhalb lokaler Wetterdaten',
                    'Simulation assumptions beyond local weather data',
                  ),
                ),
                children: [
                  Text(
                    _windText(
                      'Im geladenen Wetterraster gelten die Windmodelldaten. '
                          'Außerhalb wird der Randwind über 3 km in einen approximierten '
                          'regionalen Verlauf überführt. Bei fehlenden oder abgelaufenen '
                          'Daten gilt der eingestellte Ersatzwind; 0 m/s bedeutet Windstille.',
                      'Inside the loaded grid, model wind takes precedence. Beyond '
                          'the grid, the boundary wind blends over 3 km into an '
                          'estimated regional flow. Missing or expired data uses the '
                          'configured fallback wind; 0 m/s means calm air.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _environmentSlider(
                    key: 'regionalVariation',
                    titleDe: 'Regionale Variation',
                    titleEn: 'Regional variation',
                    max: .5,
                    divisions: 20,
                    decimals: 2,
                  ),
                  _environmentSlider(
                    key: 'altitudeShearExponent',
                    titleDe: 'Höhenabhängige Windzunahme',
                    titleEn: 'Altitude wind shear exponent',
                    max: .5,
                    divisions: 20,
                    decimals: 2,
                  ),
                  _environmentSlider(
                    key: 'gustSpeedMs',
                    titleDe: 'Böenstärke (m/s)',
                    titleEn: 'Gust strength (m/s)',
                    max: 20,
                  ),
                  _environmentSlider(
                    key: 'turbulenceIntensity',
                    titleDe: 'Turbulenz (0–1)',
                    titleEn: 'Turbulence (0–1)',
                    max: 1,
                    divisions: 20,
                    decimals: 2,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _windText(
                        'Hangaufwind / Ridge Lift',
                        'Ridge lift (approximation)',
                      ),
                    ),
                    value: wind.environment['ridgeLift'] == true,
                    onChanged: (v) =>
                        unawaited(wind.updateEnvironment({'ridgeLift': v})),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _windText(
                        'Lee-Abwind und -Turbulenz',
                        'Lee-side sink and turbulence',
                      ),
                    ),
                    value: wind.environment['leeTurbulence'] == true,
                    onChanged: (v) =>
                        unawaited(wind.updateEnvironment({'leeTurbulence': v})),
                  ),
                  _environmentSlider(
                    key: 'fallbackSpeedMs',
                    titleDe: 'Ersatzwind bei Datenlücken (m/s)',
                    titleEn: 'Fallback wind without data (m/s)',
                    max: 30,
                  ),
                  _environmentSlider(
                    key: 'fallbackFromDegrees',
                    titleDe: 'Ersatzwind aus Richtung (Grad)',
                    titleEn: 'Fallback wind from (degrees)',
                    max: 360,
                    divisions: 36,
                    decimals: 0,
                  ),
                  Text(
                    _windText(
                      'Geländeeffekte nutzen lokale Terrain-Höhenproben und sind '
                          'keine Windfeldberechnung. Fehlende Terrainsamples deaktivieren '
                          'nur den jeweiligen Effekt; die Basisströmung bleibt erhalten.',
                      'Terrain effects use nearby height samples, not CFD. '
                          'Missing terrain disables only the corresponding effect, '
                          'not the base wind.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.localized(
                    "Daten und Grenzen",
                    (l10n) => l10n.weatherDatenUndGrenzen98079772,
                  ),
                ),
                children: [
                  Text(
                    _windText(
                      'Open-Meteo · CC BY 4.0. Die 3×3-Windkarte enthält Modellwerte '
                          'für 10/80/120/180 m AGL, keine Live-Messungen. '
                          'Außerhalb des Ausschnitts werden Werte nur approximiert und '
                          'nicht als Open-Meteo-Prognose ausgegeben. Böen und '
                          'Geländeeffekte sind optionale deterministische Simulationen. '
                          'Darstellungspfeile bleiben auf den geladenen Ausschnitt begrenzt.',
                      'Open-Meteo · CC BY 4.0. The 3×3 grid provides modeled wind '
                          'at 10/80/120/180 m AGL, not live readings. Outside the '
                          'grid, values are estimated and must not be treated as an '
                          'Open-Meteo forecast. Gusts and terrain effects are optional '
                          'deterministic approximations. Arrows remain inside the loaded grid.',
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
