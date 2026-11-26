import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scenery_manifest.dart';
import 'scenery_replacement.dart';

class SceneryReplacementDialog extends StatefulWidget {
  const SceneryReplacementDialog({
    super.key,
    required this.existing,
    required this.german,
  });
  final SceneryManifest existing;
  final bool german;
  @override
  State<SceneryReplacementDialog> createState() =>
      _SceneryReplacementDialogState();
}

class _SceneryReplacementDialogState extends State<SceneryReplacementDialog> {
  late final TextEditingController _buildings, _features, _terrain;
  late bool _replaceBuildings, _replaceTerrain;
  String? _error;
  String t(String de, String en) => widget.german ? de : en;
  String encode(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);
  @override
  void initState() {
    super.initState();
    final config =
        widget.existing.toJson()['replacement'] ?? emptySceneryReplacement();
    _replaceBuildings = config['buildings']['enabled'] as bool;
    _replaceTerrain = config['terrain']['enabled'] as bool;
    _buildings = TextEditingController(
      text: encode(config['buildings']['regions']),
    );
    _features = TextEditingController(
      text: encode(config['buildings']['features']),
    );
    _terrain = TextEditingController(
      text: encode(config['terrain']['regions']),
    );
  }

  @override
  void dispose() {
    _buildings.dispose();
    _features.dispose();
    _terrain.dispose();
    super.dispose();
  }

  Object? read(TextEditingController controller) {
    if (controller.text.length > 65536) {
      throw const FormatException('Region input exceeds 64 KiB');
    }
    return jsonDecode(controller.text);
  }

  void action(VoidCallback callback) {
    try {
      callback();
      setState(() => _error = null);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Widget field(TextEditingController controller, String label, String hint) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            helperMaxLines: 4,
            border: const OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 6,
        ),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      t('Gelände und Gebäude ersetzen', 'Replace terrain and buildings'),
    ),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                'Bereiche gelten in geografischen Koordinaten. Gebäude und Gelände sind unabhängig schaltbar. Gespeicherte Bereiche werden im Ausrichtungseditor angezeigt.',
                'Regions use geographic coordinates. Buildings and terrain are independent. Saved regions are displayed in the alignment editor.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t('Standardgebäude ersetzen', 'Replace base buildings'),
              ),
              value: _replaceBuildings,
              onChanged: (v) => setState(() => _replaceBuildings = v),
            ),
            field(
              _buildings,
              t('Gebäudepolygone', 'Building polygons'),
              '[[[longitude, latitude], ...], ...]',
            ),
            OutlinedButton(
              onPressed: () => action(() {
                final a = widget.existing.toJson()['anchor'] as Map,
                    lon = (a['longitude'] as num).toDouble(),
                    lat = (a['latitude'] as num).toDouble(),
                    dx = 10 / (111320 * math.cos(lat * math.pi / 180)),
                    dy = 10 / 111320;
                double wrap(double x) => (x + 540) % 360 - 180;
                final regions = read(_buildings) as List;
                _buildings.text = encode([
                  ...regions,
                  [
                    [wrap(lon - dx), lat - dy],
                    [wrap(lon + dx), lat - dy],
                    [wrap(lon + dx), lat + dy],
                    [wrap(lon - dx), lat + dy],
                  ],
                ]);
              }),
              child: Text(
                t(
                  '20-m-Bereich am Anker ergänzen',
                  'Add 20 m region at anchor',
                ),
              ),
            ),
            field(
              _features,
              t('Einzelne Gebäude', 'Individual buildings'),
              '[{"provider":"swisstopo" or "bkg", "property":"stable_property", "id":"value"}]',
            ),
            Text(
              t(
                'Nur Kennungen aus dem jeweiligen Anbieter verwenden. Ohne stabile Kennung ein Polygon verwenden. Straßen und andere Layer werden nicht ausgeblendet.',
                'Use identifiers published by the selected provider. Use a polygon when no stable identifier is available. Roads and other layers remain visible.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('Basisgelände ersetzen', 'Replace base terrain')),
              value: _replaceTerrain,
              onChanged: (v) => setState(() => _replaceTerrain = v),
            ),
            field(
              _terrain,
              t(
                'Geländebereiche und Bodenhöhen',
                'Terrain regions and ground heights',
              ),
              '[{"polygon":[[longitude, latitude], ...], "minimumUpM":-1, "maximumUpM":1, "seamToleranceM":0.5}]',
            ),
            OutlinedButton(
              onPressed: () => action(() {
                _terrain.text = encode(
                  (read(_buildings) as List)
                      .map(
                        (p) => {
                          'polygon': p,
                          'minimumUpM': -1,
                          'maximumUpM': 1,
                          'seamToleranceM': .5,
                        },
                      )
                      .toList(),
                );
              }),
              child: Text(
                t('Gebäudebereiche übernehmen', 'Copy building regions'),
              ),
            ),
            Text(
              t(
                'Bodenhöhen sind lokale Meter der Kollisionsgeometrie. Den Bereich auf den tatsächlichen Boden begrenzen, damit Dächer nicht als Boden dienen. Ausschnitte benötigen geladene Kollisionsgeometrie, waagerechte Platzierung und eine erfolgreiche Randprüfung. Maximal 0,5 m Abweichung; bei Datenlücken bleibt das Gelände erhalten.',
                'Ground heights are local metres in collision geometry. Limit the height band to actual ground so roofs are not used as ground. Cuts require loaded collision geometry, level placement and a passing perimeter check. Maximum mismatch is 0.5 m; data gaps retain base terrain.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
        onPressed: () => action(() {
          final config = validateSceneryReplacement({
            'schemaVersion': 1,
            'buildings': {
              'enabled': _replaceBuildings,
              'regions': read(_buildings),
              'features': read(_features),
            },
            'terrain': {'enabled': _replaceTerrain, 'regions': read(_terrain)},
          }, widget.existing.toJson()['anchor'] as Map);
          Navigator.pop(context, config);
        }),
        child: Text(t('Übernehmen', 'Apply')),
      ),
    ],
  );
}
