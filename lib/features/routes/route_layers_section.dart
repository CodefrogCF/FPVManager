import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'route_layers_controller.dart';

class RouteLayersSection extends StatefulWidget {
  const RouteLayersSection({super.key, required this.controller});
  final RouteLayersController controller;
  @override
  State<RouteLayersSection> createState() => _RouteLayersSectionState();
}

class _RouteLayersSectionState extends State<RouteLayersSection> {
  late Stream<List<FlightPlan>> _plans = widget.controller.repository
      .watchFlightPlans();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.controller.globe]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Flight routes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          '3D preview · 30 m AGL at waypoints. Selected routes stay visible in ground view for this map session.',
        ),
        if (!widget.controller.globe.terrainAvailable)
          const Text(
            '3D route preview is hidden until detailed terrain is available.',
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
            child: const Text('Retry route preview'),
          ),
        ],
        StreamBuilder<List<FlightPlan>>(
          stream: _plans,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unable to load saved routes.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _plans = widget.controller.repository.watchFlightPlans();
                    }),
                    child: const Text('Retry route list'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No saved routes. Create one in Flight routes.'),
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
                        tooltip: 'Show ${plan.name} on map',
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
                                      const SnackBar(
                                        content: Text(
                                          'Unable to frame this route. Please retry.',
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
