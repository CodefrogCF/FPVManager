import 'dart:async';

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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Map layer error: $error')));
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
          Text('AIRSPACE', style: Theme.of(context).textTheme.labelLarge),

          const Divider(height: 24),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.shield_outlined),
            title: Text(source.name),
            subtitle: Text(
              controller.uasZonesLoading
                  ? 'Loading zone data...'
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
            'Polygon fill opacity: '
            '${(opacity * 100).round()}%',
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
                  'DATA SOURCE',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh UAS data',
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

          TextButton.icon(
            onPressed: () => showAirspaceSafetyPanel(context, controller),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Airspace safety & official sources'),
          ),
          const SizedBox(height: 8),

          _InfoRow(label: 'Provider', value: source.publisher),

          _InfoRow(
            label: 'Licence',
            value: source.licenseName ?? 'Not declared in source metadata',
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

          _InfoRow(
            label: 'Downloaded',
            value: _formatDownloadTime(controller.uasZonesDownloadedAt),
          ),
          _InfoRow(
            label: 'Data status',
            value: controller.uasDisplayedStatus.dataState.label,
          ),
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
          const Text(
            'Cached data is not verified current airspace information. Check official sources before flight.',
          ),
          if (provider.cacheError != null) Text(provider.cacheError!),
          TextButton.icon(
            onPressed: controller.isReady && controller.canClearUasCache
                ? () => _execute(controller.clearUasCache)
                : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear UAS dataset cache'),
          ),

          _InfoRow(
            label: 'Loaded features',
            value: controller.uasZonesFeatureCount?.toString() ?? '—',
          ),

          _InfoRow(
            label: 'Coverage',
            value: assessment == null
                ? 'Not assessed'
                : assessment.hasIssues
                ? 'Limited / incomplete data'
                : 'Not independently verified',
          ),
          if (assessment != null) ...[
            _InfoRow(
              label: 'Source features',
              value: assessment.sourceFeatureCount.toString(),
            ),
            if (assessment.skippedFeatureCount > 0)
              _InfoRow(
                label: 'Not displayed',
                value: assessment.skippedFeatureCount.toString(),
              ),
            for (final issue in assessment.issues)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(issue),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'A successful download does not establish complete airspace coverage. Other restrictions may apply.',
            ),
          ),

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

          _InfoRow(label: 'Source', value: source.dataUri.host),
          _InfoRow(label: 'Metadata', value: source.metadataUri.toString()),
          if (source.licenseUri != null)
            _InfoRow(
              label: 'Licence terms',
              value: source.licenseUri.toString(),
            ),
          if (displayed?.httpLastModified != null)
            _InfoRow(
              label: 'HTTP modified',
              value: displayed!.httpLastModified!,
            ),

          if (controller.uasZonesError != null || provider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                controller.uasZonesError ?? provider.error!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          const SizedBox(height: 16),

          Text(
            'Geographical UAS zones may restrict '
            'drone operations. The download time '
            'does not represent the official '
            'dataset publication date. '
            'Cache age and HTTP Last-Modified do not establish official validity. '
            'Always verify current flight '
            'restrictions using official sources.',
            style: Theme.of(context).textTheme.bodySmall,
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
