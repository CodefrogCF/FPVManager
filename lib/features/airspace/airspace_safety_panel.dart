import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/api_access_policy.dart';
import '../../core/osint/osint_source.dart';
import 'api_credentials_section.dart';
import '../globe/globe_controller.dart';
import 'uas_restriction.dart';
import '../help/guides_screen.dart';

/// Official destinations only. No scraping, authentication, tracking or
/// unlicensed redistribution of DABS/NOTAM contents is performed.
class AirspaceOfficialSources {
  static final Uri dabs = Uri.parse(
    'https://skybriefing.com/de/web/guest/dabs',
  );
  static final Uri notam = Uri.parse('https://skybriefing.com/');
  static final Uri uasMap = Uri.parse(
    'https://map.geo.admin.ch/?layers=ch.bazl.einschraenkungen-drohnen',
  );
  static final Uri bazl = Uri.parse(
    'https://www.bazl.admin.ch/de/geografische-uas-gebiete',
  );
  static final Uri skyguide = Uri.parse(
    'https://www.skyguide.ch/de/dienstleistungen/luftfahrtinformationsdienste',
  );
}

Future<void> showAirspaceSafetyPanel(
  BuildContext context,
  GlobeController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxWidth: 680,
    maxHeight: MediaQuery.sizeOf(context).height * .9,
  ),
  builder: (_) => AirspaceSafetyPanel(controller: controller),
);

class AirspaceSafetyPanel extends StatefulWidget {
  const AirspaceSafetyPanel({super.key, required this.controller});
  final GlobeController controller;

  @override
  State<AirspaceSafetyPanel> createState() => _AirspaceSafetyPanelState();
}

class _AirspaceSafetyPanelState extends State<AirspaceSafetyPanel> {
  Timer? _ageTimer;
  GlobeController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.uasDisplayedStatus;
        final dataset = status.dataset;
        final problems =
            controller.uasDatasetAssessment?.issues ?? const <String>[];
        final downloaded =
            dataset?.fetchedAtUtc.toIso8601String() ?? 'Not available';
        final checked =
            dataset?.lastCheckedAtUtc?.toIso8601String() ?? 'Not available';
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.translate("Airspace & flight safety"),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.translate("Close safety panel"),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.translate(
                "Preflight information only. FPVManager cannot issue a flight authorisation or guarantee that a flight is legal or safe.",
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.translate("BAZL UAS geographical zones"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _SafetyDetail('Local data state', status.dataState.label),
            _SafetyDetail(
              'Source',
              '${controller.uasSource.publisher} — ${controller.uasSource.name}',
            ),
            _SafetyDetail('Downloaded (UTC)', downloaded),
            _SafetyDetail('Last HTTP check (UTC)', checked),
            _SafetyDetail(
              'Official validity period',
              officialValidityLabel(dataset?.validity),
            ),
            _SafetyDetail(
              'Rendered features',
              controller.uasDatasetAssessment?.renderedFeatureCount
                      .toString() ??
                  'Not loaded',
            ),
            if (status.error != null)
              Text(
                context.translate("Last refresh failed: {0}", [
                  status.error!.message,
                ]),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final problem in problems)
              Text(context.translate("Data limitation: {0}", [problem])),
            const Divider(height: 32),
            Text(
              context.translate("Restriction legend (Cesium map)"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final category in UasRestrictionCategory.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _categoryColor(category),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(category.label),
              ),
            Text(
              context.translate(
                "BAZL authorisation subtypes (same category, different applicable conditions):",
              ),
            ),
            for (final entry in const [
              (
                '#ef6c00',
                'Orange — authorisation regardless of weight (MTOM_ALL)',
              ),
              (
                '#b8860b',
                'Ochre — authorisation from a specified weight (MTOM_FROM)',
              ),
              ('#7b1fa2', 'Purple — CTR rule, above 120 m AGL (CTR)'),
            ])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse('ff${entry.$1.substring(1)}', radix: 16),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(entry.$2),
              ),
            for (final item
                in (controller.uasDatasetAssessment?.categoryCounts.entries ??
                    const <MapEntry<UasRestrictionCategory, int>>[]))
              Text(
                context.translate("{0}: {1} features", [
                  item.key.label,
                  item.value,
                ]),
              ),
            if (controller.uasDatasetAssessment case final assessment?)
              _SafetyDetail(
                'Time-dependent source features',
                assessment.timeDependentFeatureCount.toString(),
              ),
            Text(
              context.translate(
                "Colors describe source restrictions. Blue is not flight clearance; check every overlapping zone and its conditions.",
              ),
            ),
            const GuideLink(GuideTopic.airspace),
            const Divider(height: 32),
            Text(
              context.translate("Temporary / time-dependent information"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.translate(
                "Check the latest DABS and original NOTAM immediately before flying. DABS is a periodic snapshot.",
              ),
            ),
            Text(
              context.translate(
                "Automatic DABS/NOTAM availability: not connected. No assertion is made that temporary restrictions have been retrieved or checked.",
              ),
            ),
            const SizedBox(height: 8),
            ApiCredentialsSection(policies: OfficialAirspaceApis.sources),
            const SizedBox(height: 12),
            _SourceReference(
              'Skyguide DABS — official bulletin',
              AirspaceOfficialSources.dabs,
            ),
            _SourceReference(
              'Skybriefing — NOTAM / official briefing',
              AirspaceOfficialSources.notam,
            ),
            _SourceReference(
              'BAZL official drone restrictions map',
              AirspaceOfficialSources.uasMap,
            ),
            _SourceReference(
              'BAZL UAS geographical zones guidance',
              AirspaceOfficialSources.bazl,
            ),
            _SourceReference(
              'Skyguide AIM publication guidance',
              AirspaceOfficialSources.skyguide,
            ),
            const Divider(height: 32),
            Text(
              context.translate("Manual preflight checklist"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.translate(
                "1. Open current BAZL map, check every applicable overlapping zone and contact the competent authority when necessary.",
              ),
            ),
            Text(
              context.translate(
                "2. Read the latest DABS and original NOTAM for the entire flight period and route.",
              ),
            ),
            Text(
              context.translate(
                "3. Check altitude references, local/cantonal rules, aerodrome procedures, weather and obstacles.",
              ),
            ),
            Text(
              context.translate(
                "4. Recheck immediately before take-off; a recent download or an empty intersection result is not proof of permission.",
              ),
            ),
          ],
        );
      },
    ),
  );

  Color _categoryColor(UasRestrictionCategory category) =>
      Color(int.parse('ff${category.hexColor.substring(1)}', radix: 16));
}

String officialValidityLabel(OsintValidityPeriod? validity) {
  if (validity == null ||
      validity.fromUtc == null && validity.untilUtc == null) {
    return 'Not supplied / not verified';
  }
  return '${validity.fromUtc?.toIso8601String() ?? 'Start not supplied'} '
      'to ${validity.untilUtc?.toIso8601String() ?? 'End not supplied'} (UTC)';
}

class _SafetyDetail extends StatelessWidget {
  const _SafetyDetail(this.name, this.value);
  final String name;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$name: $value'),
  );
}

/// Always opens an official HTTPS source outside FPVManager's embedded Cesium
/// WebView. Copy fallback remains available if browser access is blocked.
class _SourceReference extends StatelessWidget {
  const _SourceReference(this.label, this.uri);
  final String label;
  final Uri uri;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        SelectableText(uri.toString()),
        Wrap(
          spacing: 12,
          children: [
            TextButton.icon(
              onPressed: () async {
                var opened = false;
                try {
                  opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  // A missing browser or platform plugin is not a flight-safety status.
                }
                if (!opened && context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.translate(
                          "Could not open browser. Copy the URL instead.",
                        ),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(context.translate("Open official source")),
            ),
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: uri.toString())),
              icon: const Icon(Icons.copy),
              label: Text(context.translate("Copy official link")),
            ),
          ],
        ),
      ],
    ),
  );
}
