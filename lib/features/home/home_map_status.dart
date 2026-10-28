import 'dart:async';

import 'package:flutter/material.dart';

import '../airspace/uas_data_quality_banner.dart';
import '../globe/globe_controller.dart';
import '../globe/terrain_status_banner.dart';
import '../globe/map_layers_sheet.dart';
import '../obstacles/obstacle_layers_section.dart';
import '../offline/cached_map_notice.dart';

List<String> _notices(GlobeController controller, bool cachedMaps) => [
  if (controller.error case final error?) 'Map error: $error',
  if (controller.isReady && !controller.terrainAvailable)
    '3D terrain unavailable',
  if (controller.terrainResourceWarning) 'Some terrain tiles are unavailable',
  if (cachedMaps) 'Cached map · coverage may be incomplete or outdated',
  ?(controller.obstacles.wmsError ?? controller.obstacles.vectorError),
  ?UasDataQualityBanner.messageFor(controller),
];

class HomeMapStatusButton extends StatefulWidget {
  const HomeMapStatusButton({
    super.key,
    required this.controller,
    required this.cachedMaps,
    required this.onPressed,
  });
  final GlobeController controller;
  final bool cachedMaps;
  final VoidCallback onPressed;
  @override
  State<HomeMapStatusButton> createState() => _HomeMapStatusButtonState();
}

class _HomeMapStatusButtonState extends State<HomeMapStatusButton> {
  Timer? _age;
  @override
  void initState() {
    super.initState();
    _age = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _age?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final notices = _notices(widget.controller, widget.cachedMaps);
      return Semantics(
        liveRegion: notices.isNotEmpty,
        value: notices.isEmpty ? 'No map data warnings' : notices.join('. '),
        child: IconButton(
          tooltip: 'Map status',
          onPressed: widget.onPressed,
          icon: Badge.count(
            count: notices.length,
            isLabelVisible: notices.isNotEmpty,
            child: Icon(
              notices.isEmpty
                  ? Icons.info_outline
                  : Icons.warning_amber_rounded,
            ),
          ),
        ),
      );
    },
  );
}

class HomeMapStatusSheet extends StatelessWidget {
  const HomeMapStatusSheet({
    super.key,
    required this.controller,
    required this.cachedMaps,
    required this.onLayers,
  });
  final GlobeController controller;
  final bool cachedMaps;
  final ValueChanged<MapLayerTab> onLayers;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Map status'),
        trailing: IconButton(
          tooltip: 'Close map status',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    controller.error != null
                        ? 'Map error: ${controller.error}'
                        : !controller.isReady
                        ? 'Loading globe...'
                        : controller.terrainAvailable
                        ? '3D globe ready'
                        : 'Flat map — terrain heights unavailable',
                  ),
                ),
              ),
              TerrainStatusBanner(controller: controller),
              if (cachedMaps) const CachedMapNotice(),
              ObstacleStatusBanner(
                controller: controller.obstacles,
                onDetails: () => onLayers(MapLayerTab.obstacles),
              ),
              UasDataQualityBanner(
                controller: controller,
                onDetails: () => onLayers(MapLayerTab.airspace),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
