import 'dart:async';

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
              'Official MeteoSwiss pollen stations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Measured hourly station averages (No/m³, pollen grains per cubic metre); not a forecast or an exposure estimate at the selected spot.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatic observations (from 2023) and historical manual measurements are separate methods. Historical/manual series are not loaded here.',
            ),
            const SizedBox(height: 8),
            if (widget.latitude == null || widget.longitude == null)
              const Text(
                'Choose a saved flying spot or a globe coordinate to inspect nearby monitoring stations.',
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _discover(),
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Find monitoring stations'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _discover(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh station metadata'),
                  ),
                ],
              ),
              if (_near.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _service.stationMetadataRefreshFailed
                      ? 'Station directory: cached; last metadata refresh failed (original publication time unavailable).'
                      : _service.stationMetadataFromCache
                      ? 'Station directory: locally cached (original publication time unavailable).'
                      : 'Station directory: retrieved ${_service.stationMetadataCheckedUtc?.toUtc().toIso8601String() ?? 'time unknown'}',
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(
                    'pollen-stations-${widget.latitude}-${widget.longitude}',
                  ),
                  initialValue: _selected?.id,
                  decoration: const InputDecoration(
                    labelText: 'Nearest monitoring station',
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
                    'Station ${station.id}${station.canton == null ? '' : ' · ${station.canton}'} · ${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}',
                  ),
                  if (station.detailsUrl != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        station.detailsUrl!,
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('MeteoSwiss station details'),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _fetch,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Load hourly observations'),
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
                'Data state: $freshnessLabel${snapshot.fromCache ? ' · cached' : ''}${snapshot.refreshFailed ? ' · refresh failed' : ''}',
              ),
              Text('Retrieved: ${_utc(snapshot.fetchedUtc)}'),
              Text(
                snapshot.publishedUtc == null
                    ? 'Source publication time: not provided'
                    : 'Source STAC updated: ${_utc(snapshot.publishedUtc!)}',
              ),
              Text(
                latest == null
                    ? 'No valid automatic observations published in this file.'
                    : 'Latest station observation: ${_utc(latest.timeUtc)} · ${latest.method.name} · hourly average',
              ),
              if (snapshot.samples.length > 1)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey(
                    'pollen-sample-${snapshot.fetchedUtc.toIso8601String()}',
                  ),
                  initialValue: _sampleIndex,
                  decoration: const InputDecoration(
                    labelText: 'Inspect hourly observation (UTC)',
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
                Text('Selected observation: ${_utc(displayed.timeUtc)}'),
                for (final taxon in PollenTaxon.values)
                  Text(
                    '${taxon.label}: ${displayed.values[taxon]?.toStringAsFixed(0) ?? 'missing / unknown'}${displayed.values[taxon] == null ? '' : ' No/m³'}',
                  ),
              ],
              if (snapshot.unknownParameters.isNotEmpty)
                Text(
                  'Unsupported source parameters not classified: ${snapshot.unknownParameters.join(', ')}',
                ),
              const Text(
                'No official severity classes are inferred. Missing is not zero. Readings describe the monitoring station only.',
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Source: MeteoSwiss · FSDI STAC · Swiss pollen monitoring network. Coverage is limited to published stations. Data are observations, not medical advice.',
            ),
          ],
        ),
      ),
    );
  }
}
