import 'package:flutter/material.dart';

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
            const ListTile(title: Text('Sonnen- und Mondzeit der Route')),
            SceneTimeControl(
              value: editor.planning.sceneTime,
              onChanged: (value) => editor.configurePlanning(
                editor.planning.withSceneTime(value),
              ),
            ),
            const Text(
              'Wird mit der Route gespeichert. Eine feste Zeit bleibt stehen; „Jetzt“ läuft mit der Gerätezeit.',
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    ),
  ),
);
