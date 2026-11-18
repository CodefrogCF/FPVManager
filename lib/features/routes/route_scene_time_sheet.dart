import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../globe/scene_time_control.dart';
import 'route_editor_controller.dart';

Future<void> showRouteSceneTime(
  BuildContext context,
  RouteEditorController editor,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ListenableBuilder(
        listenable: editor,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.localized(
                  "Sonnen- und Mondzeit der Route",
                  (l10n) => l10n.routesSonnenUndMondzeitDer90b0d9c4,
                ),
              ),
            ),
            SceneTimeControl(
              value: editor.planning.sceneTime,
              onChanged: (value) => editor.configurePlanning(
                editor.planning.withSceneTime(value),
              ),
            ),
            Text(
              context.localized(
                "Wird mit der Route gespeichert. Eine feste Zeit bleibt stehen; „Jetzt“ läuft mit der Gerätezeit.",
                (l10n) => l10n.routesWirdMitDerRoutece20d1c9,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.localized(
                  "Fertig",
                  (l10n) => l10n.routesFertig708ad54e,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
