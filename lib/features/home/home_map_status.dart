import 'dart:async';

import '../../core/localization/app_localizations.dart';

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
        value: notices.isEmpty
            ? context.localized(
                "No map data warnings",
                (l10n) => l10n.homeNoMapDataWarnings4f085b42,
              )
            : notices.join('. '),
        child: IconButton(
          tooltip: context.localized(
            "Map status",
            (l10n) => l10n.homeMapStatus5f4e7ac0,
          ),
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
        title: Text(
          context.localized("Map status", (l10n) => l10n.homeMapStatus5f4e7ac0),
        ),
        trailing: IconButton(
          tooltip: context.localized(
            "Close map status",
            (l10n) => l10n.homeCloseMapStatusbaaf9b31,
          ),
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
                        ? context.localizedWithArgs(
                            "Map error: {0}",
                            [controller.error],
                            (l10n, value) =>
                                l10n.homeMapError05472eae(value(0)),
                          )
                        : !controller.isReady
                        ? context.localized(
                            "Loading globe...",
                            (l10n) => l10n.homeLoadingGlobe79eb5f94,
                          )
                        : controller.terrainAvailable
                        ? context.localized(
                            "3D globe ready",
                            (l10n) => l10n.homeDGlobeReady1847f54f,
                          )
                        : context.localized(
                            "Flat map — terrain heights unavailable",
                            (l10n) => l10n.homeFlatMapTerrainHeightsd993a5d7,
                          ),
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
