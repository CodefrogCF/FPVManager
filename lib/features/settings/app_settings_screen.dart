import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../globe/globe_controller.dart';
import '../globe/map_display_section.dart';
import '../globe/globe_location_controls.dart';
import '../help/guides_screen.dart';
import '../mobility/navigation_environment_section.dart';

enum AppSettingsSection { display, controls, navigation, sources, dataPrivacy }

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
    this.onProfiles,
    this.onMapLayers,
    this.onLanguageSelected,
  });
  final GlobeController globe;
  final Future<void> Function() onFlightSettings,
      onWeather,
      onTraffic,
      onAirspace,
      onData;
  final AppSettingsSection? section;
  final Future<void> Function()? onProfiles, onMapLayers;
  final Future<void> Function(AppLanguage)? onLanguageSelected;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.translate(
                'Einstellung konnte nicht übernommen werden. Bitte erneut versuchen.',
              ),
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
    onProfiles: onProfiles,
    onMapLayers: onMapLayers,
    onLanguageSelected: onLanguageSelected,
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
      AppSettingsSection.display: 'Karte & Ansicht',
      AppSettingsSection.controls: 'Flug & Bedienung',
      AppSettingsSection.navigation: 'Navigation',
      AppSettingsSection.sources: 'Datenquellen',
      AppSettingsSection.dataPrivacy: 'Offline & Daten',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate(
            section == null ? 'Einstellungen' : titles[section]!,
          ),
        ),
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
                      context.translate(globe.preferencesError!),
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
                          child: Text(context.translate("Erneut versuchen")),
                        ),
                        if (globe.preferencesLoadFailed)
                          TextButton(
                            onPressed: globe.resetPreferences,
                            child: Text(
                              context.translate(
                                "Karteneinstellungen zurücksetzen",
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (section == null) ...[
                    if (onLanguageSelected != null)
                      _LanguageSetting(
                        onChanged: (language) =>
                            _run(context, () => onLanguageSelected!(language)),
                      ),
                    if (onProfiles != null)
                      _link(
                        context,
                        Icons.person_outline,
                        context.translate("Aktivitätsprofile"),
                        onProfiles!,
                      ),
                    for (final value in AppSettingsSection.values)
                      _link(
                        context,
                        switch (value) {
                          AppSettingsSection.display => Icons.layers_outlined,
                          AppSettingsSection.controls => Icons.gamepad_outlined,
                          AppSettingsSection.navigation =>
                            Icons.navigation_outlined,
                          AppSettingsSection.sources => Icons.cloud_outlined,
                          AppSettingsSection.dataPrivacy =>
                            Icons.privacy_tip_outlined,
                        },
                        context.translate(titles[value]!),
                        value == AppSettingsSection.display &&
                                onMapLayers != null
                            ? onMapLayers!
                            : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _section(value),
                                ),
                              ),
                      ),
                    const Divider(),
                    _link(
                      context,
                      Icons.menu_book_outlined,
                      context.translate("Hilfe"),
                      () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => const GuidesScreen()),
                      ),
                    ),
                  ],
                  if (section == AppSettingsSection.display)
                    if (onMapLayers != null)
                      _link(
                        context,
                        Icons.layers_outlined,
                        context.translate("Karte & Ansicht"),
                        onMapLayers!,
                      )
                    else
                      MapDisplaySection(controller: globe),
                  if (section == AppSettingsSection.navigation)
                    NavigationEnvironmentSection(settings: globe),
                  if (section == AppSettingsSection.controls) ...[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.translate("Touch-Steuerung anzeigen"),
                      ),
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
                      context.translate("Flugsimulator & Controller"),
                      onFlightSettings,
                      subtitle: context.translate("Für die nächste Simulation"),
                    ),
                    _link(
                      context,
                      Icons.my_location,
                      context.translate("Standortanzeige"),
                      () => showGlobeLocationSettings(context, globe.location),
                    ),
                    const GuideLink(GuideTopic.controls),
                  ],
                  if (section == AppSettingsSection.sources) ...[
                    _link(
                      context,
                      Icons.traffic_outlined,
                      context.translate("Verkehr & Zugänge"),
                      onTraffic,
                    ),
                    _link(
                      context,
                      Icons.cloud_outlined,
                      context.translate("Wetteranbieter"),
                      onWeather,
                    ),
                    _link(
                      context,
                      Icons.shield_outlined,
                      context.translate("Luftraumquellen"),
                      onAirspace,
                    ),
                    _link(
                      context,
                      Icons.description_outlined,
                      context.translate("Open-Source-Lizenzen"),
                      () async {
                        showLicensePage(
                          context: context,
                          applicationName: 'FPVManager',
                        );
                      },
                    ),
                    const GuideLink(GuideTopic.freshness),
                    const GuideLink(GuideTopic.privacy),
                  ],
                  if (section == AppSettingsSection.dataPrivacy) ...[
                    _link(
                      context,
                      Icons.storage_outlined,
                      context.translate("Offline-Karten & Daten"),
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

class _LanguageSetting extends StatefulWidget {
  const _LanguageSetting({required this.onChanged});

  final Future<void> Function(AppLanguage) onChanged;

  @override
  State<_LanguageSetting> createState() => _LanguageSettingState();
}

class _LanguageSettingState extends State<_LanguageSetting> {
  bool _saving = false;

  Future<void> _select(AppLanguage? language) async {
    if (language == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onChanged(language);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = AppLanguage.fromCode(
      Localizations.localeOf(context).languageCode,
    );
    final label = context.translate('Sprache');
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(label),
      trailing: DropdownButton<AppLanguage>(
        key: const ValueKey('app-language'),
        value: current,
        items: [
          for (final language in AppLanguage.values)
            DropdownMenuItem(
              value: language,
              child: Text(language.nameInLanguage),
            ),
        ],
        onChanged: _saving ? null : _select,
      ),
    );
  }
}
