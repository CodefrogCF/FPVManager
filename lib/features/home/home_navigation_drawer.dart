import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/map_floating_surface.dart';

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
  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    Future<void> Function() action,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
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
                subtitle: Text('Local flight planning'),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Plan & explore'),
              ),
              _item(context, Icons.bookmark_outline, 'FPV Spots', onSpots),
              _item(context, Icons.route_outlined, 'Flight routes', onRoutes),
              if (onMobility != null)
                _item(
                  context,
                  Icons.travel_explore,
                  'Mobility & OSINT',
                  onMobility!,
                ),
              if (onPreflight != null)
                _item(
                  context,
                  Icons.checklist,
                  'Preflight & Telemetry',
                  onPreflight!,
                ),
              _item(
                context,
                Icons.cloud_outlined,
                'Weather & spot suitability',
                onWeather,
              ),
              const Divider(indent: 16, endIndent: 16),
              ExpansionTile(
                key: const PageStorageKey('equipment-navigation'),
                leading: const Icon(Icons.flight_outlined),
                title: const Text('Equipment'),
                subtitle: const Text('Drones, batteries & radio'),
                children: [
                  _item(
                    context,
                    Icons.flight_outlined,
                    'Drone profiles',
                    onDrones,
                  ),
                  _item(
                    context,
                    Icons.battery_full_outlined,
                    'Battery inventory',
                    onBatteries,
                  ),
                  _item(
                    context,
                    Icons.settings_input_antenna,
                    'Radio & video equipment',
                    onRadio,
                  ),
                ],
              ),
              if (onSettings != null)
                _item(
                  context,
                  Icons.settings_outlined,
                  'Einstellungen',
                  onSettings!,
                ),
              if (onData != null) ...[
                const Divider(),
                _item(
                  context,
                  Icons.storage_outlined,
                  'Offline & personal data',
                  onData!,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
