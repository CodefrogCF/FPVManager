import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/route_constraints.dart';
import '../../airspace/uas_zone_details_panel.dart';
import '../../obstacles/obstacle_details_panel.dart';
import 'route_analysis_controller.dart';
import 'route_constraints_sheet.dart';

class RouteSafetyTab extends StatelessWidget {
  const RouteSafetyTab({super.key, required this.controller});
  final RouteAnalysisController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller,
        s = c.safety,
        r = s.rules,
        a = s.airspace,
        p = s.proximity,
        settings = c.editor.planning.constraints;
    String segments(Iterable<int> values) =>
        values.map((i) => '${i + 1} → ${i + 2}').join(', ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.',
        ),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: s.loading ? null : () => s.calculate(c.result!),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(s.loading ? 'Checking…' : 'Check current route'),
            ),
            TextButton(
              onPressed: () => showRouteConstraints(context, c.editor),
              child: const Text('Configure constraints'),
            ),
            if (s.loading)
              TextButton(
                onPressed: s.cancel,
                child: const Text('Cancel checks'),
              ),
          ],
        ),
        if (s.loading) const LinearProgressIndicator(),
        if (r != null) ...[
          Text(
            'Height constraints',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Configured legal ceiling: ${settings.legalCeilingAgl ?? "unverified"} m AGL · '
            'operational ceiling: ${settings.operationalCeilingAgl ?? "not set"} m AGL',
          ),
          if (r.findings.isEmpty)
            const Text(
              'No configured limit exceedance detected in the evaluated inputs.',
            ),
          if (r.unknownHeightSamples > 0)
            Text(
              '${r.unknownHeightSamples} samples have unknown clearance; intermediate height limits remain unassessed.',
            ),
          for (final f in r.findings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber),
              title: Text('Segment ${segments([f.segment])}'),
              subtitle: Text(f.message),
              onTap: () => c.editor.select(c.editor.points[f.segment].key),
            ),
          const Text(
            'Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, '
            'zone height limits, activation times and exemptions are not automatically verified.',
          ),
        ],
        const Divider(),
        Text(
          'UAS zone intersections',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (s.airspaceError != null) Text(s.airspaceError!),
        if (a != null) ...[
          Text(
            '${a.source.attribution} · ${a.freshness.name} · retrieved ${a.fetchedAtUtc.toIso8601String()}',
          ),
          for (final limitation in a.limitations) Text(limitation),
          if (a.intersections.isEmpty)
            const Text(
              'No horizontal match in the checked dataset. Unrestricted airspace is not established.',
            ),
          for (final hit in a.intersections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_outlined),
              title: Text(hit.zone.name),
              subtitle: Text(
                '${hit.zone.restriction.category.label}\nSegments ${segments(hit.geometry.segmentIndices)}\n'
                '${hit.zone.restriction.restrictionMeaning}',
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => UasZoneDetailsPanel(
                  zone: hit.zone,
                  source: a.source,
                  downloadedAtUtc: a.fetchedAtUtc,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
        ],
        const Divider(),
        Text(
          'Horizontal obstacle proximity',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Buffer ${c.editor.globe.obstacles.bufferMeters} m · selected categories: '
          '${c.editor.globe.obstacles.categories.map((v) => v.name).join(", ")}',
        ),
        if (s.obstacleError != null) Text(s.obstacleError!),
        if (p != null) ...[
          Text(
            'BAZL / FOCA · ${s.obstacleStatus} · published ${s.snapshot?.sourceUpdated?.toIso8601String() ?? "unknown"} · '
            'retrieved ${s.snapshot?.fetchedAt.toIso8601String()}',
          ),
          if (p.incomplete)
            const Text(
              'Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.',
            ),
          Text(
            'Published coverage is incomplete. ${s.snapshot?.skipped ?? 0} unsupported source records. '
            'Missing objects and cables may exist; category filters exclude other objects.',
          ),
          if (p.hits.isEmpty)
            const Text(
              'No proximity detected in the evaluated data. This does not establish an obstacle-free route.',
            ),
          for (final hit in p.hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(hit.obstacle.name),
              subtitle: Text(
                'Segment ${segments([hit.segment])} · ${hit.horizontalMeters.toStringAsFixed(1)} m horizontal\n'
                '${hit.spatialMeters == null ? "3D separation unknown (missing/incompatible heights)" : "3D separation at closest horizontal approach: ${hit.spatialMeters!.toStringAsFixed(1)} m (source elevations)"}\n'
                'Source ID: ${hit.obstacle.id}${hit.obstacle.approximate ? " · straight/interpolated cable geometry is approximate" : ""}',
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ObstacleDetailsPanel(
                  feature: hit.obstacle,
                  snapshot: s.snapshot,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
          const Text(
            'Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations '
            'converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.',
          ),
        ],
        const Divider(),
        Text(
          'Manual verification required',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(switch (settings.visibility) {
          RouteVisibilityMode.bvlos => 'BVLOS planned: verify the required operating category and authorisation with FOCA.',
          RouteVisibilityMode.fpvWithObserver => 'FPV planned: verify observer requirements, direct visual contact and communication.',
          RouteVisibilityMode.vlos => 'VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.',
          RouteVisibilityMode.unverified => 'Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.',
        }),
        const Text(
          'Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, '
          'pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.',
        ),
        TextButton(
          onPressed: () async {
            await launchUrl(
              Uri.parse('https://www.bazl.admin.ch/de/flugregeln-drohnen'),
            );
          },
          child: const Text('Official FOCA flight rules'),
        ),
      ],
    );
  }
}
