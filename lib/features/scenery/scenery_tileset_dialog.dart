import 'package:flutter/material.dart';

import 'scenery_manifest.dart';
import 'scenery_tileset_options.dart';

typedef SceneryTilesetProbe = Future<Map<String, dynamic>> Function(
  String url,
  String cachePolicy,
);

class SceneryTilesetDialog extends StatefulWidget {
  const SceneryTilesetDialog({
    super.key,
    required this.probe,
    required this.german,
    this.existing,
  });
  final SceneryTilesetProbe probe;
  final bool german;
  final SceneryManifest? existing;
  @override
  State<SceneryTilesetDialog> createState() => _SceneryTilesetDialogState();
}

class _SceneryTilesetDialogState extends State<SceneryTilesetDialog> {
  final _fields = <String, TextEditingController>{};
  Map<String, dynamic>? _metadata;
  String _cache = 'no-store', _checkedUrl = '';
  bool _checking = false;
  String? _error;
  int _revision = 0;
  String t(String de, String en) => widget.german ? de : en;
  @override
  void initState() {
    super.initState();
    final doc = widget.existing?.toJson(),
        asset = doc == null
            ? null
            : (doc['assets'] as List).cast<Map>().firstWhere(
                (a) => a['provider'] == remoteTilesetProvider,
              );
    final options = asset?['tileset'] as Map?,
        source = doc?['source'] as Map?,
        anchor = doc?['anchor'] as Map?,
        visibility = doc?['visibility'] as Map?;
    final values = <String, Object?>{
      'url': asset?['uri'] ?? '',
      'name': doc?['name'] ?? '',
      'description': doc?['description'] ?? '',
      'author': source?['author'] ?? 'External provider',
      'sourceUrl': source?['url'] ?? '',
      'license': source?['license'] ?? 'Unspecified',
      'attribution': source?['attribution'] ?? 'External provider',
      'maximumScreenSpaceError': options?['maximumScreenSpaceError'] ?? 16,
      'loadRadiusM': visibility?['loadRadiusM'] ?? 2500,
      'unloadRadiusM': visibility?['unloadRadiusM'] ?? 4000,
      'longitude': anchor?['longitude'] ?? 0,
      'latitude': anchor?['latitude'] ?? 0,
      'heightM': anchor?['heightM'] ?? 0,
      for (final key in [
        'eastM',
        'northM',
        'upM',
        'headingDeg',
        'pitchDeg',
        'rollDeg',
        'scale',
      ])
        key: (options?['correction'] as Map?)?[key] ?? (key == 'scale' ? 1 : 0),
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: '${e.value}');
    }
    if (doc != null) {
      _cache = options!['cachePolicy'] as String;
      _checkedUrl = asset!['uri'] as String;
      _metadata = {
        'version': options['version'],
        'boundingSphere': options['boundingSphere'],
        'anchor': anchor,
        'bounds': doc['bounds'],
      };
    }
  }

  @override
  void dispose() {
    _revision++;
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _example() {
    for (final e in {
      'url': 'https://isk.geobasis-bb.de/geodienste/lgb/3d_sentinel/3dmeshes/tileset.json',
      'name': 'Brandenburg 3D Mesh',
      'author': 'Landesvermessung und Geobasisinformation Brandenburg (LGB)',
      'sourceUrl': 'https://www.distributions.informationgrid.eu/trefferanzeige?docuuid=f5a6d881-f36a-473c-a33a-4c1d1f982cf5',
      'license': 'Datenlizenz Deutschland – Namensnennung – Version 2.0',
      'attribution': '© GeoBasis-DE/LGB, dl-de/by-2-0 (Daten geändert)',
    }.entries) {
      _fields[e.key]!.text = e.value;
    }
    setState(() {
      _metadata = null;
      _checkedUrl = '';
      _error = null;
    });
  }

  Future<void> _check() async {
    final revision = ++_revision;
    String url;
    try {
      url = validateTilesetUrl(_fields['url']!.text.trim());
      _fields['url']!.text = url;
    } catch (error) {
      setState(() => _error = error.toString());
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _metadata = null;
    });
    try {
      final metadata = await widget.probe(url, _cache);
      if (!mounted ||
          revision != _revision ||
          _fields['url']!.text.trim() != url) {
        return;
      }
      validateTilesetOptions({
        'version': metadata['version'],
        'boundingSphere': metadata['boundingSphere'],
        'cachePolicy': _cache,
        'maximumScreenSpaceError': 16,
      });
      setState(() {
        _metadata = metadata;
        _checkedUrl = url;
        final anchor = metadata['anchor'] as Map;
        for (final key in ['longitude', 'latitude', 'heightM']) {
          _fields[key]!.text = '${anchor[key]}';
        }
        if (_fields['name']!.text.trim().isEmpty) {
          _fields['name']!.text = '${Uri.parse(url).host} 3D Tiles';
        }
        if (_fields['sourceUrl']!.text.trim().isEmpty) {
          _fields['sourceUrl']!.text = Uri.parse(url).origin;
        }
        if (metadata['copyright'] is String &&
            _fields['attribution']!.text == 'External provider') {
          _fields['attribution']!.text = metadata['copyright'] as String;
        }
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _checking = false);
    }
  }

  void _save() {
    try {
      final url = validateTilesetUrl(_fields['url']!.text.trim());
      if (_metadata == null || url != _checkedUrl) {
        throw const FormatException('Check the current URL before saving');
      }
      double number(String key) =>
          double.parse(_fields[key]!.text.replaceAll(',', '.'));
      final sourceUrl = _fields['sourceUrl']!.text.trim();
      final previous = widget.existing?.toJson();
      final previousAssets = (previous?['assets'] as List?) ?? [];
      final edited = previousAssets
          .cast<Map>()
          .where((a) => a['provider'] == remoteTilesetProvider)
          .firstOrNull;
      final manifest = SceneryManifest.fromJson({
        ...?previous,
        'schemaVersion': 1,
        'id':
            widget.existing?.id ??
            'scenery-${DateTime.now().microsecondsSinceEpoch}',
        'name': _fields['name']!.text.trim(),
        'description': _fields['description']!.text,
        'source': {
          'author': _fields['author']!.text.trim(),
          'url': sourceUrl.isEmpty ? null : sourceUrl,
          'license': _fields['license']!.text.trim(),
          'attribution': _fields['attribution']!.text.trim(),
        },
        'anchor': {
          'longitude': number('longitude'),
          'latitude': number('latitude'),
          'heightM': number('heightM'),
          'reference': 'WGS84_ELLIPSOID',
        },
        'bounds': _metadata!['bounds'],
        'rotation':
            previous?['rotation'] ??
            {'headingDeg': 0, 'pitchDeg': 0, 'rollDeg': 0},
        'scale': previous?['scale'] ?? 1,
        'assets': [
          for (final asset in previousAssets)
            if ((asset as Map)['id'] != edited?['id']) asset,
          {
            'id': edited?['id'] ?? 'visual',
            'provider': remoteTilesetProvider,
            'format': remoteTilesetFormat,
            'role': 'visual',
            'uri': url,
            'tileset': {
              'version': _metadata!['version'],
              'boundingSphere': _metadata!['boundingSphere'],
              'maximumScreenSpaceError': number('maximumScreenSpaceError'),
              'cachePolicy': _cache,
              'correction': {
                for (final key in [
                  'eastM',
                  'northM',
                  'upM',
                  'headingDeg',
                  'pitchDeg',
                  'rollDeg',
                  'scale',
                ])
                  key: number(key),
              },
            },
          },
        ],
        'collision':
            previous?['collision'] ??
            {'enabled': false, 'assetIds': <String>[], 'sidedness': 'double'},
        'visibility': {
          'enabled': widget.existing?.enabled ?? true,
          'loadRadiusM': number('loadRadiusM'),
          'unloadRadiusM': number('unloadRadiusM'),
        },
        'minimumAppVersion': previous?['minimumAppVersion'] ?? '0.20.0',
      });
      Navigator.pop(context, manifest);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Widget _field(String key, String label, {bool numeric = false}) => TextField(
    key: ValueKey('tileset-$key'),
    controller: _fields[key],
    enabled: !_checking,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    onChanged: key == 'url'
        ? (_) => setState(() {
            _metadata = null;
            _checkedUrl = '';
          })
        : null,
    decoration: InputDecoration(labelText: label),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? t('3D-Tiles-Anbieter hinzufügen', 'Add 3D Tiles provider')
          : t('3D-Tiles-Anbieter bearbeiten', 'Edit 3D Tiles provider'),
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(
                'Online-Dienst, rein visuell. Die Georeferenzierung bleibt erhalten. Keine Aufnahme in Offlinepakete.',
                'Online visual service. Original georeferencing is preserved. Provider data is not included in offline packages.',
              ),
            ),
            _field('url', t('Tileset-URL (HTTPS)', 'Tileset URL (HTTPS)')),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _checking ? null : _example,
                  child: Text(t('Brandenburg-Beispiel', 'Brandenburg example')),
                ),
                FilledButton(
                  key: const ValueKey('tileset-check'),
                  onPressed: _checking ? null : _check,
                  child: Text(t('Anbieter prüfen', 'Check provider')),
                ),
              ],
            ),
            if (_checking) const LinearProgressIndicator(),
            if (_metadata != null)
              Text(
                '3D Tiles ${_metadata!['version']} · ${t('Georeferenzierung geprüft', 'Georeferencing checked')}',
              ),
            for (final e in {
              'name': t('Name', 'Name'),
              'description': t('Beschreibung', 'Description'),
              'author': t('Anbieter / Autor', 'Provider / author'),
              'sourceUrl': t(
                'Quelle / Nutzungsbedingungen (HTTPS)',
                'Source / usage terms (HTTPS)',
              ),
              'license': t('Lizenz', 'License'),
              'attribution': t('Quellenangabe', 'Attribution'),
            }.entries)
              _field(e.key, e.value),
            _field(
              'maximumScreenSpaceError',
              t(
                'Max. Screen-Space-Error (Pixel; kleiner = feiner)',
                'Maximum screen-space error (pixels; lower = finer)',
              ),
              numeric: true,
            ),
            _field(
              'loadRadiusM',
              t(
                'Ladeabstand zum Datensatz (m)',
                'Loading distance from dataset (m)',
              ),
              numeric: true,
            ),
            _field(
              'unloadRadiusM',
              t(
                'Entladeabstand zum Datensatz (m)',
                'Unloading distance from dataset (m)',
              ),
              numeric: true,
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _cache,
              decoration: InputDecoration(
                labelText: t('Cache-Richtlinie', 'Caching policy'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'no-store',
                  child: Text(
                    t(
                      'Nur Laufzeit, kein Browser-Diskcache',
                      'Runtime only, no browser disk cache',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'provider',
                  child: Text(
                    t(
                      'HTTP-Cache gemäß Anbieterregeln',
                      'HTTP cache according to provider rules',
                    ),
                  ),
                ),
              ],
              onChanged: _checking
                  ? null
                  : (value) {
                      if (value != null) setState(() => _cache = value);
                    },
            ),
            ExpansionTile(
              title: Text(
                t('Optionale Lagekorrektur', 'Optional positioning correction'),
              ),
              children: [
                Text(
                  t(
                    'Nullversatz, Nullrotation und Maßstab 1 erhalten die ursprüngliche Lage. Der Referenzpunkt ist nur der Dreh-/Skalierpunkt.',
                    'Zero offsets/rotation and scale 1 retain the original placement. The reference is only the rotation/scale pivot.',
                  ),
                ),
                for (final e in {
                  'longitude': t('Referenz-Längengrad', 'Pivot longitude'),
                  'latitude': t('Referenz-Breitengrad', 'Pivot latitude'),
                  'heightM': t(
                    'Referenzhöhe (WGS84-Ellipsoid, m)',
                    'Pivot height (WGS84 ellipsoid, m)',
                  ),
                  'eastM': t('Ostversatz (m)', 'East offset (m)'),
                  'northM': t('Nordversatz (m)', 'North offset (m)'),
                  'upM': t('Höhenversatz (m)', 'Up offset (m)'),
                  'headingDeg': t('Richtung (°)', 'Heading (°)'),
                  'pitchDeg': t('Neigung (°)', 'Pitch (°)'),
                  'rollDeg': t('Rollwinkel (°)', 'Roll (°)'),
                  'scale': t('Maßstab', 'Scale'),
                }.entries)
                  _field(e.key, e.value, numeric: true),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Abbrechen', 'Cancel')),
      ),
      FilledButton(
        key: const ValueKey('tileset-save'),
        onPressed: _checking ? null : _save,
        child: Text(t('Speichern', 'Save')),
      ),
    ],
  );
}
