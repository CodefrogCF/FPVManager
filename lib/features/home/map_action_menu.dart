import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';
import '../globe/globe_location_controls.dart';
import '../../core/models/activity_profile.dart';

enum _MapAction {
  home,
  coordinates,
  location,
  touchControls,
  terrain,
  layers,
  weather,
  simulation,
  recording,
  exitNavigation,
  settings,
  allTools,
}

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
    required this.onRecordingReview,
    required this.onExitNavigation,
    this.compact = false,
    this.onSettings,
    this.preferredActions,
    this.onAllTools,
  });
  final GlobeController controller;
  final bool compact;
  final Future<void> Function()? onSettings;
  final List<ActivityAction>? preferredActions;
  final VoidCallback? onAllTools;
  bool _show(ActivityAction action) =>
      preferredActions == null || preferredActions!.contains(action);
  final Widget Function() groundButtonBuilder;
  final Future<void> Function() onHome,
      onCoordinates,
      onTerrain,
      onLayers,
      onWeather;
  final Future<void> Function() onSimulation,
      onExitNavigation,
      onRecordingReview;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact && _show(ActivityAction.location))
          GlobeLocationButton(controller: controller.location),
        if (!compact && _show(ActivityAction.layers))
          IconButton(
            tooltip: 'Map layers',
            onPressed: controller.isReady ? onLayers : null,
            icon: Icon(
              Icons.layers_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (!compact &&
            (_show(ActivityAction.ground) || controller.navigationActive))
          groundButtonBuilder(),
        PopupMenuButton<_MapAction>(
          tooltip: 'Map actions',
          onSelected: (action) {
            unawaited(switch (action) {
              _MapAction.home => onHome(),
              _MapAction.coordinates => onCoordinates(),
              _MapAction.location => showGlobeLocationSettings(
                context,
                controller.location,
              ),
              _MapAction.touchControls => controller.setTouchControlsVisible(
                !controller.touchControlsVisible,
              ),
              _MapAction.terrain => onTerrain(),
              _MapAction.layers => onLayers(),
              _MapAction.weather => onWeather(),
              _MapAction.simulation => onSimulation(),
              _MapAction.recording => onRecordingReview(),
              _MapAction.exitNavigation => onExitNavigation(),
              _MapAction.settings => onSettings?.call() ?? Future<void>.value(),
              _MapAction.allTools => Future<void>.sync(
                () => onAllTools?.call(),
              ),
            });
          },
          itemBuilder: (_) => [
            if (controller.recording.hasSamples)
              PopupMenuItem(
                value: _MapAction.recording,
                enabled: !controller.recording.busy,
                child: const Text('Review flight recording'),
              ),
            if (compact && controller.navigationActive)
              const PopupMenuItem(
                value: _MapAction.exitNavigation,
                child: Text('Return to globe'),
              ),
            if (_show(ActivityAction.simulation) || controller.simulationActive)
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
            if (_show(ActivityAction.layers))
              PopupMenuItem(
                value: _MapAction.layers,
                enabled: controller.isReady,
                child: const Text('Map layers'),
              ),
            if (_show(ActivityAction.search))
              PopupMenuItem(
                value: _MapAction.coordinates,
                enabled: controller.isReady,
                child: const Text('Ort oder Koordinaten suchen'),
              ),
            if (_show(ActivityAction.location))
              const PopupMenuItem(
                value: _MapAction.location,
                child: Text('Standortanzeige'),
              ),
            if (controller.navigationActive)
              PopupMenuItem(
                value: _MapAction.touchControls,
                enabled: controller.canEditPreferences,
                child: Text(
                  controller.touchControlsVisible
                      ? 'Touch-Steuerung ausblenden'
                      : 'Touch-Steuerung anzeigen',
                ),
              ),
            if (_show(ActivityAction.terrain))
              PopupMenuItem(
                value: _MapAction.terrain,
                enabled:
                    controller.isReady &&
                    controller.terrainAvailable &&
                    controller.selectedPoint != null &&
                    controller.selectedUasZone == null,
                child: const Text('Query terrain elevation'),
              ),
            if (_show(ActivityAction.weather))
              const PopupMenuItem(
                value: _MapAction.weather,
                child: Text('Weather intelligence'),
              ),
            if (onSettings != null)
              PopupMenuItem(
                value: _MapAction.settings,
                child: const Text('Einstellungen'),
              ),
            if (preferredActions != null && onAllTools != null)
              const PopupMenuItem(
                value: _MapAction.allTools,
                child: Text('Alle Werkzeuge'),
              ),
            const PopupMenuDivider(),
            if (_show(ActivityAction.home))
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
