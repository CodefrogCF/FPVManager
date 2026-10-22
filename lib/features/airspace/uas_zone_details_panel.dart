import 'package:flutter/material.dart';

import '../../core/osint/osint_source.dart';
import 'uas_zone_details.dart';
import 'uas_restriction.dart';

class UasZoneDetailsPanel extends StatelessWidget {
  const UasZoneDetailsPanel({
    super.key,
    required this.zone,
    required this.source,
    required this.downloadedAtUtc,
    required this.onClose,
  });
  final UasZoneDetails zone;
  final OsintSource source;
  final DateTime? downloadedAtUtc;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(
              zone.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              source.publisher,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Close details',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              zone.value('restriction') ?? 'Restriction not provided by source',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(zone.restriction.category.label),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(zone.restriction.restrictionMeaning),
          ),
          TextButton.icon(
            icon: const Icon(Icons.info_outline),
            label: const Text('Inspect restrictions'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.sizeOf(context).height * .85,
              ),
              builder: (_) => UasZoneDetailsSheet(
                zone: zone,
                source: source,
                downloadedAtUtc: downloadedAtUtc,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class UasZoneDetailsSheet extends StatelessWidget {
  const UasZoneDetailsSheet({
    super.key,
    required this.zone,
    required this.source,
    required this.downloadedAtUtc,
  });
  final UasZoneDetails zone;
  final OsintSource source;
  final DateTime? downloadedAtUtc;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  zone.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close zone inspection',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (zone.missingFields.isNotEmpty)
            _Notice(
              'Source details missing: ${zone.missingFields.join(', ')}.',
            ),
          if (zone.hasDisplayLimits)
            _Notice(
              'Limited attribute display. ${zone.omittedAttributeCount} attributes omitted. '
              '${zone.truncatedAttributes.isEmpty ? '' : 'Shortened or unavailable values: ${zone.truncatedAttributes.join(', ')}.'}',
            ),
          _heading(context, 'Interpreted restriction rule'),
          _DetailRow('Classification', zone.restriction.category.label),
          _DetailRow('Rule applicability', zone.restriction.restrictionMeaning),
          _DetailRow('Authority', zone.restriction.authority.name ?? 'Not provided'),
          _DetailRow('Authorisation contact', zone.restriction.authority.role ?? 'Not provided'),
          if (zone.restriction.category == UasRestrictionCategory.unknown)
            const _Notice('Unknown or unsupported restriction code: no permission can be inferred.'),
          if (zone.restriction.hasUnverifiedTimeRules)
            const _Notice('Potential time-dependent restriction: activation is NOT calculated. Consult original validity and daily time rules.'),
          for (final issue in zone.restriction.unrecognisedValues)
            _Notice(issue),
          _heading(context, 'Source classification'),
          ..._fields({
            'identifier': 'Identifier',
            'type': 'Zone type (source code)',
            'reason': 'Reason / category (source code)',
            'otherReasonInfo': 'Additional reason',
          }),
          _heading(context, 'Restrictions as supplied'),
          ..._fields({
            'restriction': 'Restriction code',
            'restrictionConditions': 'Restriction conditions',
            'message': 'Source message',
          }),
          _heading(context, 'Height limits'),
          _DetailRow('Lower limit', zone.heightLimit(upper: false)),
          _DetailRow('Upper limit', zone.heightLimit(upper: true)),
          const Text(
            'Each limit retains its own source unit and vertical reference.',
          ),
          _heading(context, 'Applicability as supplied'),
          ..._fields({'permanent': 'Permanent (source code)'}),
          if (zone.value('permanent') != 'YES' ||
              zone.value('startDateTime') != null ||
              zone.value('endDateTime') != null)
            ..._fields({
              'startDateTime': 'Start date/time',
              'endDateTime': 'End date/time',
            }),
          ..._fields({
            'startTime': 'Daily start (source time/offset)',
            'endTime': 'Daily end (source time/offset)',
          }),
          const Text(
            'Times and offsets are shown as supplied; applicability is not calculated.',
          ),
          _heading(context, 'Authority and contact'),
          ..._fields({
            'authorityName': 'Authority',
            'service': 'Service',
            'contactName': 'Contact',
            'siteURL': 'Source website',
            'email': 'Email',
            'phone': 'Phone',
            'purpose': 'Contact purpose',
            'intervalBefore': 'Advance notice (source value)',
          }),
          _heading(context, 'Dataset provenance'),
          _DetailRow('Provider', source.publisher),
          _DetailRow('Dataset', source.name),
          _DetailRow(
            'Downloaded (UTC)',
            downloadedAtUtc?.toUtc().toIso8601String() ?? 'Not available',
          ),
          _DetailRow('Source URL', source.dataUri.toString()),
          _DetailRow('Metadata', source.metadataUri.toString()),
          const _Notice(
            'Coverage and current applicability are not verified by this overlay. '
            'A download timestamp is not an official validity date. '
            'Check current official sources before flying.',
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('All source attributes (${zone.attributes.length})'),
            children: [
              for (final entry in zone.attributes.entries)
                _DetailRow(
                  entry.key.isEmpty ? '(empty field name)' : entry.key,
                  entry.value.isEmpty ? '(empty)' : entry.value,
                ),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> _fields(Map<String, String> labels) => [
    for (final entry in labels.entries)
      _DetailRow(entry.value, zone.value(entry.key) ?? 'Not provided'),
  ];

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        SelectableText(value),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
