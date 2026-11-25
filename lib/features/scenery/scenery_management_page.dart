import 'dart:async';

import 'package:flutter/material.dart';

import 'scenery_manifest.dart';

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
  });
  final Future<List<SceneryManifest>> Function() load, templates;
  final Future<void> Function(SceneryManifest manifest, bool create) save;
  final Future<void> Function(String id) remove;
  final bool german;
  @override
  State<SceneryManagementPage> createState() => _SceneryManagementPageState();
}

class _SceneryManagementPageState extends State<SceneryManagementPage> {
  List<SceneryManifest> _items = [];
  bool _busy = true;
  String? _error;
  String t(String de, String en) => widget.german ? de : en;
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
            'Umgebungen verwenden vorhandene Modellvorlagen. Ausrichtung und Aktivierung werden auf diesem Gerät gespeichert.',
            'Scenery uses existing model templates. Placement and activation are saved on this device.',
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
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
        for (final item in _items)
          ListTile(
            title: Text(item.name),
            subtitle: Text(
              '${item.enabled ? t('Aktiviert', 'Enabled') : t('Deaktiviert', 'Disabled')} · ${(item.toJson()['source'] as Map)['attribution']}',
            ),
            onTap: _busy ? null : () => _edit(item),
            trailing: IconButton(
              tooltip: t('Entfernen', 'Remove'),
              onPressed: _busy ? null : () => _remove(item),
              icon: const Icon(Icons.delete_outline),
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
  });
  final List<SceneryManifest> templates;
  final SceneryManifest? existing;
  final bool german;
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
      widget.existing == null
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
                keyboardType: {'id', 'name', 'description'}.contains(entry.key)
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
