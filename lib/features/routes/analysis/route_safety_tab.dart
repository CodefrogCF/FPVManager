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
          context.localized(
            "Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.",
            (l10n) => l10n.commonPlanningChecksOnlyNo5a915c9e,
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
                    ? context.localized(
                        "Checking…",
                        (l10n) => l10n.routesChecking820d6004,
                      )
                    : context.localized(
                        "Check current route",
                        (l10n) => l10n.routesCheckCurrentRoute87fb7469,
                      ),
              ),
            ),
            TextButton(
              onPressed: () => showRouteConstraints(context, c.editor),
              child: Text(
                context.localized(
                  "Configure constraints",
                  (l10n) => l10n.routesConfigureConstraintsf3a3a710,
                ),
              ),
            ),
            if (s.loading)
              TextButton(
                onPressed: s.cancel,
                child: Text(
                  context.localized(
                    "Cancel checks",
                    (l10n) => l10n.routesCancelChecks480fd8da,
                  ),
                ),
              ),
          ],
        ),
        if (s.loading) const LinearProgressIndicator(),
        if (r != null) ...[
          Text(
            context.localized(
              "Height constraints",
              (l10n) => l10n.routesHeightConstraintseeba8204,
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.localizedWithArgs(
              "Configured legal ceiling: {0} m AGL · operational ceiling: {1} m AGL",
              [
                settings.legalCeilingAgl ?? "unverified",
                settings.operationalCeilingAgl ?? "not set",
              ],
              (l10n, value) => l10n.routesConfiguredLegalCeilingMe4d4520c(
                value(0),
                value(1),
              ),
            ),
          ),
          if (r.findings.isEmpty)
            Text(
              context.localized(
                "No configured limit exceedance detected in the evaluated inputs.",
                (l10n) => l10n.routesNoConfiguredLimitExceedance5e7f8c0c,
              ),
            ),
          if (r.unknownHeightSamples > 0)
            Text(
              context.localizedWithArgs(
                "{0} samples have unknown clearance; intermediate height limits remain unassessed.",
                [r.unknownHeightSamples],
                (l10n, value) =>
                    l10n.routesSamplesHaveUnknownClearance53029fc6(value(0)),
              ),
            ),
          for (final f in r.findings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber),
              title: Text(
                context.localizedWithArgs("Segment {0}", [
                  segments([f.segment]),
                ], (l10n, value) => l10n.routesSegment2e9d80c3(value(0))),
              ),
              subtitle: Text(f.message),
              onTap: () => c.editor.select(c.editor.points[f.segment].key),
            ),
          Text(
            context.localized(
              "Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, zone height limits, activation times and exemptions are not automatically verified.",
              (l10n) => l10n.commonTerrainChecksSampleAt803435c1,
            ),
          ),
        ],
        const Divider(),
        Text(
          context.localized(
            "UAS zone intersections",
            (l10n) => l10n.routesUasZoneIntersections5bc17c8d,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (s.airspaceError != null) Text(s.airspaceError!),
        if (a != null) ...[
          Text(
            context.localizedWithArgs(
              "{0} · {1} · retrieved {2}",
              [
                a.source.attribution,
                a.freshness.name,
                a.fetchedAtUtc.toIso8601String(),
              ],
              (l10n, value) =>
                  l10n.routesRetrieved06b37dcd(value(0), value(1), value(2)),
            ),
          ),
          for (final limitation in a.limitations) Text(limitation),
          if (a.intersections.isEmpty)
            Text(
              context.localized(
                "No horizontal match in the checked dataset. Unrestricted airspace is not established.",
                (l10n) => l10n.routesNoHorizontalMatchIne04da067,
              ),
            ),
          for (final hit in a.intersections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_outlined),
              title: Text(hit.zone.name),
              subtitle: Text(
                context.localizedWithArgs(
                  "{0}\nSegments {1}\n{2}",
                  [
                    hit.zone.restriction.category.label,
                    segments(hit.geometry.segmentIndices),
                    hit.zone.restriction.restrictionMeaning,
                  ],
                  (l10n, value) =>
                      l10n.routesSegments5ae8cd98(value(0), value(1), value(2)),
                ),
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
          context.localized(
            "Horizontal obstacle proximity",
            (l10n) => l10n.routesHorizontalObstacleProximityb3d4572a,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.localizedWithArgs(
            "Buffer {0} m · selected categories: {1}",
            [
              c.editor.globe.obstacles.bufferMeters,
              c.editor.globe.obstacles.categories.map((v) => v.name).join(", "),
            ],
            (l10n, value) => l10n.routesBufferMSelectedCategories6b55c391(
              value(0),
              value(1),
            ),
          ),
        ),
        if (s.obstacleError != null) Text(s.obstacleError!),
        if (p != null) ...[
          Text(
            context.localizedWithArgs(
              "BAZL / FOCA · {0} · published {1} · retrieved {2}",
              [
                s.obstacleStatus,
                s.snapshot?.sourceUpdated?.toIso8601String() ?? "unknown",
                s.snapshot?.fetchedAt.toIso8601String(),
              ],
              (l10n, value) => l10n.routesBazlFocaPublishedRetrievedede87b71(
                value(0),
                value(1),
                value(2),
              ),
            ),
          ),
          if (p.incomplete)
            Text(
              context.localized(
                "Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.",
                (l10n) => l10n.commonIncompleteCheckGeometryCandidate8ab13e83,
              ),
            ),
          Text(
            context.localizedWithArgs(
              "Published coverage is incomplete. {0} unsupported source records. Missing objects and cables may exist; category filters exclude other objects.",
              [s.snapshot?.skipped ?? 0],
              (l10n, value) =>
                  l10n.routesPublishedCoverageIsIncomplete8fda9cde(value(0)),
            ),
          ),
          if (p.hits.isEmpty)
            Text(
              context.localized(
                "No proximity detected in the evaluated data. This does not establish an obstacle-free route.",
                (l10n) => l10n.routesNoProximityDetectedIn75f77f3a,
              ),
            ),
          for (final hit in p.hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(hit.obstacle.name),
              subtitle: Text(
                context.localizedWithArgs(
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
                  (l10n, value) => l10n.routesSegmentMHorizontalSource0f6d6b0d(
                    value(0),
                    value(1),
                    value(2),
                    value(3),
                    value(4),
                  ),
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
            context.localized(
              "Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.",
              (l10n) => l10n.commonApproximateMetricDistancesUse2ad8d0c4,
            ),
          ),
        ],
        const Divider(),
        Text(
          context.localized(
            "3D Infrastructure Clearance (advisory)",
            (l10n) => l10n.routesDInfrastructureClearanceAdvisory02222668,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.localized(
              "Assess modeled bridges, supports and tunnel walls",
              (l10n) => l10n.commonAssessModeledBridgesSupports6afd1bbd,
            ),
          ),
          subtitle: Text(
            context.localized(
              "Opt-in. Only available local surface geometry is inspected; 3D Tiles alone do not prove clearance.",
              (l10n) => l10n.routesOptInOnlyAvailable291368ee,
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
              Text(
                context.localized(
                  "Approximate drone radius",
                  (l10n) => l10n.routesApproximateDroneRadiuse7919b03,
                ),
              ),
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
              context.localized(
                "Show 3D Infrastructure Clearance findings on map",
                (l10n) => l10n.routesShowDInfrastructureClearancedcae1002,
              ),
            ),
            value: s.infrastructureLayerVisible,
            onChanged: s.setInfrastructureLayerVisible,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(
              context.localized(
                "Import local bridge/support geometry (JSON)",
                (l10n) => l10n.routesImportLocalBridgeSupport8cc6480f,
              ),
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
                            context.localized(
                              "Local geometry loaded. Re-run Check current route. Source claims remain unverified.",
                              (l10n) =>
                                  l10n.routesLocalGeometryLoadedRe52972d93,
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.localizedWithArgs(
                              "Infrastructure import failed: {0}",
                              [e],
                              (l10n, value) =>
                                  l10n.routesInfrastructureImportFailed68671f9d(
                                    value(0),
                                  ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
          ),
          Text(
            context.localizedWithArgs(
              "Local bridge/support surfaces: {0}. Imported dimensions are not independently verified.",
              [c.editor.globe.infrastructureSurfaceCount],
              (l10n, value) =>
                  l10n.routesLocalBridgeSupportSurfacesc5994174(value(0)),
            ),
          ),
          if (s.infrastructureError != null) Text(s.infrastructureError!),
          if (s.infrastructure case final report?) ...[
            Text(
              context.localizedWithArgs(
                "Examined up to {0} model samples; {1} unknown-altitude probes.",
                [report.checkedSamples, report.unknownHeightSamples],
                (l10n, value) =>
                    l10n.routesExaminedUpToModel89dfac48(value(0), value(1)),
              ),
            ),
            if (report.processingLimited)
              Text(
                context.localized(
                  "Processing limit reached. The assessment or result list is incomplete.",
                  (l10n) => l10n.routesProcessingLimitReachedThe59278caf,
                ),
              ),
            Text(report.message),
            if (report.findings.isEmpty)
              Text(
                context.localized(
                  "No conflict found in the available local models. Infrastructure clearance remains unassessed elsewhere.",
                  (l10n) => l10n.routesNoConflictFoundIn4baaf950,
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
                  context.localizedWithArgs(
                    "Segment {0} · simulated separation {1} m\n{2} · {3} · {4} / {5}\nModel geometry only; not real-world flight clearance.",
                    [
                      segments([hit.segment]),
                      hit.clearanceMeters.toStringAsFixed(2),
                      hit.kind,
                      hit.quality,
                      hit.source,
                      hit.sourceId,
                    ],
                    (l10n, value) =>
                        l10n.routesSegmentSimulatedSeparationM10cc26fd(
                          value(0),
                          value(1),
                          value(2),
                          value(3),
                          value(4),
                          value(5),
                        ),
                  ),
                ),
                onTap: hit.segment < c.editor.points.length
                    ? () => c.editor.select(c.editor.points[hit.segment].key)
                    : null,
              ),
          ] else
            Text(
              context.localized(
                "No current infrastructure assessment. Use Check current route.",
                (l10n) => l10n.routesNoCurrentInfrastructureAssessmentc3d9ef92,
              ),
            ),
        ],
        const Divider(),
        Text(
          context.localized(
            "Manual verification required",
            (l10n) => l10n.routesManualVerificationRequireda6416489,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(switch (settings.visibility) {
          RouteVisibilityMode.bvlos => context.localized(
            "BVLOS planned: verify the required operating category and authorisation with FOCA.",
            (l10n) => l10n.routesBvlosPlannedVerifyThe1d105130,
          ),
          RouteVisibilityMode.fpvWithObserver => context.localized(
            "FPV planned: verify observer requirements, direct visual contact and communication.",
            (l10n) => l10n.commonFpvPlannedVerifyObservera86fbfbe,
          ),
          RouteVisibilityMode.vlos => context.localized(
            "VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.",
            (l10n) => l10n.routesVlosPlannedVerifyActual5fbdce06,
          ),
          RouteVisibilityMode.unverified => context.localized(
            "Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.",
            (l10n) => l10n.routesVisibilityScenarioUnverifiedConfirmd7996cb0,
          ),
        }),
        Text(
          context.localized(
            "Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.",
            (l10n) => l10n.commonCheckCurrentOfficialZonesb6eb2aee,
          ),
        ),
        TextButton(
          onPressed: () async {
            await launchUrl(
              Uri.parse('https://www.bazl.admin.ch/de/flugregeln-drohnen'),
            );
          },
          child: Text(
            context.localized(
              "Official FOCA flight rules",
              (l10n) => l10n.routesOfficialFocaFlightRulesa3ad892e,
            ),
          ),
        ),
      ],
    );
  }
}
