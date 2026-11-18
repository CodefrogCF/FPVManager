import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import 'route_layers_controller.dart';

class RouteLayersSection extends StatefulWidget {
  const RouteLayersSection({super.key, required this.controller});
  final RouteLayersController controller;
  @override
  State<RouteLayersSection> createState() => _RouteLayersSectionState();
}

class _RouteLayersSectionState extends State<RouteLayersSection> {
  late Stream<List<FlightPlanSummary>> _plans = widget.controller.repository
      .watchFlightPlanSummaries();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.controller.globe]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localized(
            "Flight routes",
            (l10n) => l10n.routesFlightRoutescf03df8f,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.localized(
            "Configured heights are shown in 3D. Points marked * use a 30 m AGL preview because their height is missing or uses an unsupported datum. Selected routes stay visible in ground view.",
            (l10n) => l10n.routesConfiguredHeightsAreShowna9eb24e8,
          ),
        ),
        if (!widget.controller.globe.terrainAvailable)
          Text(
            context.localized(
              "3D route preview is hidden until detailed terrain is available.",
              (l10n) => l10n.routesDRoutePreviewIs18af1855,
            ),
          ),
        if (widget.controller.error != null ||
            widget.controller.globe.routePreviewError != null) ...[
          Text(
            widget.controller.error ??
                widget.controller.globe.routePreviewError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: widget.controller.retrying
                ? null
                : widget.controller.retry,
            child: Text(
              context.localized(
                "Retry route preview",
                (l10n) => l10n.routesRetryRoutePreview25273ee7,
              ),
            ),
          ),
        ],
        StreamBuilder<List<FlightPlanSummary>>(
          stream: _plans,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.localized(
                      "Unable to load saved routes.",
                      (l10n) => l10n.routesUnableToLoadSavedda813904,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _plans = widget.controller.repository
                          .watchFlightPlanSummaries();
                    }),
                    child: Text(
                      context.localized(
                        "Retry route list",
                        (l10n) => l10n.routesRetryRouteListd4c0bbae,
                      ),
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.localized(
                    "No saved routes. Create one in Flight routes.",
                    (l10n) => l10n.routesNoSavedRoutesCreateca237d75,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final plan in snapshot.data!)
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(plan.name),
                          value: widget.controller.selectedIds.contains(
                            plan.id,
                          ),
                          onChanged: widget.controller.retrying
                              ? null
                              : (selected) => widget.controller.select(
                                  plan.id,
                                  selected!,
                                ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.localizedWithArgs(
                          "Show {0} on map",
                          [plan.name],
                          (l10n, value) =>
                              l10n.routesShowOnMapa1a4e0a9(value(0)),
                        ),
                        icon: const Icon(Icons.fit_screen),
                        onPressed:
                            widget.controller.hasGeometry(plan.id) &&
                                widget.controller.globe.terrainAvailable
                            ? () async {
                                try {
                                  await widget.controller.settled;
                                  await widget.controller.globe
                                      .frameVisibleRoute(plan.id);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.localized(
                                            "Unable to frame this route. Please retry.",
                                            (l10n) => l10n
                                                .routesUnableToFrameThisbad8013a,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
