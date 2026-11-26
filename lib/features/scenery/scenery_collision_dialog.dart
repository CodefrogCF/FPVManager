import 'package:flutter/material.dart';

import 'scenery_collision_import.dart';
import 'scenery_import_files.dart';
import 'scenery_manifest.dart';

typedef SceneryColliderGenerator = Future<PreparedSceneryCollision> Function(
  SceneryManifest,
  String,
);
typedef SceneryCollisionSelection = (
  SceneryManifest,
  List<PreparedSceneryCollision>,
);

class SceneryCollisionDialog extends StatefulWidget {
  const SceneryCollisionDialog({
    super.key,
    required this.existing,
    required this.german,
    required this.generate,
    this.pick,
  });
  final SceneryManifest existing;
  final bool german;
  final SceneryColliderGenerator generate;
  final Future<PreparedSceneryCollision?> Function()? pick;
  @override
  State<SceneryCollisionDialog> createState() => _SceneryCollisionDialogState();
}

class _SceneryCollisionDialogState extends State<SceneryCollisionDialog> {
  late List<Map<String, dynamic>> _assets;
  final _pending = <String, PreparedSceneryCollision>{};
  late bool _enabled;
  late String _side;
  String? _visual, _error, _progress;
  bool _busy = false;
  String t(String de, String en) => widget.german ? de : en;
  @override
  void initState() {
    super.initState();
    final doc = widget.existing.toJson(), c = doc['collision'] as Map;
    _assets = (doc['assets'] as List)
        .where((a) => a['role'] == 'collision')
        .cast<Map<String, dynamic>>()
        .toList();
    _enabled = c['enabled'] as bool;
    _side = c['sidedness'] as String;
    _visual = widget.existing.assets
        .where(
          (a) =>
              a.role == 'visual' &&
              a.format == 'glb' &&
              {'managed', 'bundled'}.contains(a.provider),
        )
        .firstOrNull
        ?.id;
  }

  Future<bool> _resource(String uri) async => !mounted
      ? false
      : await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  t('Zugehörige Datei auswählen', 'Select model resource'),
                ),
                content: Text(uri),
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
  Future<void> _prepare(bool generate) async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = t(
        'Kollisionsgeometrie vorbereiten',
        'Preparing collision geometry',
      );
    });
    try {
      final mesh = generate
          ? await widget.generate(widget.existing, _visual!)
          : await (widget.pick?.call() ??
                pickSceneryCollision(
                  requestResource: _resource,
                  progress: (stage) {
                    if (mounted) setState(() => _progress = stage);
                  },
                ));
      if (mesh == null || !mounted) return;
      final next = [
        ..._assets.where((a) => a['uri'] != mesh.key),
        sceneryCollisionAsset(mesh),
      ];
      configureSceneryCollision(
        widget.existing,
        next,
        enabled: true,
        sidedness: _side,
      );
      setState(() {
        _assets = next;
        _pending[mesh.key] = mesh;
        _enabled = true;
      });
    } on SceneryImportCancelled {
      /* No definition or file was committed. */
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  void _save() {
    try {
      final draft = configureSceneryCollision(
        widget.existing,
        _assets,
        enabled: _enabled,
        sidedness: _side,
      );
      Navigator.pop(context, (
        draft,
        _pending.values
            .where((m) => _assets.any((a) => a['uri'] == m.key))
            .toList(),
      ));
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Kollisionsgeometrie', 'Collision geometry')),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                'Kollisionsmeshes verwenden denselben lokalen Ursprung und dieselben Meter-Einheiten wie das sichtbare Modell. Öffnungen werden nicht automatisch geschlossen.',
                'Collision meshes use the visual model’s local origin and metre units. Openings are never filled automatically.',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t(
                  'Physische Kollisionen aktivieren',
                  'Enable physical collisions',
                ),
              ),
              value: _enabled,
              onChanged: _busy ? null : (v) => setState(() => _enabled = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _side,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('Dünne Flächen', 'Thin-surface sidedness'),
              ),
              items: [
                for (final value in ['double', 'front', 'back'])
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'double'
                          ? t('Beide Seiten', 'Double sided')
                          : value == 'front'
                          ? t(
                              'Vorderseite (Dreiecksnormalen)',
                              'Front (triangle normals)',
                            )
                          : t('Rückseite', 'Back'),
                    ),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _side = v!),
            ),
            for (final asset in _assets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  asset['uri'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${(asset['model'] as Map?)?['triangles'] ?? '—'} triangles',
                ),
                trailing: IconButton(
                  tooltip: t('Mesh entfernen', 'Remove mesh'),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _assets.remove(asset)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => _prepare(false),
              icon: const Icon(Icons.file_open),
              label: Text(
                t('Kollisionsmesh importieren', 'Import collision mesh'),
              ),
            ),
            if (_visual != null) ...[
              DropdownButtonFormField<String>(
                initialValue: _visual,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t('Sichtbares Quellmodell', 'Visual source model'),
                ),
                items: [
                  for (final asset in widget.existing.assets.where(
                    (a) =>
                        a.role == 'visual' &&
                        a.format == 'glb' &&
                        {'managed', 'bundled'}.contains(a.provider),
                  ))
                    DropdownMenuItem(value: asset.id, child: Text(asset.id)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _visual = v),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _prepare(true),
                icon: const Icon(Icons.grid_on),
                label: Text(
                  t(
                    'Aus sichtbarem Modell erzeugen',
                    'Generate from visual model',
                  ),
                ),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_progress != null) Text(_progress!),
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
        onPressed: _busy ? null : _save,
        child: Text(t('Übernehmen', 'Apply')),
      ),
    ],
  );
}
