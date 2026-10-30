import 'dart:async';

import 'package:flutter/material.dart';

import 'globe_location_controller.dart';
import 'map_floating_surface.dart';

class GlobeLocationButton extends StatelessWidget {
  const GlobeLocationButton({super.key, required this.controller});
  final GlobeLocationController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => GestureDetector(
      onLongPress: () => showGlobeLocationSettings(context, controller),
      child: IconButton(
        key: const ValueKey('globe-locate'),
        tooltip: controller.busy
            ? 'Standort wird gesucht'
            : controller.stale
            ? 'Letzter Standort · erneut orten'
            : 'Mein Standort · lange drücken für Optionen',
        onPressed: controller.busy
            ? null
            : () => unawaited(controller.locate()),
        icon: Icon(
          controller.following ? Icons.gps_fixed : Icons.my_location,
          color:
              controller.enabled && !controller.stale && controller.fix != null
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
    ),
  );
}

Future<void> showGlobeLocationSettings(
  BuildContext context,
  GlobeLocationController controller,
) => showMapPanel<void>(
  context,
  builder: (context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mein Standort',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Schließen',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Standort anzeigen'),
          value: controller.enabled,
          onChanged: (value) =>
              unawaited(value ? controller.locate() : controller.disable()),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Standort verfolgen'),
          subtitle: const Text('Kartenbewegung beendet die Verfolgung.'),
          value: controller.following,
          onChanged: (value) => unawaited(controller.setFollowing(value)),
        ),
        if (controller.busy) const LinearProgressIndicator(),
        if (controller.message != null) Text(controller.message!),
        if (controller.fix case final fix?) ...[
          Text(
            controller.stale
                ? 'Letzter bekannter Standort · veraltet'
                : 'Aktuelles GPS-Signal',
          ),
          Text('Genauigkeit: ±${fix.accuracyMeters.round()} m'),
          Text('Signalzeit: ${fix.timeUtc.toLocal()}'),
          if (controller.heading case final heading?)
            Text('Fahrtrichtung: ${heading.round()}°'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(controller.locate()),
            icon: const Icon(Icons.my_location),
            label: const Text('Auf Standort zentrieren'),
          ),
        ],
      ],
    ),
  ),
);
