import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globe/globe_controller.dart';

class SituationalLayersSection extends StatelessWidget {
  const SituationalLayersSection({super.key, required this.globe, this.onOpen});
  final GlobeController globe;
  final VoidCallback? onOpen;
  Future<void> _set(BuildContext context, Map<String, dynamic> value) async {
    try {
      await globe.showSituationalOverlay(value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layer update failed. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: globe,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Independent information layers. Online layers send the viewed area to geo.admin.ch. Published information may be incomplete or outdated; it does not establish flight or ground access permission.',
        ),
        for (final layer in [
          (
            id: 'heliports',
            name: 'Published aerodromes & heliports',
            source: 'BAZL / FOCA',
            code: 'ch.bazl.flugplaetze-heliports',
          ),
          (
            id: 'wildfire',
            name: 'Wildfire danger',
            source: 'BAFU / FOEN',
            code: 'ch.bafu.gefahren-waldbrand_warnung',
          ),
        ]) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(layer.name),
            value: globe.situationalVisible(layer.id),
            subtitle: Text(
              '${layer.source} · Switzerland / Liechtenstein\nTiles: ${globe.situationalStatus(layer.id) ?? "off"} · source publication/validity: unknown. Tile loading is not verification of freshness.',
            ),
            onChanged: (visible) => _set(context, {
              'id': layer.id,
              'visible': visible,
              'opacity': globe.situationalOpacity(layer.id),
            }),
          ),
          if (globe.situationalVisible(layer.id)) ...[
            Slider(
              label: '${(globe.situationalOpacity(layer.id) * 100).round()}%',
              value: globe.situationalOpacity(layer.id),
              onChanged: (value) => _set(context, {
                'id': layer.id,
                'visible': true,
                'opacity': value,
              }),
            ),
            if (globe.situationalStatus(layer.id) == 'failed')
              TextButton(
                onPressed: () => _set(context, {
                  'id': layer.id,
                  'visible': true,
                  'opacity': globe.situationalOpacity(layer.id),
                  'retry': true,
                }),
                child: const Text('Retry tiles'),
              ),
          ],
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://api3.geo.admin.ch/rest/services/api/MapServer/${layer.code}/legend',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Official legend & source'),
          ),
        ],
        const Text(
          'Aerodrome data is a planning reference, not the operational AIP or a list of public access rights. Wildfire data does not replace local orders. No confidential emergency data or live responder layer is used.',
        ),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://www.slf.ch/en/avalanche-bulletin-and-snow-situation/',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Official SLF avalanche bulletin'),
        ),
        for (final id in ['road', 'traffic', 'aircraft'])
          if (globe.situationalVisible(id))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('$id snapshot visible'),
              trailing: IconButton(
                tooltip: 'Remove $id layer',
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: () => _set(context, {'id': id, 'visible': false}),
              ),
            ),
        if (onOpen != null)
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Routes, traffic & aircraft'),
          ),
      ],
    ),
  );
}
