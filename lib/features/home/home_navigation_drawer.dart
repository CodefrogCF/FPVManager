import 'dart:async';

import 'package:flutter/material.dart';

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
  });
  final Future<void> Function() onSpots,
      onRoutes,
      onWeather,
      onDrones,
      onBatteries,
      onRadio;
  final Future<void> Function()? onPreflight;
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
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const ListTile(
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Equipment'),
          ),
          _item(context, Icons.flight_outlined, 'Drone profiles', onDrones),
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
    ),
  );
}
