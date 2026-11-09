import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';
import '../globe/globe_location_controls.dart';
import '../globe/desktop_globe_interaction_mode.dart';
import '../../core/models/activity_profile.dart';

class _MenuEntry {
  const _MenuEntry(this.action, this.label, {this.enabled = true});
  const _MenuEntry.divider() : action = null, label = '', enabled = false;

  final _MapAction? action;
  final String label;
  final bool enabled;
}

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
    this.desktopMenu,
  });
  final GlobeController controller;
  final bool compact;
  final Future<void> Function()? onSettings;
  final List<ActivityAction>? preferredActions;
  final VoidCallback? onAllTools;

  /// Optional test override; the shipped desktop build uses MenuAnchor.
  final bool? desktopMenu;

  bool get _useDesktopMenu => desktopMenu ?? desktopGlobeInteractionEnabled;
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
            tooltip: 'Karte & Ansicht',
            onPressed: controller.isReady ? onLayers : null,
            icon: Icon(
              Icons.layers_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (!compact &&
            (_show(ActivityAction.ground) || controller.navigationActive))
          groundButtonBuilder(),
        _useDesktopMenu ? _desktopActions(context) : _mobileActions(context),
      ],
    ),
  );

  Future<void> _dispatch(BuildContext context, _MapAction action) =>
      switch (action) {
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
        _MapAction.allTools => Future<void>.sync(() => onAllTools?.call()),
      };

  IconData _icon(_MapAction action) => switch (action) {
    _MapAction.home => Icons.home_outlined,
    _MapAction.coordinates => Icons.search,
    _MapAction.location => Icons.my_location,
    _MapAction.touchControls => Icons.gamepad_outlined,
    _MapAction.terrain => Icons.height,
    _MapAction.layers => Icons.layers_outlined,
    _MapAction.weather => Icons.cloud_outlined,
    _MapAction.simulation => Icons.flight_takeoff,
    _MapAction.recording => Icons.route_outlined,
    _MapAction.exitNavigation => Icons.public,
    _MapAction.settings => Icons.settings_outlined,
    _MapAction.allTools => Icons.apps,
  };

  List<_MenuEntry> _entries() => [
    if (_show(ActivityAction.search))
      _MenuEntry(
        _MapAction.coordinates,
        'Ort suchen',
        enabled: controller.isReady,
      ),
    if (_show(ActivityAction.location))
      const _MenuEntry(_MapAction.location, 'Standortanzeige'),
    if (_show(ActivityAction.layers))
      _MenuEntry(
        _MapAction.layers,
        'Karte & Ansicht',
        enabled: controller.isReady,
      ),
    if (_show(ActivityAction.weather))
      const _MenuEntry(_MapAction.weather, 'Wetter'),
    if (_show(ActivityAction.terrain))
      _MenuEntry(
        _MapAction.terrain,
        'Geländehöhe',
        enabled:
            controller.isReady &&
            controller.terrainAvailable &&
            controller.selectedPoint != null &&
            controller.selectedUasZone == null,
      ),
    const _MenuEntry.divider(),
    if (_show(ActivityAction.simulation) || controller.simulationActive)
      _MenuEntry(
        _MapAction.simulation,
        controller.simulationActive ? 'Flug einstellen' : 'Flugsimulator',
        enabled:
            controller.isReady &&
            controller.terrainAvailable &&
            !controller.simulationPending,
      ),
    if (controller.recording.hasSamples)
      _MenuEntry(
        _MapAction.recording,
        'Flugaufzeichnung',
        enabled: !controller.recording.busy,
      ),
    if (controller.navigationActive)
      _MenuEntry(
        _MapAction.touchControls,
        controller.touchControlsVisible
            ? 'Touch-Steuerung ausblenden'
            : 'Touch-Steuerung anzeigen',
        enabled: controller.canEditPreferences,
      ),
    if (compact && controller.navigationActive)
      const _MenuEntry(_MapAction.exitNavigation, 'Zur Karte'),
    const _MenuEntry.divider(),
    if (onSettings != null)
      const _MenuEntry(_MapAction.settings, 'Einstellungen'),
    if (preferredActions != null && onAllTools != null)
      const _MenuEntry(_MapAction.allTools, 'Alle Werkzeuge'),
    if (_show(ActivityAction.home))
      _MenuEntry(
        _MapAction.home,
        'Karte zurücksetzen',
        enabled: controller.isReady,
      ),
  ];

  Widget _mobileActions(BuildContext context) => PopupMenuButton<_MapAction>(
    tooltip: 'Kartenaktionen',
    onSelected: (action) => unawaited(_dispatch(context, action)),
    itemBuilder: (_) => [
      for (final entry in _entries())
        if (entry.action == null)
          const PopupMenuDivider()
        else
          PopupMenuItem<_MapAction>(
            value: entry.action,
            enabled: entry.enabled,
            child: Row(
              children: [
                Icon(_icon(entry.action!)),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.label)),
              ],
            ),
          ),
    ],
  );

  Widget _desktopActions(BuildContext context) => MenuAnchor(
    consumeOutsideTap: false,
    style: const MenuStyle(alignment: Alignment.bottomRight),
    menuChildren: [
      for (final entry in _entries())
        if (entry.action == null)
          const Divider(height: 1)
        else
          MenuItemButton(
            onPressed: entry.enabled
                ? () => unawaited(_dispatch(context, entry.action!))
                : null,
            leadingIcon: Icon(_icon(entry.action!)),
            child: Text(entry.label),
          ),
    ],
    builder: (context, menu, child) => IconButton(
      tooltip: 'Kartenaktionen',
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.more_vert),
    ),
  );
}
