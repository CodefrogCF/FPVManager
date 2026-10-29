import 'package:flutter/material.dart';

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
              tooltip: 'Close',
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
                        const Text(
                          'Move the map to a place, then tap the map to set your first waypoint.',
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
          decoration: const InputDecoration(
            labelText: 'Filter saved spots',
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
          widget.hint ?? 'Choose a spot to add the first waypoint at its saved coordinates.',
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
                  child: const Text('Unable to load saved spots. Retry'),
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
                      ? 'No saved spots yet. Use the place search or tap the map.'
                      : 'No matching saved spots.',
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
