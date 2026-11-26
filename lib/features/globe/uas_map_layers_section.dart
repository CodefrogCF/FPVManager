import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import '../airspace/airspace_safety_panel.dart';
import 'globe_controller.dart';

class UasMapLayersSection extends StatefulWidget {
  const UasMapLayersSection({super.key, required this.controller});
  final GlobeController controller;
  @override
  State<UasMapLayersSection> createState() => _UasMapLayersSectionState();
}

class _UasMapLayersSectionState extends State<UasMapLayersSection> {
  double? _previewOpacity;
  Timer? _ageTimer;

  @override
  void initState() {
    super.initState();
    // Age the visible cache status without fetching data or polling a service.
    _ageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  Future<void> _execute(Future<void> Function() command) async {
    try {
      await command();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedWithArgs("Map layer error: {0}", [
              error,
            ], (l10n, value) => l10n.globeMapLayerError65930212(value(0))),
          ),
        ),
      );
    }
  }

  String _formatDownloadTime(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    final utc = date.toUtc();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${utc.year}-'
        '${twoDigits(utc.month)}-'
        '${twoDigits(utc.day)} '
        '${twoDigits(utc.hour)}:'
        '${twoDigits(utc.minute)} UTC';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final opacity = _previewOpacity ?? controller.uasZonesFillOpacity;
      final source = controller.uasSource;
      final provider = controller.uasProviderStatus;
      final displayed = controller.uasDisplayedDataset;
      final assessment = controller.uasDatasetAssessment;
      final updateFailed =
          controller.uasZonesError != null ||
          provider.update == OsintUpdateState.failed;
      final validity =
          displayed?.validity?.at(provider.checkedAtUtc) ??
          OsintValidity.unknown;

      final canEditOpacity =
          controller.isReady &&
          controller.canEditPreferences &&
          controller.uasZonesVisible &&
          !controller.uasZonesLoading;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.shield_outlined),
            title: Text(source.name),
            subtitle: Text(
              controller.uasZonesLoading
                  ? context.localized(
                      "Loading zone data...",
                      (l10n) => l10n.globeLoadingZoneDatacd4362a5,
                    )
                  : source.publisher,
            ),
            value: controller.uasZonesVisible,
            onChanged:
                controller.isReady &&
                    controller.canEditPreferences &&
                    !controller.uasZonesLoading
                ? (visible) {
                    _execute(() => controller.setUasZonesVisible(visible));
                  }
                : null,
          ),

          if (controller.uasZonesLoading) const LinearProgressIndicator(),

          const SizedBox(height: 12),

          Text(
            context.localizedWithArgs("Polygon fill opacity: {0}%", [
              (opacity * 100).round(),
            ], (l10n, value) => l10n.globePolygonFillOpacityd148d398(value(0))),
          ),

          Slider(
            key: const ValueKey('uas-fill-opacity'),
            min: 0,
            max: 1,
            divisions: 20,
            value: opacity,
            onChanged: canEditOpacity
                ? (value) {
                    setState(() {
                      _previewOpacity = value;
                    });
                  }
                : null,
            onChangeEnd: canEditOpacity
                ? (value) async {
                    await _execute(
                      () => controller.setUasZonesFillOpacity(value),
                    );
                    if (!mounted) return;
                    setState(() => _previewOpacity = null);
                  }
                : null,
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  context.localized(
                    "Datenstand",
                    (l10n) => l10n.globeDatenstand0ce51d29,
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: context.localized(
                  "Refresh UAS data",
                  (l10n) => l10n.globeRefreshUasData3aea6b96,
                ),
                onPressed:
                    controller.isReady &&
                        controller.canEditPreferences &&
                        controller.uasZonesVisible &&
                        !controller.uasZonesLoading
                    ? () => _execute(controller.refreshUasZones)
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          _InfoRow(
            label: 'Update',
            value: controller.uasZonesLoading
                ? 'Updating...'
                : updateFailed
                ? (displayed == null
                      ? 'Update failed'
                      : 'Update failed — previous map data retained')
                : displayed == null
                ? 'Not loaded'
                : 'Loaded',
          ),
          if (controller.developerMenusEnabled)
            _InfoRow(
              label: 'Data status',
              value: controller.uasDisplayedStatus.dataState.label,
            ),
          // Cache freshness is preflight information, not a developer-only
          // performance diagnostic. Keep it visible in public builds.
          _InfoRow(
            label: 'Cache status',
            value: switch (controller.uasDataFreshness) {
              OsintFreshness.notLoaded => 'Not loaded',
              OsintFreshness.fresh => 'Within local cache lifetime',
              OsintFreshness.stale => 'Cache expired — refresh recommended',
              OsintFreshness.clockSkew => 'Device clock precedes download',
            },
          ),
          _InfoRow(
            label: 'Official validity',
            value: switch (validity) {
              OsintValidity.unknown => 'Not supplied by this dataset',
              OsintValidity.notYetValid => 'Not yet applicable',
              OsintValidity.withinPeriod => 'Within declared period',
              OsintValidity.expired => 'Declared period expired',
            },
          ),
          _InfoRow(
            label: 'Coverage',
            value: assessment == null
                ? 'Not assessed'
                : assessment.hasIssues
                ? 'Limited / incomplete data'
                : 'Not independently verified',
          ),
          if (assessment != null && assessment.issues.isNotEmpty)
            Text(assessment.issues.first),
          Text(
            context.localized(
              "Weitere Einschränkungen möglich. Vor dem Flug amtliche Quellen prüfen.",
              (l10n) => l10n.globeWeitereEinschraenkungenMoeglichVor9c93ae78,
            ),
          ),
          TextButton.icon(
            onPressed: () => showAirspaceSafetyPanel(context, controller),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(
              context.localized(
                "Amtliche Quellen & Sicherheit",
                (l10n) => l10n.globeAmtlicheQuellenSicherheit68a6f080,
              ),
            ),
          ),
          ExpansionTile(
            key: const PageStorageKey('map-airspace-source-details'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              context.localized(
                "Daten & Quellen",
                (l10n) => l10n.globeDatenQuellen0b5b5779,
              ),
            ),
            children: [
              _InfoRow(label: 'Provider', value: source.publisher),

              _InfoRow(
                label: 'Licence',
                value: source.licenseName ?? 'Not declared in source metadata',
              ),

              _InfoRow(
                label: 'Downloaded',
                value: _formatDownloadTime(controller.uasZonesDownloadedAt),
              ),
              if (controller.developerMenusEnabled)
                _InfoRow(
                  label: 'Source checked',
                  value: displayed?.lastCheckedAtUtc == null
                      ? 'Not checked by this adapter'
                      : _formatDownloadTime(displayed!.lastCheckedAtUtc),
                ),
              _InfoRow(
                label: 'Published',
                value: displayed?.publishedAtUtc == null
                    ? 'Not supplied by this dataset'
                    : _formatDownloadTime(displayed!.publishedAtUtc),
              ),
              if (controller.developerMenusEnabled &&
                  provider.cacheError != null)
                Text(provider.cacheError!),
              if (controller.developerMenusEnabled)
                TextButton.icon(
                  onPressed: controller.isReady && controller.canClearUasCache
                      ? () => _execute(controller.clearUasCache)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    context.localized(
                      "Clear UAS dataset cache",
                      (l10n) => l10n.globeClearUasDatasetCacheaad7bb57,
                    ),
                  ),
                ),

              _InfoRow(
                label: 'Loaded features',
                value: controller.uasZonesFeatureCount?.toString() ?? '—',
              ),
              const SizedBox(height: 8),

              if (controller.developerMenusEnabled && assessment != null) ...[
                _InfoRow(
                  label: 'Source features',
                  value: assessment.sourceFeatureCount.toString(),
                ),
                if (assessment.skippedFeatureCount > 0)
                  _InfoRow(
                    label: 'Not displayed',
                    value: assessment.skippedFeatureCount.toString(),
                  ),
                for (final issue in assessment.issues.skip(1))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(issue),
                  ),
              ],

              if (displayed?.validity?.fromUtc != null)
                _InfoRow(
                  label: 'Valid from',
                  value: _formatDownloadTime(displayed!.validity!.fromUtc),
                ),
              if (displayed?.validity?.untilUtc != null)
                _InfoRow(
                  label: 'Valid until',
                  value: _formatDownloadTime(displayed!.validity!.untilUtc),
                ),

              // The dataset endpoint and metadata are part of source
              // provenance, even when developer menus are disabled.
              _InfoRow(label: 'Source', value: source.dataUri.host),
              _InfoRow(label: 'Metadata', value: source.metadataUri.toString()),
              if (source.licenseUri != null)
                _InfoRow(
                  label: 'Licence terms',
                  value: source.licenseUri.toString(),
                ),
              if (controller.developerMenusEnabled &&
                  displayed?.httpLastModified != null)
                _InfoRow(
                  label: 'HTTP modified',
                  value: displayed!.httpLastModified!,
                ),
            ],
          ),
          if (controller.uasZonesError != null || provider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                // A failed renderer import must remain actionable in public
                // builds. The generic error hid whether an existing dataset
                // remained usable or which update failed.
                controller.uasZonesError ?? provider.error!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
