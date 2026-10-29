import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globe/globe_controller.dart';
import 'avalanche_bulletin.dart';

class AvalancheLayersSection extends StatefulWidget {
  const AvalancheLayersSection({super.key, required this.globe});
  final GlobeController globe;
  @override
  State<AvalancheLayersSection> createState() => _AvalancheLayersSectionState();
}

class _AvalancheLayersSectionState extends State<AvalancheLayersSection> {
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Einstellung konnte nicht gespeichert werden. Erneut versuchen.',
        );
      }
    }
  }

  Widget _link(String text, String url) => TextButton.icon(
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    icon: const Icon(Icons.open_in_new),
    label: Text(text),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.globe.avalanche,
    builder: (context, _) {
      final layer = widget.globe.avalanche, data = layer.status.dataset;
      final editable = widget.globe.canEditPreferences;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lawinenbulletin · SLF'),
            subtitle: Text(layer.message),
            value: layer.visible,
            onChanged: editable
                ? (v) => _run(() => layer.options(enabled: v))
                : null,
          ),
          if (layer.visible) ...[
            Slider(
              value: layer.opacity,
              label: '${(layer.opacity * 100).round()} %',
              onChanged: editable
                  ? (v) => _run(() => layer.options(alpha: v))
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: layer.period,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Darstellung der publizierten Tagesabschnitte',
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tagesübersicht')),
                DropdownMenuItem(
                  value: 'earlier',
                  child: Text('Früherer Tagesabschnitt'),
                ),
                DropdownMenuItem(
                  value: 'later',
                  child: Text('Späterer Tagesabschnitt'),
                ),
              ],
              onChanged: editable
                  ? (v) => _run(() => layer.options(selectedPeriod: v))
                  : null,
            ),
            const Text(
              'Die Tagesübersicht zeigt die höchste publizierte regionale Stufe. Höhenlagen, Expositionen und Lawinenprobleme stehen in der Beschreibung beim Antippen. Die Farbe gilt nicht pauschal für jeden Hang.',
            ),
            if (layer.loading) const LinearProgressIndicator(),
            OutlinedButton.icon(
              onPressed: layer.loading || layer.refreshWaitSeconds > 0
                  ? null
                  : () => layer.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(
                layer.refreshWaitSeconds > 0
                    ? 'Erneut aktualisieren in ${layer.refreshWaitSeconds} s'
                    : 'SLF-Bulletin aktualisieren',
              ),
            ),
            if (layer.error ?? _error case final String error)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (data != null) ...[
              Text(
                'Abruf / Prüfung: ${(data.lastCheckedAtUtc ?? data.fetchedAtUtc).toLocal()}',
              ),
              Text(
                'Publikation: ${data.publishedAtUtc?.toLocal() ?? "kein aktives Bulletin / nicht angegeben"}',
              ),
              if (data.validity != null)
                Text(
                  'Gültigkeit: ${data.validity!.fromUtc?.toLocal()} – ${data.validity!.untilUtc?.toLocal()}',
                ),
            ],
            const Text('Gefahrenstufen · regionale Übersicht'),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final level in [1, 2, 3, 4, 5, 0])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: Color(
                          const [
                            0xff89949e,
                            0xffccff66,
                            0xffffff00,
                            0xffff9900,
                            0xffff0000,
                            0xff660000,
                          ][level],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          level == 0
                              ? 'Unbekannt / alter Stand'
                              : '$level · ${avalancheLabels[level]}',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Text(
              'Grau: unbekannt oder veralteter / nicht bestätigter Stand. Abgelaufene Flächen werden ausgeblendet. Ein fehlendes Bulletin ist keine Entwarnung.',
            ),
          ],
          _link(
            'WSL-Institut für Schnee- und Lawinenforschung SLF · offizielles Bulletin',
            'https://www.slf.ch/de/lawinenbulletin-und-schneesituation/',
          ),
          if (layer.visible) ...[
            _link(
              'SLF-Rückmeldungen aus dem Gelände',
              'https://pro.slf.ch/reply/public/',
            ),
            _link(
              'Datenquelle und Lizenz · CC BY 4.0',
              'https://www.slf.ch/de/services-und-produkte/slf-datenservice/',
            ),
          ],
        ],
      );
    },
  );
}
