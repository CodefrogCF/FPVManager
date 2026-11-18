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
          title: Text(
            context.localized(
              "Eigene Sonnen- und Mondzeit",
              (l10n) => l10n.globeEigeneSonnenUndMondzeit785565c8,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Aus: Beleuchtung der Karte verwenden.",
              (l10n) => l10n.globeAusBeleuchtungDerKarte53fe9a28,
            ),
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
                label: Text(
                  context.localized("Jetzt", (l10n) => l10n.globeJetzt6b627c53),
                ),
              ),
              TextButton.icon(
                onPressed: () => _choose(context),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  context.localized(
                    "Datum und Uhrzeit",
                    (l10n) => l10n.globeDatumUndUhrzeit6b922369,
                  ),
                ),
              ),
            ],
          ),
          Text(
            context.localized(
              "Eingabe in der Zeitzone des Geräts; gespeichert in UTC. Nur Lichtvorschau, keine Wetter- oder Freigabeprüfung.",
              (l10n) => l10n.commonEingabeInDerZeitzone41488cc9,
            ),
          ),
        ],
      ],
    );
  }
}
