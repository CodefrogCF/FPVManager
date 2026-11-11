import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/models/scene_time.dart';

/// Shared by route planning and pre-flight settings; dates are stored in UTC.
class SceneTimeControl extends StatelessWidget {
  const SceneTimeControl({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final SceneTime value;
  final ValueChanged<SceneTime> onChanged;

  Future<void> _choose(BuildContext context) async {
    final initial = value.fixedUtc?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;
    onChanged(
      SceneTime(
        enabled: true,
        fixedUtc: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = value.fixedUtc?.toLocal();
    final formats = MaterialLocalizations.of(context);
    final label = local == null
        ? 'Jetzt · aktuelle Gerätezeit'
        : '${formats.formatFullDate(local)} · ${formats.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)} ${local.timeZoneName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.translate("Eigene Sonnen- und Mondzeit")),
          subtitle: Text(
            context.translate("Aus: Beleuchtung der Karte verwenden."),
          ),
          value: value.enabled,
          onChanged: (enabled) =>
              onChanged(SceneTime(enabled: enabled, fixedUtc: value.fixedUtc)),
        ),
        if (value.enabled) ...[
          Text(label),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => onChanged(const SceneTime(enabled: true)),
                icon: const Icon(Icons.update),
                label: Text(context.translate("Jetzt")),
              ),
              TextButton.icon(
                onPressed: () => _choose(context),
                icon: const Icon(Icons.event_outlined),
                label: Text(context.translate("Datum und Uhrzeit")),
              ),
            ],
          ),
          Text(
            context.translate(
              "Eingabe in der Zeitzone des Geräts; gespeichert in UTC. Nur Lichtvorschau, keine Wetter- oder Freigabeprüfung.",
            ),
          ),
        ],
      ],
    );
  }
}
