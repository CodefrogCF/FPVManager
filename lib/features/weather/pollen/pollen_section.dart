import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/osint/osint_dataset.dart';
import 'pollen_models.dart';
import 'pollen_service.dart';

/// Station-based pollen observations, independent from weather forecasts.
class PollenSection extends StatefulWidget {
  const PollenSection({
    super.key,
    required this.latitude,
    required this.longitude,
    this.service,
  });
  final double? latitude;
  final double? longitude;
  final PollenService? service;

  @override
  State<PollenSection> createState() => _PollenSectionState();
}

class _PollenSectionState extends State<PollenSection> {
  PollenService? _ownedService;
  PollenService get _service =>
      widget.service ?? (_ownedService ??= PollenService());
  List<PollenStation> _near = const [];
  PollenStation? _selected;
  PollenSnapshot? _snapshot;
  int _sampleIndex = 0;
  bool _busy = false;
  String? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant PollenSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.service != widget.service) {
      _generation++;
      _near = [];
      _selected = null;
      _snapshot = null;
      _sampleIndex = 0;
      _busy = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    if (_ownedService != null) {
      unawaited(_ownedService!.dispose());
    }
    super.dispose();
  }

  Future<void> _discover({bool refresh = false}) async {
    final lat = widget.latitude, lon = widget.longitude;
    if (lat == null || lon == null || _busy) {
      return;
    }
    final op = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stations = await _service.stations(refresh: refresh);
      if (!mounted || op != _generation) {
        return;
      }
      final nearest = _service.nearest(stations, lat, lon);
      final selection = nearest.isEmpty ? null : nearest.first;
      setState(() {
        _near = nearest;
        _selected = selection;
        _snapshot = null;
        _sampleIndex = 0;
      });
      if (selection != null) {
        await _readOffline(selection, op);
      }
    } catch (error) {
      if (mounted && op == _generation) {
        setState(() => _error = 'Pollen stations unavailable: $error');
      }
    } finally {
      if (mounted && op == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _readOffline(PollenStation station, int op) async {
    final saved = await _service.offline(station.id);
    if (mounted && op == _generation && _selected?.id == station.id) {
      setState(() => _snapshot = saved);
    }
  }

  void _select(String id) {
    final station = _near.where((s) => s.id == id).firstOrNull;
    if (station == null) {
      return;
    }
    final op = ++_generation;
    setState(() {
      _selected = station;
      _snapshot = null;
      _sampleIndex = 0;
      _error = null;
    });
    unawaited(_readOffline(station, op));
  }

  Future<void> _fetch() async {
    final station = _selected;
    if (station == null || _busy) {
      return;
    }
    final op = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loaded = await _service.observations(station, refresh: true);
      if (mounted && op == _generation) {
        setState(() {
          _snapshot = loaded;
          _sampleIndex = 0;
        });
      }
    } catch (error) {
      if (mounted && op == _generation) {
        setState(() => _error = 'Pollen observations unavailable: $error');
      }
    } finally {
      if (mounted && op == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  String _utc(DateTime time) => time.toUtc().toIso8601String();

  @override
  Widget build(BuildContext context) {
    final station = _selected;
    final snapshot = _snapshot;
    final freshness = snapshot?.freshnessAt(DateTime.now());
    final freshnessLabel = switch (freshness) {
      OsintFreshness.fresh => 'Within freshness window',
      OsintFreshness.clockSkew => 'Device clock / observation time conflict',
      _ => 'Stale or unavailable',
    };
    final latest = snapshot?.samples.firstOrNull;
    final displayed = snapshot == null || snapshot.samples.isEmpty
        ? null
        : snapshot.samples[_sampleIndex.clamp(0, snapshot.samples.length - 1)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.localized(
                "Official MeteoSwiss pollen stations",
                (l10n) => l10n.weatherOfficialMeteoswissPollenStations0d04b249,
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              context.localized(
                "Measured hourly station averages (No/m³, pollen grains per cubic metre); not a forecast or an exposure estimate at the selected spot.",
                (l10n) => l10n.commonMeasuredHourlyStationAverages6b75bd38,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.localized(
                "Automatic observations (from 2023) and historical manual measurements are separate methods. Historical/manual series are not loaded here.",
                (l10n) => l10n.weatherAutomaticObservationsFromAnda1a45d31,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.latitude == null || widget.longitude == null)
              Text(
                context.localized(
                  "Choose a saved flying spot or a globe coordinate to inspect nearby monitoring stations.",
                  (l10n) => l10n.weatherChooseASavedFlyingba7ecae9,
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _discover(),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(
                      context.localized(
                        "Find monitoring stations",
                        (l10n) => l10n.weatherFindMonitoringStations4d511534,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _discover(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.localized(
                        "Refresh station metadata",
                        (l10n) => l10n.weatherRefreshStationMetadataa5976bc4,
                      ),
                    ),
                  ),
                ],
              ),
              if (_near.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _service.stationMetadataRefreshFailed
                      ? context.localized(
                          "Station directory: cached; last metadata refresh failed (original publication time unavailable).",
                          (l10n) =>
                              l10n.weatherStationDirectoryCachedLastf07e00ef,
                        )
                      : _service.stationMetadataFromCache
                      ? context.localized(
                          "Station directory: locally cached (original publication time unavailable).",
                          (l10n) =>
                              l10n.weatherStationDirectoryLocallyCached005bbea0,
                        )
                      : context.localizedWithArgs(
                          "Station directory: retrieved {0}",
                          [
                            _service.stationMetadataCheckedUtc
                                    ?.toUtc()
                                    .toIso8601String() ??
                                'time unknown',
                          ],
                          (l10n, value) =>
                              l10n.weatherStationDirectoryRetrieved72729476(
                                value(0),
                              ),
                        ),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(
                    'pollen-stations-${widget.latitude}-${widget.longitude}',
                  ),
                  initialValue: _selected?.id,
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Nearest monitoring station",
                      (l10n) => l10n.weatherNearestMonitoringStationb112be37,
                    ),
                  ),
                  items: [
                    for (final s in _near)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.name} (${PollenService.distanceKm(widget.latitude!, widget.longitude!, s).toStringAsFixed(0)} km)',
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (id) {
                          if (id != null) {
                            _select(id);
                          }
                        },
                ),
                if (station != null) ...[
                  Text(
                    context.localizedWithArgs(
                      "Station {0}{1} · {2}, {3}",
                      [
                        station.id,
                        station.canton == null ? '' : ' · ${station.canton}',
                        station.latitude.toStringAsFixed(4),
                        station.longitude.toStringAsFixed(4),
                      ],
                      (l10n, value) => l10n.commonStation5a5e3cd7(
                        value(0),
                        value(1),
                        value(2),
                        value(3),
                      ),
                    ),
                  ),
                  if (station.detailsUrl != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        station.detailsUrl!,
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        context.localized(
                          "MeteoSwiss station details",
                          (l10n) =>
                              l10n.weatherMeteoswissStationDetails565885c8,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _fetch,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(
                      context.localized(
                        "Load hourly observations",
                        (l10n) => l10n.weatherLoadHourlyObservations7bc23c4c,
                      ),
                    ),
                  ),
                ],
              ],
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (snapshot != null) ...[
              const Divider(),
              Text(
                context.localizedWithArgs(
                  "Data state: {0}{1}{2}",
                  [
                    freshnessLabel,
                    snapshot.fromCache ? ' · cached' : '',
                    snapshot.refreshFailed ? ' · refresh failed' : '',
                  ],
                  (l10n, value) => l10n.weatherDataState98888b0e(
                    value(0),
                    value(1),
                    value(2),
                  ),
                ),
              ),
              Text(
                context.localizedWithArgs("Retrieved: {0}", [
                  _utc(snapshot.fetchedUtc),
                ], (l10n, value) => l10n.commonRetrievedc0a8bd29(value(0))),
              ),
              Text(
                snapshot.publishedUtc == null
                    ? context.localized(
                        "Source publication time: not provided",
                        (l10n) => l10n.weatherSourcePublicationTimeNot23697f29,
                      )
                    : context.localizedWithArgs(
                        "Source STAC updated: {0}",
                        [_utc(snapshot.publishedUtc!)],
                        (l10n, value) =>
                            l10n.weatherSourceStacUpdateddde9e800(value(0)),
                      ),
              ),
              Text(
                latest == null
                    ? context.localized(
                        "No valid automatic observations published in this file.",
                        (l10n) =>
                            l10n.weatherNoValidAutomaticObservationse3251aaa,
                      )
                    : context.localizedWithArgs(
                        "Latest station observation: {0} · {1} · hourly average",
                        [_utc(latest.timeUtc), latest.method.name],
                        (l10n, value) =>
                            l10n.weatherLatestStationObservationHourly1d766dcb(
                              value(0),
                              value(1),
                            ),
                      ),
              ),
              if (snapshot.samples.length > 1)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey(
                    'pollen-sample-${snapshot.fetchedUtc.toIso8601String()}',
                  ),
                  initialValue: _sampleIndex,
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Inspect hourly observation (UTC)",
                      (l10n) => l10n.weatherInspectHourlyObservationUtcae90e45a,
                    ),
                  ),
                  items: [
                    for (var i = 0; i < snapshot.samples.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(_utc(snapshot.samples[i].timeUtc)),
                      ),
                  ],
                  onChanged: (index) {
                    if (index != null) {
                      setState(() => _sampleIndex = index);
                    }
                  },
                ),
              if (displayed != null) ...[
                Text(
                  context.localizedWithArgs(
                    "Selected observation: {0}",
                    [_utc(displayed.timeUtc)],
                    (l10n, value) =>
                        l10n.weatherSelectedObservation26593d3f(value(0)),
                  ),
                ),
                for (final taxon in PollenTaxon.values)
                  Text(
                    '${taxon.label}: ${displayed.values[taxon]?.toStringAsFixed(0) ?? 'missing / unknown'}${displayed.values[taxon] == null ? '' : ' No/m³'}',
                  ),
              ],
              if (snapshot.unknownParameters.isNotEmpty)
                Text(
                  context.localizedWithArgs(
                    "Unsupported source parameters not classified: {0}",
                    [snapshot.unknownParameters.join(', ')],
                    (l10n, value) =>
                        l10n.weatherUnsupportedSourceParametersNot75db504a(
                          value(0),
                        ),
                  ),
                ),
              Text(
                context.localized(
                  "No official severity classes are inferred. Missing is not zero. Readings describe the monitoring station only.",
                  (l10n) => l10n.weatherNoOfficialSeverityClasses2d4def34,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.localized(
                "Source: MeteoSwiss · FSDI STAC · Swiss pollen monitoring network. Coverage is limited to published stations. Data are observations, not medical advice.",
                (l10n) => l10n.commonSourceMeteoswissFsdiStac0fd2fd76,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
