import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';
import '../globe/map_display_section.dart';
import '../globe/globe_location_controls.dart';
import '../help/guides_screen.dart';

enum AppSettingsSection { display, controls, sources, dataPrivacy }

/// Reuses existing controllers and feature screens. This route owns no database,
/// credential vault or second copy of the user's preferences.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({
    super.key,
    required this.globe,
    required this.onFlightSettings,
    required this.onWeather,
    required this.onTraffic,
    required this.onAirspace,
    required this.onData,
    this.section,
  });
  final GlobeController globe;
  final Future<void> Function() onFlightSettings,
      onWeather,
      onTraffic,
      onAirspace,
      onData;
  final AppSettingsSection? section;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Einstellung konnte nicht übernommen werden. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    }
  }

  AppSettingsScreen _section(AppSettingsSection value) => AppSettingsScreen(
    globe: globe,
    onFlightSettings: onFlightSettings,
    onWeather: onWeather,
    onTraffic: onTraffic,
    onAirspace: onAirspace,
    onData: onData,
    section: value,
  );
  Widget _link(
    BuildContext context,
    IconData icon,
    String title,
    Future<void> Function() action, {
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _run(context, action),
  );
  @override
  Widget build(BuildContext context) {
    const titles = {
      AppSettingsSection.display: 'Darstellung und Karte',
      AppSettingsSection.controls: 'Steuerung',
      AppSettingsSection.sources: 'Datenquellen und Zugänge',
      AppSettingsSection.dataPrivacy: 'Offline und Datenschutz',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(section == null ? 'Einstellungen' : titles[section]!),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListenableBuilder(
              listenable: globe,
              builder: (context, _) => ListView(
                key: PageStorageKey(section),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  if (globe.preferencesLoading) const LinearProgressIndicator(),
                  if (globe.preferencesError != null) ...[
                    Text(
                      globe.preferencesError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: globe.preferencesLoading
                              ? null
                              : () => globe.preferencesLoadFailed
                                    ? globe.retryLoadingPreferences()
                                    : globe.retrySavingPreferences(),
                          child: const Text('Retry'),
                        ),
                        if (globe.preferencesLoadFailed)
                          TextButton(
                            onPressed: globe.resetPreferences,
                            child: const Text('Reset map preferences'),
                          ),
                      ],
                    ),
                  ],
                  if (section == null) ...[
                    for (final value in AppSettingsSection.values)
                      _link(
                        context,
                        switch (value) {
                          AppSettingsSection.display => Icons.layers_outlined,
                          AppSettingsSection.controls => Icons.gamepad_outlined,
                          AppSettingsSection.sources => Icons.cloud_outlined,
                          AppSettingsSection.dataPrivacy =>
                            Icons.privacy_tip_outlined,
                        },
                        titles[value]!,
                        () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(builder: (_) => _section(value)),
                        ),
                      ),
                    const Divider(),
                    _link(
                      context,
                      Icons.menu_book_outlined,
                      'Guides und Hilfe',
                      () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => const GuidesScreen()),
                      ),
                    ),
                  ],
                  if (section == AppSettingsSection.display)
                    MapDisplaySection(controller: globe),
                  if (section == AppSettingsSection.controls) ...[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Touch-Steuerung anzeigen'),
                      value: globe.touchControlsVisible,
                      onChanged: globe.canEditPreferences
                          ? (value) => _run(
                              context,
                              () => globe.setTouchControlsVisible(value),
                            )
                          : null,
                    ),
                    _link(
                      context,
                      Icons.flight_outlined,
                      'Flug- und Controller-Einstellungen',
                      onFlightSettings,
                      subtitle: 'Für die nächste Simulation',
                    ),
                    _link(
                      context,
                      Icons.my_location,
                      'Standortanzeige',
                      () => showGlobeLocationSettings(context, globe.location),
                    ),
                    const GuideLink(GuideTopic.controls),
                  ],
                  if (section == AppSettingsSection.sources) ...[
                    _link(
                      context,
                      Icons.traffic_outlined,
                      'Verkehrsdaten und ASTRA-Zugänge',
                      onTraffic,
                    ),
                    _link(
                      context,
                      Icons.cloud_outlined,
                      'Wetter und Anbieter',
                      onWeather,
                    ),
                    _link(
                      context,
                      Icons.shield_outlined,
                      'Luftraum und offizielle Quellen',
                      onAirspace,
                    ),
                    const GuideLink(GuideTopic.freshness),
                    const GuideLink(GuideTopic.privacy),
                  ],
                  if (section == AppSettingsSection.dataPrivacy) ...[
                    _link(
                      context,
                      Icons.storage_outlined,
                      'Offline-Karten und persönliche Daten',
                      onData,
                    ),
                    const GuideLink(GuideTopic.offline),
                    const GuideLink(GuideTopic.privacy),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
