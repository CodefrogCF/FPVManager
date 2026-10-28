import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';

enum _MapAction { home, coordinates, terrain, layers, weather, simulation }

class MapActionMenu extends StatelessWidget {
  const MapActionMenu({
    super.key,
    required this.controller,
    required this.groundButtonBuilder,
    required this.onHome,
    required this.onCoordinates,
    required this.onTerrain,
    required this.onLayers,
    required this.onWeather,
    required this.onSimulation,
    this.compact = false,
  });
  final GlobeController controller;
  final bool compact;
  final Widget Function() groundButtonBuilder;
  final Future<void> Function() onHome,
      onCoordinates,
      onTerrain,
      onLayers,
      onWeather;
  final Future<void> Function() onSimulation;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          IconButton(
            tooltip: 'Map layers',
            onPressed: controller.isReady ? onLayers : null,
            icon: Icon(
              Icons.layers_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (!compact) groundButtonBuilder(),
        PopupMenuButton<_MapAction>(
          tooltip: 'Map actions',
          onSelected: (action) {
            unawaited(switch (action) {
              _MapAction.home => onHome(),
              _MapAction.coordinates => onCoordinates(),
              _MapAction.terrain => onTerrain(),
              _MapAction.layers => onLayers(),
              _MapAction.weather => onWeather(),
              _MapAction.simulation => onSimulation(),
            });
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _MapAction.simulation,
              enabled:
                  controller.isReady &&
                  controller.terrainAvailable &&
                  !controller.simulationPending,
              child: Text(
                controller.simulationActive
                    ? 'Flight simulation settings'
                    : 'Spawn in map · simulated flight',
              ),
            ),
            PopupMenuItem(
              value: _MapAction.layers,
              enabled: controller.isReady,
              child: const Text('Map layers'),
            ),
            PopupMenuItem(
              value: _MapAction.coordinates,
              enabled: controller.isReady,
              child: const Text('Go to coordinates'),
            ),
            PopupMenuItem(
              value: _MapAction.terrain,
              enabled:
                  controller.isReady &&
                  controller.terrainAvailable &&
                  controller.selectedPoint != null &&
                  controller.selectedUasZone == null,
              child: const Text('Query terrain elevation'),
            ),
            const PopupMenuItem(
              value: _MapAction.weather,
              child: Text('Weather intelligence'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _MapAction.home,
              enabled: controller.isReady,
              child: const Text('Home'),
            ),
          ],
        ),
      ],
    ),
  );
}
