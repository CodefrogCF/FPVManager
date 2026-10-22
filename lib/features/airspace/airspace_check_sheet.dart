import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/osint/osint_dataset.dart';
import '../globe/globe_controller.dart';
import 'uas_airspace_checker.dart';
import 'uas_zone_details_panel.dart';
import 'airspace_safety_panel.dart';

Future<void> showAirspaceCheck(
  BuildContext context, {
  required GlobeController controller,
  required String name,
  required List<Wgs84Coordinate> positions,
  bool route = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxWidth: 640,
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  builder: (_) => AirspaceCheckSheet(
    controller: controller,
    name: name,
    positions: List.unmodifiable(positions),
    route: route,
  ),
);

class AirspaceCheckSheet extends StatefulWidget {
  const AirspaceCheckSheet({
    super.key,
    required this.controller,
    required this.name,
    required this.positions,
    this.route = false,
  });
  final GlobeController controller;
  final String name;
  final List<Wgs84Coordinate> positions;
  final bool route;
  @override
  State<AirspaceCheckSheet> createState() => _AirspaceCheckSheetState();
}

class _AirspaceCheckSheetState extends State<AirspaceCheckSheet> {
  UasAirspaceCheck? _result;
  String? _error;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AirspaceCheckSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = oldWidget.positions, b = widget.positions;
    if (oldWidget.controller != widget.controller ||
        a.length != b.length ||
        [
          for (var i = 0; i < a.length && i < b.length; i++)
            a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude,
        ].any((changed) => changed)) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final operation = ++_operation;
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.controller.checkAirspace(
        widget.positions,
        forceRefresh: refresh,
      );
      if (mounted && operation == _operation) setState(() => _result = result);
    } catch (error) {
      if (mounted && operation == _operation) {
        setState(
          () => _error = error is ArgumentError
              ? error.message.toString()
              : 'Unable to check airspace. No current result is available.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Airspace intersections',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close airspace check',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(widget.name, style: Theme.of(context).textTheme.titleMedium),
          Text(
            widget.route
                ? 'Route snapshot · ${widget.positions.length} waypoints · all connecting segments'
                : 'Spot position · ${widget.positions.single.latitude.toStringAsFixed(6)}, '
                      '${widget.positions.single.longitude.toStringAsFixed(6)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Horizontal WGS84 geometry only, including boundary contact. '
              'Route segments are straight between waypoints. '
              'Height limits, activation times and legal applicability are not evaluated. '
              'This check is not flight authorization.',
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                showAirspaceSafetyPanel(context, widget.controller),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Flight safety & current official publications'),
          ),
          if (result == null && _error == null) ...[
            const LinearProgressIndicator(),
            const Text('Loading UAS data and checking geometry…'),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _load(refresh: true),
              child: const Text('Retry with fresh data'),
            ),
          ],
          if (result != null) ...[
            Text(
              result.intersections.isEmpty
                  ? 'No horizontal intersections found in the checked data.'
                  : 'Intersecting zones: ${result.intersections.length}',
            ),
            const Text(
              'Absence of a match does not establish unrestricted airspace. '
              'Source coverage is not independently verified.',
            ),
            const SizedBox(height: 12),
            Text('${result.source.name} · ${result.source.publisher}'),
            Text('Downloaded (UTC): ${result.fetchedAtUtc.toIso8601String()}'),
            Text('${result.checkedFeatureCount} polygon features checked'),
            if (result.freshness != OsintFreshness.fresh)
              const Text(
                'Dataset cache is stale or its clock is inconsistent.',
              ),
            for (final limitation in result.limitations)
              Text(
                limitation,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextButton.icon(
              onPressed: () => _load(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh source data'),
            ),
            for (final hit in result.intersections)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.zone.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(hit.zone.restriction.category.label),
                      Text(
                        hit.zone.value('restriction') ??
                            'Restriction not provided',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hit.zone.value('restrictionConditions')
                          case final text?)
                        Text(
                          text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text('Lower: ${hit.zone.heightLimit(upper: false)}'),
                      Text('Upper: ${hit.zone.heightLimit(upper: true)}'),
                      if (widget.route)
                        Text(
                          'Waypoints: ${_indices(hit.geometry.pointIndices)} · '
                          'Segments: ${_indices(hit.geometry.segmentIndices, segments: true)}',
                        ),
                      TextButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          constraints: BoxConstraints(
                            maxWidth: 640,
                            maxHeight: MediaQuery.sizeOf(context).height * .85,
                          ),
                          builder: (_) => UasZoneDetailsSheet(
                            zone: hit.zone,
                            source: result.source,
                            downloadedAtUtc: result.fetchedAtUtc,
                          ),
                        ),
                        child: const Text('Inspect restrictions'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _indices(Set<int> indices, {bool segments = false}) => indices.isEmpty
      ? 'none'
      : [
          for (final index in indices)
            segments ? '${index + 1}–${index + 2}' : '${index + 1}',
        ].join(', ');
}
