import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../mobility/destination_search.dart';
import '../spots/data/spot_query.dart';
import '../spots/data/spot_repository.dart';

class RouteStartLocation {
  const RouteStartLocation(this.position, {this.spotId});
  final Wgs84Coordinate position;
  final int? spotId;
}

Future<RouteStartLocation?> showRouteStartLocation(
  BuildContext context, {
  required bool search,
  SpotRepository? spots,
  DestinationSearch? placeSearch,
  String? title,
  String? hint,
}) => showModalBottomSheet<RouteStartLocation>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .8,
      child: Column(
        children: [
          ListTile(
            title: Text(
              title ?? (search ? 'Find a start area' : 'Start at a saved spot'),
            ),
            trailing: IconButton(
              tooltip: context.localized(
                "Close",
                (l10n) => l10n.commonClosebbfa773e,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: search
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.localized(
                            "Move the map to a place, then tap the map to set your first waypoint.",
                            (l10n) => l10n.commonMoveTheMapTob0c48a5b,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RoadDestinationSearch(
                          search: placeSearch,
                          onSelected: (place) => Navigator.pop(
                            context,
                            RouteStartLocation(
                              Wgs84Coordinate(
                                latitude: place.point.latitude,
                                longitude: place.point.longitude,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _SavedStarts(repository: spots!, hint: hint),
          ),
        ],
      ),
    ),
  ),
);

class _SavedStarts extends StatefulWidget {
  const _SavedStarts({required this.repository, this.hint});
  final SpotRepository repository;
  final String? hint;
  @override
  State<_SavedStarts> createState() => _SavedStartsState();
}

class _SavedStartsState extends State<_SavedStarts> {
  late Stream<List<SpotMapEntry>> _spots = widget.repository.watchMapSpots();
  String _filter = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          maxLength: 120,
          decoration: InputDecoration(
            labelText: context.localized(
              "Filter saved spots",
              (l10n) => l10n.routesFilterSavedSpotsf0054cfd,
            ),
            counterText: '',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _filter = value.trim().toLowerCase()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.hint ??
              context.localized(
                "Choose a spot to add the first waypoint at its saved coordinates.",
                (l10n) => l10n.routesChooseASpotToc0d9ecad,
              ),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<SpotMapEntry>>(
          stream: _spots,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(
                    () => _spots = widget.repository.watchMapSpots(),
                  ),
                  child: Text(
                    context.localized(
                      "Unable to load saved spots. Retry",
                      (l10n) => l10n.routesUnableToLoadSaved7cf6f705,
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final matches = snapshot.data!
                .where((s) => s.name.toLowerCase().contains(_filter))
                .toList();
            if (matches.isEmpty) {
              return Center(
                child: Text(
                  snapshot.data!.isEmpty
                      ? context.localized(
                          "No saved spots yet. Use the place search or tap the map.",
                          (l10n) => l10n.routesNoSavedSpotsYet044a3542,
                        )
                      : context.localized(
                          "No matching saved spots.",
                          (l10n) => l10n.routesNoMatchingSavedSpots783f2c6f,
                        ),
                ),
              );
            }
            return ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final spot = matches[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(spot.name),
                  subtitle: Text(
                    '${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}',
                  ),
                  onTap: () => Navigator.pop(
                    context,
                    RouteStartLocation(
                      Wgs84Coordinate(
                        latitude: spot.latitude,
                        longitude: spot.longitude,
                      ),
                      spotId: spot.id,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}
