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
            ? context.localized(
                "Standort wird gesucht",
                (l10n) => l10n.globeStandortWirdGesucht33b02f57,
              )
            : controller.stale
            ? context.localized(
                "Letzter Standort · erneut orten",
                (l10n) => l10n.globeLetzterStandortErneutOrten9afe561d,
              )
            : context.localized(
                "Mein Standort · lange drücken für Optionen",
                (l10n) => l10n.globeMeinStandortLangeDrueckend4c6bff6,
              ),
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
                context.localized(
                  "Mein Standort",
                  (l10n) => l10n.commonMeinStandort98425c52,
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: context.localized(
                "Schließen",
                (l10n) => l10n.commonSchliessen44424b18,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Standort anzeigen",
              (l10n) => l10n.globeStandortAnzeigenca6f8a53,
            ),
          ),
          value: controller.enabled,
          onChanged: (value) =>
              unawaited(value ? controller.locate() : controller.disable()),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Standort verfolgen",
              (l10n) => l10n.globeStandortVerfolgen14ee16f9,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Kartenbewegung beendet die Verfolgung. Online-Karten können beim Zentrieren und Folgen den Standortbereich erkennen lassen.",
              (l10n) => l10n.globeKartenbewegungBeendetDieVerfolgung00211415,
            ),
          ),
          value: controller.following,
          onChanged: (value) => unawaited(controller.setFollowing(value)),
        ),
        if (controller.busy) const LinearProgressIndicator(),
        if (controller.message != null) Text(controller.message!),
        if (controller.fix case final fix?) ...[
          Text(
            controller.stale
                ? context.localized(
                    "Letzter bekannter Standort · veraltet",
                    (l10n) =>
                        l10n.globeLetzterBekannterStandortVeraltet04a9e861,
                  )
                : context.localized(
                    "Aktuelles GPS-Signal",
                    (l10n) => l10n.globeAktuellesGpsSignal291591fd,
                  ),
          ),
          Text(
            context.localizedWithArgs("Genauigkeit: ±{0} m", [
              fix.accuracyMeters.round(),
            ], (l10n, value) => l10n.globeGenauigkeitM4e998940(value(0))),
          ),
          Text(
            context.localizedWithArgs("Signalzeit: {0}", [
              fix.timeUtc.toLocal(),
            ], (l10n, value) => l10n.globeSignalzeiteb1b8546(value(0))),
          ),
          if (controller.heading case final heading?)
            Text(
              context.localizedWithArgs("Fahrtrichtung: {0}°", [
                heading.round(),
              ], (l10n, value) => l10n.globeFahrtrichtung8ce70d3a(value(0))),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(controller.locate()),
            icon: const Icon(Icons.my_location),
            label: Text(
              context.localized(
                "Auf Standort zentrieren",
                (l10n) => l10n.globeAufStandortZentrierene8973c1b,
              ),
            ),
          ),
        ],
      ],
    ),
  ),
);
