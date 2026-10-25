import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'offline_map_store.dart';
import 'offline_region.dart';

class OfflineRegionsSection extends StatefulWidget {
  const OfflineRegionsSection({
    super.key,
    this.latitude = 46.8,
    this.longitude = 8.3,
    required this.cachedMaps,
    required this.onCachedMaps,
    this.enabled = true,
    this.storage,
    this.onChanged,
  });
  final double latitude, longitude;
  final bool cachedMaps, enabled;
  final ValueChanged<bool> onCachedMaps;
  final OfflineMapStorage? storage;
  final ValueChanged<OfflineRegion?>? onChanged;
  @override
  State<OfflineRegionsSection> createState() => _OfflineRegionsSectionState();
}

class _OfflineRegionsSectionState extends State<OfflineRegionsSection> {
  late final _store = widget.storage ?? openOfflineMapStore();
  late final _latitude = TextEditingController(
        text: widget.latitude.toStringAsFixed(5),
      ),
      _longitude = TextEditingController(
        text: widget.longitude.toStringAsFixed(5),
      );
  final _name = TextEditingController(text: 'Offline region');
  List<OfflineRegion> _regions = [];
  List<OfflineTileInfo> _tiles = [];
  double _radius = 1;
  int _detail = 14;
  String _style = 'topographic';
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _name.dispose();
    if (widget.storage == null) _store.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final regions = await _store.regions(), tiles = await _store.tiles();
      if (mounted) {
        setState(() {
          _regions = regions;
          _tiles = tiles;
          _busy = false;
          _error = _store.rendererReady ? null : 'Reload this Web app online to enable its offline map worker. HTTPS or localhost is required.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Offline storage unavailable. Web requires HTTPS or localhost and browser storage access.';
        });
      }
    }
  }

  OfflineRegion _candidate() {
    final lat = double.parse(_latitude.text.replaceAll(',', '.')),
        lon = double.parse(_longitude.text.replaceAll(',', '.'));
    final dy = _radius / 111.195, dx = dy / math.cos(lat * math.pi / 180);
    return OfflineRegion(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      west: lon - dx,
      east: lon + dx,
      south: lat - dy,
      north: lat + dy,
      style: _style,
      imageryLevel: _detail,
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final region = _candidate();
      await _store.setRegions([..._regions, region]);
      widget.onChanged?.call(region);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Choose valid Swiss coordinates and a smaller area; at most 12 regions / 5,000 tiles per region.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    OfflineRegion? estimate;
    try {
      estimate = _candidate();
    } catch (_) {}
    final size = _tiles.fold<int>(0, (total, t) => total + t.bytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offline map regions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Store supported swisstopo map and terrain tiles while exploring selected areas online. This is a viewed-tile cache; saved areas can remain incomplete. Satellite imagery and live overlays are excluded.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use cached base map and terrain'),
          subtitle: const Text(
            'Missing tiles remain unavailable. Live data layers and API actions are separate and may still use the network.',
          ),
          value: widget.cachedMaps,
          onChanged: widget.enabled && !_busy && _store.rendererReady
              ? widget.onCachedMaps
              : null,
        ),
        Text(
          'Retained map data: ${(size / 1048576).toStringAsFixed(1)} / 256 MiB',
        ),
        const Text(
          '© swisstopo · OGD terms. Retrieval age is not an official publication date. Cached maps do not supply live airspace, traffic or weather information.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextButton.icon(
          onPressed: widget.enabled && !_busy ? _load : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh storage status'),
        ),
        for (final region in _regions) _region(region),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Add offline region'),
          children: [
            TextField(
              controller: _name,
              enabled: widget.enabled && !_busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Region name'),
            ),
            TextField(
              controller: _latitude,
              enabled: widget.enabled && !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Centre latitude'),
            ),
            TextField(
              controller: _longitude,
              enabled: widget.enabled && !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Centre longitude'),
            ),
            Text('Half-width around centre: ${_radius.toStringAsFixed(1)} km'),
            Slider(
              value: _radius,
              min: .25,
              max: 5,
              divisions: 19,
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _radius = v)
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _style,
              decoration: const InputDecoration(labelText: 'Supported map'),
              items: const [
                DropdownMenuItem(
                  value: 'topographic',
                  child: Text('Topographic'),
                ),
                DropdownMenuItem(value: 'relief', child: Text('Relief')),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _style = v!)
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _detail,
              decoration: const InputDecoration(
                labelText: 'Maximum imagery detail',
              ),
              items: [
                for (final level in [12, 13, 14, 15, 16, 17])
                  DropdownMenuItem(value: level, child: Text('Zoom $level')),
              ],
              onChanged: widget.enabled && !_busy
                  ? (v) => setState(() => _detail = v!)
                  : null,
            ),
            if (estimate != null)
              Text(
                'Estimated full-area download/storage: ${(estimate.estimatedBytes / 1048576).toStringAsFixed(1)} MiB · ${estimate.expectedTiles} tiles. Actual size varies; overlapping regions share tiles.',
              ),
            FilledButton.icon(
              onPressed: widget.enabled && !_busy && estimate != null
                  ? _save
                  : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Save region for caching'),
            ),
            const Text(
              'After saving, choose this map style and explore the region at the selected detail. Refresh storage status to see coverage. Terrain needs close views too. There is no bulk tile download.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _region(OfflineRegion region) {
    final tiles = _tiles.where((t) => region.includesKey(t.key)).toList();
    final size = tiles.fold<int>(0, (n, t) => n + t.bytes);
    final oldest = tiles.isEmpty
        ? null
        : tiles.map((t) => t.fetchedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final stale =
        oldest != null &&
        DateTime.now().toUtc().difference(oldest) > const Duration(days: 30);
    return ListTile(
      onTap: widget.enabled && !_busy
          ? () => widget.onChanged?.call(region)
          : null,
      contentPadding: EdgeInsets.zero,
      title: Text(region.name),
      subtitle: Text(
        '${tiles.length} / ${region.expectedTiles} tiles · ${(size / 1048576).toStringAsFixed(1)} MiB\n'
        '${tiles.length >= region.expectedTiles ? 'Stored area' : 'Partial cache — missing tiles'} · ${region.style}\n'
        '${oldest == null ? 'Not downloaded' : '${stale ? 'Outdated cache' : 'Cached snapshot'} · oldest retrieval ${oldest.toIso8601String()}'}',
      ),
      trailing: IconButton(
        tooltip: 'Remove cached region',
        icon: const Icon(Icons.delete_outline),
        onPressed: widget.enabled && !_busy
            ? () async {
                setState(() => _busy = true);
                try {
                  await _store.setRegions(
                    _regions.where((r) => r.id != region.id).toList(),
                  );
                  widget.onChanged?.call(null);
                  await _load();
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      _busy = false;
                      _error = 'Unable to remove cached region';
                    });
                  }
                }
              }
            : null,
      ),
    );
  }
}
