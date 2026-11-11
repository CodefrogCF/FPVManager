import 'dart:convert';

import '../../../core/localization/app_localizations.dart';

import 'package:file_selector/file_selector.dart';
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
        Text(
          context.translate(
            "Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.",
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: s.loading ? null : () => s.calculate(c.result!),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                s.loading
                    ? context.translate("Checking…")
                    : context.translate("Check current route"),
              ),
            ),
            TextButton(
              onPressed: () => showRouteConstraints(context, c.editor),
              child: Text(context.translate("Configure constraints")),
            ),
            if (s.loading)
              TextButton(
                onPressed: s.cancel,
                child: Text(context.translate("Cancel checks")),
              ),
          ],
        ),
        if (s.loading) const LinearProgressIndicator(),
        if (r != null) ...[
          Text(
            context.translate("Height constraints"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.translate(
              "Configured legal ceiling: {0} m AGL · operational ceiling: {1} m AGL",
              [
                settings.legalCeilingAgl ?? "unverified",
                settings.operationalCeilingAgl ?? "not set",
              ],
            ),
          ),
          if (r.findings.isEmpty)
            Text(
              context.translate(
                "No configured limit exceedance detected in the evaluated inputs.",
              ),
            ),
          if (r.unknownHeightSamples > 0)
            Text(
              context.translate(
                "{0} samples have unknown clearance; intermediate height limits remain unassessed.",
                [r.unknownHeightSamples],
              ),
            ),
          for (final f in r.findings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber),
              title: Text(
                context.translate("Segment {0}", [
                  segments([f.segment]),
                ]),
              ),
              subtitle: Text(f.message),
              onTap: () => c.editor.select(c.editor.points[f.segment].key),
            ),
          Text(
            context.translate(
              "Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, zone height limits, activation times and exemptions are not automatically verified.",
            ),
          ),
        ],
        const Divider(),
        Text(
          context.translate("UAS zone intersections"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (s.airspaceError != null) Text(s.airspaceError!),
        if (a != null) ...[
          Text(
            context.translate("{0} · {1} · retrieved {2}", [
              a.source.attribution,
              a.freshness.name,
              a.fetchedAtUtc.toIso8601String(),
            ]),
          ),
          for (final limitation in a.limitations) Text(limitation),
          if (a.intersections.isEmpty)
            Text(
              context.translate(
                "No horizontal match in the checked dataset. Unrestricted airspace is not established.",
              ),
            ),
          for (final hit in a.intersections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_outlined),
              title: Text(hit.zone.name),
              subtitle: Text(
                context.translate("{0}\nSegments {1}\n{2}", [
                  hit.zone.restriction.category.label,
                  segments(hit.geometry.segmentIndices),
                  hit.zone.restriction.restrictionMeaning,
                ]),
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
          context.translate("Horizontal obstacle proximity"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.translate("Buffer {0} m · selected categories: {1}", [
            c.editor.globe.obstacles.bufferMeters,
            c.editor.globe.obstacles.categories.map((v) => v.name).join(", "),
          ]),
        ),
        if (s.obstacleError != null) Text(s.obstacleError!),
        if (p != null) ...[
          Text(
            context.translate(
              "BAZL / FOCA · {0} · published {1} · retrieved {2}",
              [
                s.obstacleStatus,
                s.snapshot?.sourceUpdated?.toIso8601String() ?? "unknown",
                s.snapshot?.fetchedAt.toIso8601String(),
              ],
            ),
          ),
          if (p.incomplete)
            Text(
              context.translate(
                "Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.",
              ),
            ),
          Text(
            context.translate(
              "Published coverage is incomplete. {0} unsupported source records. Missing objects and cables may exist; category filters exclude other objects.",
              [s.snapshot?.skipped ?? 0],
            ),
          ),
          if (p.hits.isEmpty)
            Text(
              context.translate(
                "No proximity detected in the evaluated data. This does not establish an obstacle-free route.",
              ),
            ),
          for (final hit in p.hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(hit.obstacle.name),
              subtitle: Text(
                context.translate(
                  "Segment {0} · {1} m horizontal\n{2}\nSource ID: {3}{4}",
                  [
                    segments([hit.segment]),
                    hit.horizontalMeters.toStringAsFixed(1),
                    hit.spatialMeters == null
                        ? "3D separation unknown (missing/incompatible heights)"
                        : "3D separation at closest horizontal approach: ${hit.spatialMeters!.toStringAsFixed(1)} m (source elevations)",
                    hit.obstacle.id,
                    hit.obstacle.approximate
                        ? " · straight/interpolated cable geometry is approximate"
                        : "",
                  ],
                ),
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
          Text(
            context.translate(
              "Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.",
            ),
          ),
        ],
        const Divider(),
        Text(
          context.translate("3D Infrastructure Clearance (advisory)"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.translate(
              "Assess modeled bridges, supports and tunnel walls",
            ),
          ),
          subtitle: Text(
            context.translate(
              "Opt-in. Only available local surface geometry is inspected; 3D Tiles alone do not prove clearance.",
            ),
          ),
          value: s.infrastructureEnabled,
          onChanged: s.loading ? null : s.setInfrastructureEnabled,
        ),
        if (s.infrastructureEnabled) ...[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.translate("Approximate drone radius")),
              DropdownButton<double>(
                value: s.droneRadiusMeters,
                items: const [0.15, 0.25, 0.5, 1.0, 2.0]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v m')))
                    .toList(),
                onChanged: s.loading
                    ? null
                    : (v) {
                        if (v != null) s.setDroneRadiusMeters(v);
                      },
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.translate(
                "Show 3D Infrastructure Clearance findings on map",
              ),
            ),
            value: s.infrastructureLayerVisible,
            onChanged: s.setInfrastructureLayerVisible,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(
              context.translate("Import local bridge/support geometry (JSON)"),
            ),
            onPressed: s.loading
                ? null
                : () async {
                    try {
                      final file = await openFile(
                        acceptedTypeGroups: [
                          const XTypeGroup(
                            label: 'Infrastructure geometry',
                            extensions: ['json'],
                          ),
                        ],
                      );
                      if (file == null) return;
                      if (await file.length() > 65536) {
                        throw const FormatException(
                          'Maximum geometry size: 64 KiB',
                        );
                      }
                      final value = jsonDecode(await file.readAsString());
                      if (value is! Map<String, dynamic>) {
                        throw const FormatException(
                          'Expected a geometry JSON object',
                        );
                      }
                      await c.editor.globe.importInfrastructureGeometry(value);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate(
                              "Local geometry loaded. Re-run Check current route. Source claims remain unverified.",
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate(
                              "Infrastructure import failed: {0}",
                              [e],
                            ),
                          ),
                        ),
                      );
                    }
                  },
          ),
          Text(
            context.translate(
              "Local bridge/support surfaces: {0}. Imported dimensions are not independently verified.",
              [c.editor.globe.infrastructureSurfaceCount],
            ),
          ),
          if (s.infrastructureError != null) Text(s.infrastructureError!),
          if (s.infrastructure case final report?) ...[
            Text(
              context.translate(
                "Examined up to {0} model samples; {1} unknown-altitude probes.",
                [report.checkedSamples, report.unknownHeightSamples],
              ),
            ),
            if (report.processingLimited)
              Text(
                context.translate(
                  "Processing limit reached; additional route sections were not evaluated.",
                ),
              ),
            Text(report.message),
            if (report.findings.isEmpty)
              Text(
                context.translate(
                  "No conflict found in the available local models. Infrastructure clearance remains unassessed elsewhere.",
                ),
              ),
            for (final hit in report.findings)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  hit.modelContact ? Icons.warning_amber : Icons.info_outline,
                ),
                title: Text(
                  '${hit.modelContact ? "Model contact" : "Model proximity"}: ${hit.name}',
                ),
                subtitle: Text(
                  context.translate(
                    "Segment {0} · simulated separation {1} m\n{2} · {3} · {4} / {5}\nModel geometry only; not real-world flight clearance.",
                    [
                      segments([hit.segment]),
                      hit.clearanceMeters.toStringAsFixed(2),
                      hit.kind,
                      hit.quality,
                      hit.source,
                      hit.sourceId,
                    ],
                  ),
                ),
                onTap: hit.segment < c.editor.points.length
                    ? () => c.editor.select(c.editor.points[hit.segment].key)
                    : null,
              ),
          ] else
            Text(
              context.translate(
                "No current infrastructure assessment. Use Check current route.",
              ),
            ),
        ],
        const Divider(),
        Text(
          context.translate("Manual verification required"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(switch (settings.visibility) {
          RouteVisibilityMode.bvlos => context.translate(
            "BVLOS planned: verify the required operating category and authorisation with FOCA.",
          ),
          RouteVisibilityMode.fpvWithObserver => context.translate(
            "FPV planned: verify observer requirements, direct visual contact and communication.",
          ),
          RouteVisibilityMode.vlos => context.translate(
            "VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.",
          ),
          RouteVisibilityMode.unverified => context.translate(
            "Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.",
          ),
        }),
        Text(
          context.translate(
            "Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.",
          ),
        ),
        TextButton(
          onPressed: () async {
            await launchUrl(
              Uri.parse('https://www.bazl.admin.ch/de/flugregeln-drohnen'),
            );
          },
          child: Text(context.translate("Official FOCA flight rules")),
        ),
      ],
    );
  }
}
