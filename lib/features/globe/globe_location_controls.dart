import 'dart:async';

import '../../core/localization/app_localizations.dart';

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
            ? context.translate("Standort wird gesucht")
            : controller.stale
            ? context.translate("Letzter Standort · erneut orten")
            : context.translate("Mein Standort · lange drücken für Optionen"),
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
                context.translate("Mein Standort"),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: context.translate("Schließen"),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Standort anzeigen")),
          value: controller.enabled,
          onChanged: (value) =>
              unawaited(value ? controller.locate() : controller.disable()),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Standort verfolgen")),
          subtitle: Text(
            context.translate("Kartenbewegung beendet die Verfolgung."),
          ),
          value: controller.following,
          onChanged: (value) => unawaited(controller.setFollowing(value)),
        ),
        if (controller.busy) const LinearProgressIndicator(),
        if (controller.message != null) Text(controller.message!),
        if (controller.fix case final fix?) ...[
          Text(
            controller.stale
                ? context.translate("Letzter bekannter Standort · veraltet")
                : context.translate("Aktuelles GPS-Signal"),
          ),
          Text(
            context.translate("Genauigkeit: ±{0} m", [
              fix.accuracyMeters.round(),
            ]),
          ),
          Text(context.translate("Signalzeit: {0}", [fix.timeUtc.toLocal()])),
          if (controller.heading case final heading?)
            Text(context.translate("Fahrtrichtung: {0}°", [heading.round()])),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(controller.locate()),
            icon: const Icon(Icons.my_location),
            label: Text(context.translate("Auf Standort zentrieren")),
          ),
        ],
      ],
    ),
  ),
);
