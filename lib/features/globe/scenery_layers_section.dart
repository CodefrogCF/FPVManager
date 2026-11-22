import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import 'globe_controller.dart';

/// Optional scenery assets with experimental, non-surveyed collision geometry.
class SceneryLayersSection extends StatefulWidget {
  const SceneryLayersSection({super.key, required this.controller});
  final GlobeController controller;

  @override
  State<SceneryLayersSection> createState() => _SceneryLayersSectionState();
}

class _SceneryLayersSectionState extends State<SceneryLayersSection> {
  List<Map<String, dynamic>> _items = [];
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _replacement;

  Future<void> _load(Future<Map<String, dynamic>> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await action();
      final items = (response['sceneries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted)
        setState(() {
          _items = items;
          if (response.containsKey('replacement')) {
            _replacement = response['replacement'] as Map<String, dynamic>?;
          }
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editScenery(Map<String, dynamic> item, bool german) async {
    final id = item['id'] as String;
    final original = {
      for (final key in [
        'alignment',
        'heightOffsetM',
        'buildingRegions',
        'terrainRegions',
        'replaceBuildings',
        'clipTerrain',
      ])
        key: item[key],
    };
    final text = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(original),
    );
    String? error;
    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          Map<String, dynamic> parse() {
            if (text.text.length > 128 * 1024)
              throw const FormatException('JSON too large');
            final decoded = jsonDecode(text.text);
            if (decoded is! Map<String, dynamic> ||
                decoded['alignment'] is! Map<String, dynamic>) {
              throw const FormatException(
                'Expected scenery edit JSON with alignment',
              );
            }
            return decoded;
          }

          void change(
            void Function(Map<String, dynamic>, Map<String, dynamic>) action,
          ) {
            try {
              final edit = parse();
              final alignment = edit['alignment'] as Map<String, dynamic>;
              action(edit, alignment);
              text.text = const JsonEncoder.withIndent('  ').convert(edit);
              update(() => error = null);
            } catch (e) {
              update(() => error = e.toString());
            }
          }

          void nudge(double east, double north) => change((_, alignment) {
            final latitude = (alignment['latitude'] as num).toDouble();
            final radians = latitude * math.pi / 180;
            final w = math.sqrt(
              1 - 0.00669437999014 * math.pow(math.sin(radians), 2),
            );
            final eastM = 6378137 / w * math.cos(radians) * math.pi / 180;
            final northM =
                6378137 *
                (1 - 0.00669437999014) /
                math.pow(w, 3) *
                math.pi /
                180;
            if (eastM.abs() < 100)
              throw const FormatException('Too close to pole');
            alignment['longitude'] =
                (alignment['longitude'] as num) + east / eastM;
            alignment['latitude'] = latitude + north / northM;
          });
          return AlertDialog(
            title: Text(
              german
                  ? 'Ausrichtung & Ersatzflächen'
                  : 'Alignment & replacement regions',
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      german
                          ? 'JSON aus dem Workbench einfügen oder Werte anpassen. Höhenversatz relativ zur automatischen Geländehöhe. Gebäudeersatz im Flug nur bei geladenem Kollisionsmesh. Gelände-Clipping im Flug nur für geprüfte Ersatzflächen mit passendem Kollisionsasset.'
                          : 'Paste JSON from the workbench or edit values. Height offset is relative to automatic terrain alignment. Building replacement in flight requires a loaded collision mesh. Terrain clipping in flight is limited to verified replacement areas with matching collision assets.',
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => nudge(0, 1),
                          child: const Text('N +1 m'),
                        ),
                        TextButton(
                          onPressed: () => nudge(0, -1),
                          child: const Text('S +1 m'),
                        ),
                        TextButton(
                          onPressed: () => nudge(-1, 0),
                          child: const Text('W +1 m'),
                        ),
                        TextButton(
                          onPressed: () => nudge(1, 0),
                          child: const Text('E +1 m'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (_, a) => a['rotationDeg'] =
                                (a['rotationDeg'] as num) - 0.25,
                          ),
                          child: const Text('−0.25°'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (_, a) => a['rotationDeg'] =
                                (a['rotationDeg'] as num) + 0.25,
                          ),
                          child: const Text('+0.25°'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (e, _) => e['heightOffsetM'] =
                                ((e['heightOffsetM'] as num?) ?? 0) - 0.25,
                          ),
                          child: const Text('Z −0.25 m'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (e, _) => e['heightOffsetM'] =
                                ((e['heightOffsetM'] as num?) ?? 0) + 0.25,
                          ),
                          child: const Text('Z +0.25 m'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (_, a) => a['scale'] = (a['scale'] as num) - 0.01,
                          ),
                          child: const Text('Scale −0.01'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (_, a) => a['scale'] = (a['scale'] as num) + 0.01,
                          ),
                          child: const Text('Scale +0.01'),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (e, _) => e['replaceBuildings'] =
                                e['replaceBuildings'] != true,
                          ),
                          child: Text(
                            german
                                ? 'Gebäude-Ersatz umschalten'
                                : 'Toggle building replacement',
                          ),
                        ),
                        TextButton(
                          onPressed: () => change(
                            (e, _) =>
                                e['clipTerrain'] = e['clipTerrain'] != true,
                          ),
                          child: Text(
                            german
                                ? 'Gelände-Clipping umschalten'
                                : 'Toggle terrain clipping',
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: text,
                      minLines: 8,
                      maxLines: 15,
                      onChanged: (_) => update(() => error = null),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Scenery JSON',
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _load(() => widget.controller.setSceneryEdit(id, null));
                },
                child: Text(
                  german ? 'Original wiederherstellen' : 'Restore original',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(german ? 'Abbrechen' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final edit = parse();
                    Navigator.pop(dialogContext);
                    _load(() => widget.controller.setSceneryEdit(id, edit));
                  } catch (e) {
                    update(() => error = e.toString());
                  }
                },
                child: Text(german ? 'Anwenden' : 'Apply'),
              ),
            ],
          );
        },
      ),
    );
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      text.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final german =
        AppLocalizations.maybeOf(context)?.language != AppLanguage.english;
    final controller = widget.controller;
    final enabled = controller.isReady && !_busy;
    return ExpansionTile(
      key: const PageStorageKey('map-real-world-scenery'),
      tilePadding: EdgeInsets.zero,
      title: Text(german ? 'Reale 3D-Umgebungen' : 'Real-world scenery'),
      onExpansionChanged: (expanded) {
        if (expanded && enabled) _load(controller.sceneryStatus);
      },
      children: [
        Text(
          german
              ? 'Experimentell: Kollisionsgeometrie aus Scan, nicht vermessen oder validiert.'
              : 'Experimental: scan-derived collision geometry, not surveyed or validated.',
        ),
        if (_replacement != null)
          Text(
            german
                ? 'Aktive Masken: Gebäude ${_replacement!['buildingActive'] == true ? 'an' : 'aus'} · Gelände ${_replacement!['terrainActive'] == true ? 'an' : 'aus'}'
                : 'Active masks: buildings ${_replacement!['buildingActive'] == true ? 'on' : 'off'} · terrain ${_replacement!['terrainActive'] == true ? 'on' : 'off'}',
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
        TextButton.icon(
          onPressed: enabled ? () => _load(controller.sceneryStatus) : null,
          icon: const Icon(Icons.refresh),
          label: Text(german ? 'Status aktualisieren' : 'Refresh status'),
        ),
        for (final item in _items) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(item['name'] as String? ?? 'Scenery'),
            subtitle: Text(
              '${item['state'] ?? 'idle'}${item['message'] == null ? '' : ' · ${item['message']}'}',
            ),
            value: item['enabled'] == true,
            onChanged: enabled
                ? (value) => _load(
                    () => controller.setSceneryEnabled(
                      item['id'] as String,
                      value,
                    ),
                  )
                : null,
          ),
          if (item['collisionState'] != null)
            Text(
              german
                  ? 'Kollision: ${item['collisionReady'] == true ? 'aktiv' : item['collisionState']} · ${item['collisionTriangles'] ?? 0} Dreiecke${item['collisionError'] == null ? '' : ' · ${item['collisionError']}'}'
                  : 'Collision: ${item['collisionReady'] == true ? 'active' : item['collisionState']} · ${item['collisionTriangles'] ?? 0} triangles${item['collisionError'] == null ? '' : ' · ${item['collisionError']}'}',
            ),
          if (item['lastHit'] is Map)
            Text(
              german
                  ? 'Letzter Kontakt: Dreieck ${(item['lastHit'] as Map)['triangle']}'
                  : 'Last contact: triangle ${(item['lastHit'] as Map)['triangle']}',
            ),
          if (item['groundHeightM'] is num && item['effectiveAlignment'] is Map)
            Text(
              german
                  ? 'Gelände: ${(item['groundHeightM'] as num).toStringAsFixed(1)} m · Modellanker: ${((item['effectiveAlignment'] as Map)['ellipsoidHeightM'] as num).toStringAsFixed(1)} m (experimentell)'
                  : 'Terrain: ${(item['groundHeightM'] as num).toStringAsFixed(1)} m · Model anchor: ${((item['effectiveAlignment'] as Map)['ellipsoidHeightM'] as num).toStringAsFixed(1)} m (experimental)',
            ),
          if (item['heightState'] == 'pending' ||
              item['heightState'] == 'unavailable')
            Text(
              german
                  ? 'Geländehöhenabgleich ausstehend.'
                  : 'Terrain alignment pending.',
            ),
          if ((item['buildingRegions'] as List?)?.isNotEmpty == true)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                german
                    ? 'LoD2 im Ersatzbereich ausblenden'
                    : 'Hide LoD2 in replacement region',
              ),
              subtitle: Text(
                german
                    ? 'Experimenteller Scan-Umriss. Im Flug nur bei aktiver Kollision.'
                    : 'Experimental scan outline. In flight only with active collision.',
              ),
              value: item['replaceBuildings'] == true,
              onChanged: enabled
                  ? (value) => _load(
                      () => controller.setSceneryEdit(item['id'] as String, {
                        for (final key in [
                          'alignment',
                          'heightOffsetM',
                          'buildingRegions',
                          'terrainRegions',
                          'clipTerrain',
                        ])
                          key: item[key],
                        'replaceBuildings': value,
                      }),
                    )
                  : null,
            ),
          if (item['groundUnderlayState'] != null &&
              item['groundUnderlayState'] != 'idle')
            Text(
              german
                  ? 'DGM1-Unterlage: ${item['groundUnderlayState']} · Sichtbar: ${item['groundUnderlayVisible'] == true ? 'ja' : 'nein'}${item['groundUnderlayError'] == null ? '' : ' · ${item['groundUnderlayError']}'}'
                  : 'DGM1 underlay: ${item['groundUnderlayState']} · Visible: ${item['groundUnderlayVisible'] == true ? 'yes' : 'no'}${item['groundUnderlayError'] == null ? '' : ' · ${item['groundUnderlayError']}'}',
            ),
          if ((item['terrainRegions'] as List?)?.isNotEmpty == true)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                german
                    ? 'Geprüfte Gelände-Ersatzflächen inkl. DGM1 (Test)'
                    : 'Verified ground areas including DGM1 (test)',
              ),
              subtitle: Text(
                german
                    ? 'Freigegeben: ${item['terrainReplacementApproved'] ?? 0}/${(item['terrainRegions'] as List?)?.length ?? 0} · Randprüfung: ${item['terrainSeamState'] ?? 'idle'}. Nicht freigegebene Flächen behalten das Standardgelände.'
                    : 'Approved: ${item['terrainReplacementApproved'] ?? 0}/${(item['terrainRegions'] as List?)?.length ?? 0} · seam check: ${item['terrainSeamState'] ?? 'idle'}. Unapproved areas retain base terrain.',
              ),
              value: item['clipTerrain'] == true,
              onChanged: enabled
                  ? (value) => _load(
                      () => controller.setSceneryEdit(item['id'] as String, {
                        for (final key in [
                          'alignment',
                          'heightOffsetM',
                          'buildingRegions',
                          'terrainRegions',
                          'replaceBuildings',
                        ])
                          key: item[key],
                        'clipTerrain': value,
                      }),
                    )
                  : null,
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: enabled
                    ? () async {
                        final alignment = item['alignment'];
                        if (alignment is! Map<String, dynamic>) return;
                        final latitude = alignment['latitude'],
                            longitude = alignment['longitude'];
                        if (latitude is! num || longitude is! num) return;
                        try {
                          await controller.flyTo(
                            latitude: latitude.toDouble(),
                            longitude: longitude.toDouble(),
                            altitude: 450,
                          );
                        } catch (error) {
                          if (mounted)
                            setState(() => _error = error.toString());
                        }
                      }
                    : null,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(german ? 'Auf Karte zeigen' : 'Show on map'),
              ),
              TextButton.icon(
                onPressed: enabled ? () => _editScenery(item, german) : null,
                icon: const Icon(Icons.tune),
                label: Text(
                  german
                      ? 'Ausrichtung & Ersatzflächen'
                      : 'Alignment & replacement regions',
                ),
              ),
              if (item['state'] == 'error')
                TextButton(
                  onPressed: enabled
                      ? () => _load(
                          () => controller.retryScenery(item['id'] as String),
                        )
                      : null,
                  child: Text(german ? 'Erneut laden' : 'Retry'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
