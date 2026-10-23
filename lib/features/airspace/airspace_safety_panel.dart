import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/api_access_policy.dart';
import 'api_credentials_section.dart';
import '../globe/globe_controller.dart';
import 'uas_restriction.dart';

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

class AirspaceSafetyPanel extends StatelessWidget {
  const AirspaceSafetyPanel({super.key, required this.controller});
  final GlobeController controller;

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
                    'Airspace & flight safety',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close safety panel',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Preflight information only. FPVManager cannot issue a flight authorisation or guarantee that a flight is legal or safe.',
            ),
            const SizedBox(height: 12),
            Text(
              'BAZL UAS geographical zones',
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
              dataset?.validity == null
                  ? 'Not supplied / not verified'
                  : 'Source validity metadata available; review official data',
            ),
            if (controller.uasNetworkMetrics case final metrics?)
              _SafetyDetail('Last GeoJSON HTTP/parse metrics', metrics.summary),
            if (controller.uasTransferMetrics case final transfer?)
              _SafetyDetail(
                'Last Cesium command (incl. acknowledgement)',
                '${transfer.characters} characters · encode '
                    '${transfer.encodeTime.inMilliseconds} ms · bridge/renderer '
                    '${transfer.acknowledgementTime.inMilliseconds} ms',
              ),
            if (controller.uasRenderMetrics case final render?) ...[
              _SafetyDetail(
                'Cesium GeoJSON load',
                '${render.loadMs.toStringAsFixed(1)} ms',
              ),
              _SafetyDetail(
                'Cesium datasource attach',
                '${render.attachMs.toStringAsFixed(1)} ms',
              ),
              _SafetyDetail(
                'First Cesium frame after attach',
                render.firstFrameMs == null
                    ? 'Not measured'
                    : '${render.firstFrameMs!.toStringAsFixed(1)} ms',
              ),
            ],
            _SafetyDetail(
              'Rendered features',
              controller.uasDatasetAssessment?.renderedFeatureCount
                      .toString() ??
                  'Not loaded',
            ),
            if (status.error != null)
              Text(
                'Last refresh failed: ${status.error!.message}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final problem in problems) Text('Data limitation: $problem'),
            const Divider(height: 32),
            Text(
              'Restriction legend (Cesium map)',
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
            const Text(
              'BAZL authorisation subtypes (same category, different applicable conditions):',
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
              Text('${item.key.label}: ${item.value} features'),
            if (controller.uasDatasetAssessment case final assessment?)
              _SafetyDetail(
                'Time-dependent source features',
                assessment.timeDependentFeatureCount.toString(),
              ),
            const Text(
              'Colors reflect the official restriction attribute (CodeRestrictionType), not the zone definition type COMMON. Blue does not mean flight clearance. Overlapping restrictions, validity, aircraft weight, altitude and local rules must be checked individually.',
            ),
            const Divider(height: 32),
            Text(
              'Temporary / time-dependent information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Skyguide DABS is a periodically published snapshot. NOTAM information can change between DABS editions. The authoritative original NOTAM and applicable AIP must be checked immediately before flying. DABS is not continuously updated.',
            ),
            const Text(
              'Automatic DABS/NOTAM availability: not connected. No assertion is made that temporary restrictions have been retrieved or checked.',
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
              'Manual preflight checklist',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              '1. Open current BAZL map, check every applicable overlapping zone and contact the competent authority when necessary.',
            ),
            const Text(
              '2. Read the latest DABS and original NOTAM for the entire flight period and route.',
            ),
            const Text(
              '3. Check altitude references, local/cantonal rules, aerodrome procedures, weather and obstacles.',
            ),
            const Text(
              '4. Recheck immediately before take-off; a recent download or an empty intersection result is not proof of permission.',
            ),
          ],
        );
      },
    ),
  );

  Color _categoryColor(UasRestrictionCategory category) =>
      Color(int.parse('ff${category.hexColor.substring(1)}', radix: 16));
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
                    const SnackBar(
                      content: Text(
                        'Could not open browser. Copy the URL instead.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open official source'),
            ),
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: uri.toString())),
              icon: const Icon(Icons.copy),
              label: const Text('Copy official link'),
            ),
          ],
        ),
      ],
    ),
  );
}
