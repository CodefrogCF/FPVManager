import 'dart:async';

import 'package:flutter/material.dart';

import 'scenery_manifest.dart';
import 'scenery_asset_provider.dart';
import 'scenery_model_import.dart';
import 'scenery_import_files.dart';
import 'scenery_tileset_dialog.dart';
import 'scenery_tileset_options.dart';

/// Definition management; selecting/importing new asset bytes belongs to the
/// asset provider/import workflow. Existing templates retain their provenance.
class SceneryManagementPage extends StatefulWidget {
  const SceneryManagementPage({
    super.key,
    required this.load,
    required this.templates,
    required this.save,
    required this.remove,
    required this.german,
    this.importModel,
    this.pickImport,
    this.probeTileset,
    this.align,
  });
  final Future<List<SceneryManifest>> Function() load, templates;
  final Future<void> Function(SceneryManifest manifest, bool create) save;
  final Future<void> Function(String id) remove;
  final bool german;
  final Future<void> Function(SceneryManifest, PreparedSceneryModel)?
  importModel;
  final Future<(String, PreparedSceneryModel)?> Function()? pickImport;
  final SceneryTilesetProbe? probeTileset;
  final Future<void> Function(String? id)? align;
  @override
  State<SceneryManagementPage> createState() => _SceneryManagementPageState();
}

class _SceneryManagementPageState extends State<SceneryManagementPage> {
  List<SceneryManifest> _items = [];
  bool _busy = true;
  String? _error;
  String t(String de, String en) => widget.german ? de : en;
  Future<void> _align(String? id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.align!(id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(SceneryManifest? existing) async {
    if (existing?.assets.any((a) => a.provider == remoteTilesetProvider) ==
        true) {
      await _tileset(existing);
      return;
    }
    List<SceneryManifest> templates;
    try {
      templates = existing == null ? await widget.templates() : [existing];
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
      return;
    }
    if (!mounted) return;
    if (templates.isEmpty) {
      setState(
        () => _error = t(
          'Keine Modellvorlage verfügbar.',
          'No model template available.',
        ),
      );
      return;
    }
    final route = DialogRoute<SceneryManifest>(
      context: context,
      builder: (_) => _SceneryDefinitionDialog(
        templates: templates,
        existing: existing,
        german: widget.german,
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(result, existing == null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    final error = _error;
    await _load();
    if (mounted && error != null) setState(() => _error = error);
  }

  Future<void> _remove(SceneryManifest item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Umgebung entfernen?', 'Remove scenery?')),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Abbrechen', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Entfernen', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.remove(item.id);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    final error = _error;
    await _load();
    if (mounted && error != null) setState(() => _error = error);
  }

  String? _progress;
  Future<void> _tileset(SceneryManifest? existing) async {
    if (widget.probeTileset == null) return;
    final route = DialogRoute<SceneryManifest>(
      context: context,
      builder: (_) => SceneryTilesetDialog(
        probe: widget.probeTileset!,
        german: widget.german,
        existing: existing,
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(result, existing == null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    final error = _error;
    await _load();
    if (mounted && error != null) setState(() => _error = error);
  }

  bool _placing = false;
  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = t('Modell auswählen', 'Selecting model');
    });
    try {
      final picked =
          await (widget.pickImport?.call() ??
              pickSceneryModel(
                progress: (stage) {
                  if (mounted) setState(() => _progress = stage);
                },
                requestResource: (uri) async {
                  if (!mounted) return false;
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            t(
                              'Zugehörige Datei auswählen',
                              'Select model resource',
                            ),
                          ),
                          content: Text(
                            t(
                                  'Bitte die zu dieser Modellreferenz gehörende Datei auswählen:\n',
                                  'Select the file belonging to this model reference:\n',
                                ) +
                                uri,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(t('Abbrechen', 'Cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(t('Datei auswählen', 'Select file')),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
              ));
      if (picked == null || !mounted) return;
      final (filename, model) = picked;
      final name = filename.replaceFirst(
        RegExp(r'\.(glb|gltf)$', caseSensitive: false),
        '',
      );
      final draft = SceneryManifest.fromJson({
        'schemaVersion': 1,
        'id': 'scenery-${DateTime.now().microsecondsSinceEpoch}',
        'name': name.length > 120 ? name.substring(0, 120) : name,
        'description': '',
        'source': {
          'author': 'Local import',
          'url': null,
          'license': 'Unspecified',
          'attribution': 'Local import — rights retained by the asset owner',
        },
        'anchor': {
          'longitude': 0,
          'latitude': 0,
          'heightM': 0,
          'reference': 'TERRAIN_RELATIVE',
        },
        'bounds': {'west': 0, 'south': 0, 'east': 0, 'north': 0},
        'rotation': {'headingDeg': 0, 'pitchDeg': 0, 'rollDeg': 0},
        'scale': 1,
        'assets': [
          {
            'id': 'visual',
            'role': 'visual',
            'provider': 'managed',
            'format': 'glb',
            'uri': model.key,
            'model': model.metadata,
          },
        ],
        'collision': {
          'enabled': false,
          'assetIds': <String>[],
          'sidedness': 'double',
        },
        'visibility': {
          'enabled': true,
          'loadRadiusM': 2500,
          'unloadRadiusM': 4000,
        },
        'minimumAppVersion': sceneryApplicationVersion,
      });
      final route = DialogRoute<SceneryManifest>(
        context: context,
        builder: (_) => _SceneryDefinitionDialog(
          templates: [draft],
          existing: draft,
          german: widget.german,
          importing: true,
        ),
      );
      setState(() {
        _placing = true;
        _progress = null;
      });
      final result = await Navigator.of(context).push(route);
      await route.completed;
      if (result == null || !mounted) return;
      setState(() {
        _placing = false;
        _progress = t('Modell speichern', 'Saving model');
      });
      await widget.importModel!(result, model);
      await _load();
    } on SceneryImportCancelled {
      /* No files were committed. */
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _placing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(t('3D-Umgebungen verwalten', 'Manage 3D scenery')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t(
            'Modelle und Ausrichtung werden auf diesem Gerät gespeichert. Lokale Modelle sind rein visuell; Kollisionen benötigen ein separates Modell. Backups enthalten derzeit nur die Definitionen.',
            'Models and placement are saved on this device. Local models are visual only; collisions require separate geometry. Backups currently contain definitions only.',
          ),
        ),
        if (_busy && !_placing) const LinearProgressIndicator(),
        if (_progress != null) Text(_progress!),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _edit(null),
            icon: const Icon(Icons.add),
            label: Text(t('Neue Umgebung', 'New scenery')),
          ),
        ),
        if (widget.importModel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('scenery-import'),
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(t('GLB / glTF importieren', 'Import GLB / glTF')),
            ),
          ),
        if (widget.probeTileset != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('scenery-add-tileset'),
              onPressed: _busy ? null : () => _tileset(null),
              icon: const Icon(Icons.cloud_outlined),
              label: Text(
                t('3D-Tiles-Anbieter hinzufügen', 'Add 3D Tiles provider'),
              ),
            ),
          ),
        if (widget.align != null)
          TextButton.icon(
            onPressed: _busy ? null : () => _align(null),
            icon: const Icon(Icons.touch_app_outlined),
            label: Text(
              t(
                'Im Globus auswählen und ausrichten',
                'Select and align on globe',
              ),
            ),
          ),
        for (final item in _items)
          ListTile(
            title: Text(item.name),
            subtitle: Text(
              '${item.enabled ? t('Aktiviert', 'Enabled') : t('Deaktiviert', 'Disabled')} · ${(item.toJson()['source'] as Map)['attribution']}',
            ),
            onTap: _busy ? null : () => _edit(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.align != null)
                  IconButton(
                    tooltip: t('Im Globus ausrichten', 'Align on globe'),
                    onPressed: _busy ? null : () => _align(item.id),
                    icon: const Icon(Icons.open_with),
                  ),
                IconButton(
                  tooltip: t('Entfernen', 'Remove'),
                  onPressed: _busy ? null : () => _remove(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _SceneryDefinitionDialog extends StatefulWidget {
  const _SceneryDefinitionDialog({
    required this.templates,
    required this.existing,
    required this.german,
    this.importing = false,
  });
  final List<SceneryManifest> templates;
  final SceneryManifest? existing;
  final bool german;
  final bool importing;
  @override
  State<_SceneryDefinitionDialog> createState() =>
      _SceneryDefinitionDialogState();
}

class _SceneryDefinitionDialogState extends State<_SceneryDefinitionDialog> {
  final _fields = <String, TextEditingController>{};
  late SceneryManifest _template;
  late String _reference;
  late bool _collisions;
  String? _error;
  String t(String de, String en) => widget.german ? de : en;
  @override
  void initState() {
    super.initState();
    _setTemplate(widget.existing ?? widget.templates.first);
  }

  void _setTemplate(SceneryManifest template) {
    _template = template;
    final doc = template.toJson(),
        a = doc['anchor'] as Map,
        r = doc['rotation'] as Map,
        v = doc['visibility'] as Map;
    final values = <String, Object?>{
      'id':
          widget.existing?.id ??
          'scenery-${DateTime.now().microsecondsSinceEpoch}',
      'name':
          widget.existing?.name ?? '${template.name} (${t('Kopie', 'copy')})',
      'description': doc['description'],
      ...((doc['source'] as Map).map((k, v) => MapEntry('source-$k', v ?? '')))
          .cast<String, Object?>(),
      'longitude': a['longitude'],
      'latitude': a['latitude'],
      'heightM': a['heightM'],
      ...r.cast<String, Object?>(),
      'scale': doc['scale'],
      'loadRadiusM': v['loadRadiusM'],
      'unloadRadiusM': v['unloadRadiusM'],
    };
    for (final entry in values.entries) {
      (_fields[entry.key] ??= TextEditingController()).text = '${entry.value}';
    }
    _reference = a['reference'] as String;
    _collisions =
        widget.existing != null && (doc['collision'] as Map)['enabled'] == true;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      final doc = _template.toJson();
      double number(String key) =>
          double.parse(_fields[key]!.text.replaceAll(',', '.'));
      doc['id'] = _fields['id']!.text.trim();
      doc['name'] = _fields['name']!.text.trim();
      doc['description'] = _fields['description']!.text;
      if (_template.assets.any((a) => a.provider == 'managed')) {
        doc['source'] = {
          for (final key in ['author', 'license', 'attribution', 'url'])
            key: key == 'url' && _fields['source-$key']!.text.trim().isEmpty
                ? null
                : _fields['source-$key']!.text.trim(),
        };
      }
      doc['anchor'] = {
        'longitude': number('longitude'),
        'latitude': number('latitude'),
        'heightM': number('heightM'),
        'reference': _reference,
      };
      doc['rotation'] = {
        for (final key in ['headingDeg', 'pitchDeg', 'rollDeg'])
          key: number(key),
      };
      doc['scale'] = number('scale');
      (doc['collision'] as Map)['enabled'] = _collisions;
      (doc['visibility'] as Map).addAll(<String, dynamic>{
        'loadRadiusM': number('loadRadiusM'),
        'unloadRadiusM': number('unloadRadiusM'),
      });
      doc['bounds'] = sceneryCoverageBounds(
        number('longitude'),
        number('latitude'),
        number('unloadRadiusM'),
      );
      if (widget.existing == null) {
        // Reusing visual data at another location does not transfer certified
        // terrain replacement patches or their provider-specific calibration.
        doc['extensions'] = <String, dynamic>{};
        (doc['visibility'] as Map)['enabled'] = false;
      }
      Navigator.pop(context, SceneryManifest.fromJson(doc));
    } catch (error) {
      setState(
        () => _error = t('Werte prüfen: ', 'Check values: ') + error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.importing
          ? t('Modell platzieren', 'Place model')
          : widget.existing == null
          ? t('Neue Umgebung', 'New scenery')
          : t('Umgebung bearbeiten', 'Edit scenery'),
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.existing == null)
              DropdownButtonFormField<String>(
                initialValue: _template.id,
                decoration: InputDecoration(
                  labelText: t('Modellvorlage', 'Model template'),
                ),
                items: [
                  for (final template in widget.templates)
                    DropdownMenuItem(
                      value: template.id,
                      child: Text(
                        template.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) {
                    setState(
                      () => _setTemplate(
                        widget.templates.firstWhere((m) => m.id == id),
                      ),
                    );
                  }
                },
              ),
            for (final entry in <String, String>{
              'name': t('Name', 'Name'),
              'description': t('Beschreibung', 'Description'),
              if (_template.assets.any((a) => a.provider == 'managed')) ...{
                'source-author': t('Autor / Quelle', 'Author / source'),
                'source-url': t(
                  'Quellen-URL (optional, HTTPS)',
                  'Source URL (optional, HTTPS)',
                ),
                'source-license': t('Lizenz', 'License'),
                'source-attribution': t('Quellenangabe', 'Attribution'),
              },
              'longitude': t('Längengrad', 'Longitude'),
              'latitude': t('Breitengrad', 'Latitude'),
              'heightM': t('Höhe (m)', 'Height (m)'),
              'headingDeg': t('Richtung (°)', 'Heading (°)'),
              'pitchDeg': t('Neigung (°)', 'Pitch (°)'),
              'rollDeg': t('Rollwinkel (°)', 'Roll (°)'),
              'scale': t('Maßstab', 'Scale'),
              'loadRadiusM': t('Ladeentfernung (m)', 'Loading distance (m)'),
              'unloadRadiusM': t(
                'Entladeentfernung (m)',
                'Unloading distance (m)',
              ),
            }.entries)
              TextField(
                key: ValueKey('scenery-${entry.key}'),
                controller: _fields[entry.key],
                enabled: entry.key != 'id' || widget.existing == null,
                decoration: InputDecoration(labelText: entry.value),
                keyboardType:
                    {'id', 'name', 'description'}.contains(entry.key) ||
                        entry.key.startsWith('source-')
                    ? TextInputType.text
                    : const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _reference,
              decoration: InputDecoration(
                labelText: t('Höhenbezug', 'Altitude reference'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'WGS84_ELLIPSOID',
                  child: Text(
                    t(
                      'Absolut (WGS84-Ellipsoid)',
                      'Absolute (WGS84 ellipsoid)',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'TERRAIN_RELATIVE',
                  child: Text(t('Über Gelände', 'Above terrain')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _reference = value);
              },
            ),
            Text('${(_template.toJson()['source'] as Map)['attribution']}'),
            for (final a in _template.assets.where((a) => a.model != null))
              Text(
                '${a.model!['triangles']} triangles · ${a.model!['textures']} textures · ${((a.model!['byteLength'] as num) / 1048576).toStringAsFixed(1)} MiB',
              ),
            SwitchListTile.adaptive(
              title: Text(t('Modellkollisionen', 'Model collisions')),
              subtitle: Text(
                t(
                  'Verwendet das separate Kollisionsmodell der Vorlage.',
                  'Uses the template’s separate collision model.',
                ),
              ),
              value: _collisions,
              onChanged:
                  ((_template.toJson()['collision'] as Map)['assetIds'] as List)
                      .isEmpty
                  ? null
                  : (value) => setState(() => _collisions = value),
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
      FilledButton(onPressed: _save, child: Text(t('Speichern', 'Save'))),
    ],
  );
}
