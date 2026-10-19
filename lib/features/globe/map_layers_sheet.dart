import 'package:flutter/material.dart';

import 'globe_controller.dart';

class MapLayersSheet extends StatefulWidget {
  const MapLayersSheet({super.key, required this.controller});

  final GlobeController controller;

  @override
  State<MapLayersSheet> createState() => _MapLayersSheetState();
}

class _MapLayersSheetState extends State<MapLayersSheet> {
  double? _previewOpacity;

  Future<void> _execute(Future<void> Function() command) async {
    try {
      await command();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Map layer error: $error')));
    }
  }

  String _formatDownloadTime(DateTime? date) {
    if (date == null) {
      return 'Not downloaded in this session';
    }

    final utc = date.toUtc();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${utc.year}-'
        '${twoDigits(utc.month)}-'
        '${twoDigits(utc.day)} '
        '${twoDigits(utc.hour)}:'
        '${twoDigits(utc.minute)} UTC';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final controller = widget.controller;
          final opacity = _previewOpacity ?? controller.uasZonesFillOpacity;

          final canEditOpacity =
              controller.isReady &&
              controller.uasZonesVisible &&
              !controller.uasZonesLoading;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers_outlined),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Map Layers',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'BASE MAP',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<GlobeMapStyle>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: GlobeMapStyle.satellite,
                          label: Text('Satellite'),
                          icon: Icon(Icons.satellite_alt),
                        ),
                        ButtonSegment(
                          value: GlobeMapStyle.topographic,
                          label: Text('Topo'),
                          icon: Icon(Icons.map_outlined),
                        ),
                        ButtonSegment(
                          value: GlobeMapStyle.relief,
                          label: Text('Relief'),
                          icon: Icon(Icons.terrain),
                        ),
                      ],
                      selected: {controller.mapStyle},
                      onSelectionChanged: controller.isReady
                          ? (selection) {
                              _execute(
                                () => controller.setMapStyle(selection.first),
                              );
                            }
                          : null,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'AIRSPACE',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),

                  const Divider(height: 24),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.shield_outlined),
                    title: const Text('Swiss UAS Geographical Zones'),
                    subtitle: Text(
                      controller.uasZonesLoading
                          ? 'Loading official zone data...'
                          : 'FOCA / BAZL · GeoJSON',
                    ),
                    value: controller.uasZonesVisible,
                    onChanged: controller.isReady && !controller.uasZonesLoading
                        ? (visible) {
                            _execute(
                              () => controller.setUasZonesVisible(visible),
                            );
                          }
                        : null,
                  ),

                  if (controller.uasZonesLoading)
                    const LinearProgressIndicator(),

                  const SizedBox(height: 12),

                  Text(
                    'Polygon fill opacity: '
                    '${(opacity * 100).round()}%',
                  ),

                  Slider(
                    min: 0,
                    max: 1,
                    divisions: 20,
                    value: opacity,
                    onChanged: canEditOpacity
                        ? (value) {
                            setState(() {
                              _previewOpacity = value;
                            });
                          }
                        : null,
                    onChangeEnd: canEditOpacity
                        ? (value) async {
                            await _execute(
                              () => controller.setUasZonesFillOpacity(value),
                            );
                            if (!mounted) return;
                            setState(() => _previewOpacity = null);
                          }
                        : null,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'DATA SOURCE',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh UAS data',
                        onPressed:
                            controller.isReady &&
                                controller.uasZonesVisible &&
                                !controller.uasZonesLoading
                            ? () => _execute(controller.refreshUasZones)
                            : null,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _InfoRow(label: 'Provider', value: 'FOCA / BAZL'),

                  _InfoRow(
                    label: 'Downloaded',
                    value: _formatDownloadTime(controller.uasZonesDownloadedAt),
                  ),

                  _InfoRow(
                    label: 'Loaded features',
                    value: controller.uasZonesFeatureCount?.toString() ?? '—',
                  ),

                  _InfoRow(label: 'Source', value: 'data.geo.admin.ch'),

                  if (controller.uasZonesError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        controller.uasZonesError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Text(
                    'Geographical UAS zones may restrict '
                    'drone operations. The download time '
                    'does not represent the official '
                    'dataset publication date. '
                    'Always verify current flight '
                    'restrictions using official sources.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
