import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../globe/map_floating_surface.dart';
import '../../core/models/activity_profile.dart';

class HomeNavigationDrawer extends StatelessWidget {
  const HomeNavigationDrawer({
    super.key,
    required this.onSpots,
    required this.onRoutes,
    required this.onWeather,
    required this.onDrones,
    required this.onBatteries,
    required this.onRadio,
    this.onPreflight,
    this.onMobility,
    this.onData,
    this.onSettings,
    this.onObservations,
    this.onGroundRoutes,
    this.profile,
    this.onProfiles,
    this.onAction,
    this.onLayer,
    this.allToolsExpanded = false,
    this.onClose,
  });
  final Future<void> Function() onSpots,
      onRoutes,
      onWeather,
      onDrones,
      onBatteries,
      onRadio;
  final Future<void> Function()? onPreflight;
  final Future<void> Function()? onMobility;
  final Future<void> Function()? onData;
  final Future<void> Function()? onSettings;
  final Future<void> Function()? onObservations;
  final Future<void> Function()? onGroundRoutes;
  final ActivityProfile? profile;
  final Future<void> Function()? onProfiles;
  final Future<void> Function(ActivityAction)? onAction;
  final Future<void> Function(ActivityLayer)? onLayer;
  final bool allToolsExpanded;

  /// Non-modal desktop panels close themselves rather than popping the route.
  final VoidCallback? onClose;

  Widget _tool(BuildContext context, ActivityTool tool) => switch (tool) {
    ActivityTool.groundRoutes => _item(
      context,
      Icons.hiking,
      context.translate(tool.label),
      onGroundRoutes ?? () async {},
    ),
    ActivityTool.observations => _item(
      context,
      Icons.sensors_outlined,
      context.translate(tool.label),
      onObservations ?? () async {},
    ),
    ActivityTool.places => _item(
      context,
      Icons.bookmark_outline,
      context.translate(tool.label),
      onSpots,
    ),
    ActivityTool.routes => _item(
      context,
      Icons.route_outlined,
      context.translate(tool.label),
      onRoutes,
    ),
    ActivityTool.mobility => _item(
      context,
      Icons.travel_explore,
      context.translate(tool.label),
      onMobility ?? () async {},
    ),
    ActivityTool.preflight => _item(
      context,
      Icons.checklist,
      context.translate(tool.label),
      onPreflight ?? () async {},
    ),
    ActivityTool.weather => _item(
      context,
      Icons.cloud_outlined,
      context.translate(tool.label),
      onWeather,
    ),
    ActivityTool.offline => _item(
      context,
      Icons.storage_outlined,
      context.translate(tool.label),
      onData ?? () async {},
    ),
    ActivityTool.equipment => ExpansionTile(
      title: Text(context.translate(tool.label)),
      leading: const Icon(Icons.flight_outlined),
      children: [
        _item(
          context,
          Icons.flight_outlined,
          context.translate("Drohnen"),
          onDrones,
        ),
        _item(
          context,
          Icons.battery_full_outlined,
          context.translate("Akkus"),
          onBatteries,
        ),
        _item(
          context,
          Icons.settings_input_antenna,
          context.translate("Funk & Video"),
          onRadio,
        ),
      ],
    ),
  };

  List<Widget> _workspace(BuildContext context) => [
    if (onProfiles != null)
      _item(context, Icons.person_outline, profile!.name, onProfiles!),
    if (!allToolsExpanded) ...[
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(context.translate("Arbeitsbereich")),
      ),
      for (final tool in profile!.tools) _tool(context, tool),
      if (onLayer != null && profile!.layers.isNotEmpty)
        ExpansionTile(
          title: Text(context.translate("Bevorzugte Ebenen")),
          leading: const Icon(Icons.layers_outlined),
          children: [
            for (final layer in profile!.layers)
              _item(
                context,
                Icons.layers_outlined,
                context.translate(layer.label),
                () => onLayer!(layer),
              ),
          ],
        ),
      const Divider(),
    ],
    ExpansionTile(
      key: ValueKey('all-tools-$allToolsExpanded-${profile!.id}'),
      initiallyExpanded: allToolsExpanded,
      leading: const Icon(Icons.apps),
      title: Text(context.translate("Alle Werkzeuge")),
      children: [
        for (final tool in ActivityTool.values) _tool(context, tool),
        if (onAction != null)
          ExpansionTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(context.translate("Kartenaktionen")),
            children: [
              for (final action in ActivityAction.values)
                _item(
                  context,
                  Icons.map_outlined,
                  context.translate(action.label),
                  () => onAction!(action),
                ),
            ],
          ),
        if (onLayer != null)
          ExpansionTile(
            title: Text(context.translate("Alle Kartenebenen")),
            children: [
              for (final layer in ActivityLayer.values)
                _item(
                  context,
                  Icons.layers_outlined,
                  context.translate(layer.label),
                  () => onLayer!(layer),
                ),
            ],
          ),
      ],
    ),
    if (onSettings != null)
      _item(
        context,
        Icons.settings_outlined,
        context.translate("Einstellungen"),
        onSettings!,
      ),
  ];
  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    Future<void> Function() action,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      if (onClose != null) {
        onClose!();
      } else {
        Navigator.pop(context);
      }
      unawaited(action());
    },
  );
  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MapFloatingSurface(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              ListTile(
                leading: Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text('FPVManager'),
                trailing: onClose == null
                    ? null
                    : IconButton(
                        tooltip: context.translate("Menü schließen"),
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                subtitle: Text(
                  profile == null
                      ? context.translate("Karte und Aktivitäten")
                      : context.translate("Karte und Aktivitäten"),
                ),
              ),
              const Divider(),
              if (profile != null) ..._workspace(context),
              if (profile == null) ...[
                if (onProfiles != null)
                  _item(
                    context,
                    Icons.person_outline,
                    context.translate("Aktivitätsprofile"),
                    onProfiles!,
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(context.translate("Planen & Entdecken")),
                ),
                _item(
                  context,
                  Icons.bookmark_outline,
                  context.translate("Gespeicherte Orte"),
                  onSpots,
                ),
                _item(
                  context,
                  Icons.route_outlined,
                  context.translate("Flugrouten"),
                  onRoutes,
                ),
                if (onMobility != null)
                  _item(
                    context,
                    Icons.travel_explore,
                    'Navigation & OSINT',
                    onMobility!,
                  ),
                if (onPreflight != null)
                  _item(
                    context,
                    Icons.checklist,
                    context.translate("Flugvorbereitung"),
                    onPreflight!,
                  ),
                _item(
                  context,
                  Icons.cloud_outlined,
                  context.translate("Wetter"),
                  onWeather,
                ),
                const Divider(indent: 16, endIndent: 16),
                if (onGroundRoutes != null)
                  _item(
                    context,
                    Icons.hiking,
                    context.translate("Bodenrouten"),
                    onGroundRoutes!,
                  ),
                if (onObservations != null)
                  _item(
                    context,
                    Icons.sensors_outlined,
                    context.translate("Messstationen"),
                    onObservations!,
                  ),
                ExpansionTile(
                  key: const PageStorageKey('equipment-navigation'),
                  leading: const Icon(Icons.flight_outlined),
                  title: Text(context.translate("Ausrüstung")),
                  children: [
                    _item(
                      context,
                      Icons.flight_outlined,
                      context.translate("Drohnen"),
                      onDrones,
                    ),
                    _item(
                      context,
                      Icons.battery_full_outlined,
                      context.translate("Akkus"),
                      onBatteries,
                    ),
                    _item(
                      context,
                      Icons.settings_input_antenna,
                      context.translate("Funk & Video"),
                      onRadio,
                    ),
                  ],
                ),
                if (onSettings != null)
                  _item(
                    context,
                    Icons.settings_outlined,
                    context.translate("Einstellungen"),
                    onSettings!,
                  ),
                if (onData != null) ...[
                  const Divider(),
                  _item(
                    context,
                    Icons.storage_outlined,
                    context.translate("Offline & Daten"),
                    onData!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
