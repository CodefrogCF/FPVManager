import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/fpv_database.dart' show Spot;
import '../../globe/globe_controller.dart';
import '../../spots/data/spot_location_service.dart';
import '../../spots/data/spot_repository.dart';
import '../road_routing.dart';
import '../mobility_preferences.dart';
import 'osm_poi_models.dart';
import 'osm_poi_saved_spots.dart';
import 'osm_poi_service.dart';

/// The network is only used after an explicit button press, never on tab open.
class OsmPoiSection extends StatefulWidget {
  const OsmPoiSection({
    super.key,
    required this.spots,
    required this.preferences,
    required this.globe,
    this.initialSpotId,
    this.initialMapPoint,
    this.service,
  });

  final SpotRepository spots;
  final MobilityPreferences preferences;
  final GlobeController globe;
  final int? initialSpotId;
  final MobilityPoint? initialMapPoint;
  final OsmPoiService? service;

  @override
  State<OsmPoiSection> createState() => _OsmPoiSectionState();
}

class _OsmPoiSectionState extends State<OsmPoiSection> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  late final Future<List<Spot>> _spots = widget.spots.getAllSpots();
  late final OsmPoiService _service = widget.service ?? OsmPoiService();
  late final OsmPoiSavedSpots _saved = OsmPoiSavedSpots(
    widget.preferences.database,
    widget.spots,
  );
  final Set<OsmPoiCategory> _categories = {
    OsmPoiCategory.drinkingWater,
    OsmPoiCategory.toilets,
    OsmPoiCategory.viewpoints,
  };
  int _radius = 500;
  bool _consent = false, _busy = false;
  String? _message;
  OsmPoiSnapshot? _result;
  int? _spotId;
  int _revision = 0;
  final Set<String> _saving = {};
  final Map<String, int> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _spotId = widget.initialMapPoint == null ? widget.initialSpotId : null;
    final selected = widget.initialMapPoint;
    if (selected != null) {
      _setCenter(selected.latitude, selected.longitude);
    } else {
      unawaited(_fromSavedSpot());
    }
  }

  Future<void> _fromSavedSpot() async {
    try {
      final spots = await _spots;
      if (!mounted || spots.isEmpty || _latitude.text.isNotEmpty) {
        return;
      }
      final spot =
          spots.where((s) => s.id == widget.initialSpotId).firstOrNull ??
          spots.first;
      setState(() {
        _spotId = spot.id;
        _setCenter(spot.latitude, spot.longitude);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Saved spots unavailable; enter coordinates.',
        );
      }
    }
  }

  void _setCenter(double latitude, double longitude) {
    _latitude.text = '$latitude';
    _longitude.text = '$longitude';
    _result = null;
  }

  OsmPoiSearch _searchSettings() {
    final lat = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null) {
      throw const FormatException('Enter valid search-center coordinates.');
    }
    return OsmPoiSearch(
      latitude: lat,
      longitude: lon,
      radiusMeters: _radius,
      categories: _categories,
    );
  }

  Future<void> _execute(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'POI operation failed. Verify your area and network.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _search({bool force = false}) => _execute(() async {
    if (!_consent) {
      throw const FormatException(
        'Allow sending the search-center coordinates to Overpass first.',
      );
    }
    final revision = ++_revision;
    final result = await _service.search(
      _searchSettings(),
      forceRefresh: force,
    );
    if (mounted && revision == _revision) {
      setState(() {
        _result = result;
        _savedIds.clear();
      });
    }
  });

  Future<void> _cache() => _execute(() async {
    final cached = await _service.readCached(_searchSettings());
    if (mounted) {
      setState(() {
        _result = cached;
        _savedIds.clear();
        _message = cached == null
            ? 'No local snapshot for the selected area and categories.'
            : null;
      });
    }
  });

  Future<void> _deviceLocation() => _execute(() async {
    final position = await const SpotLocationService().currentLocation();
    if (mounted) {
      setState(() {
        _spotId = null;
        _setCenter(position.position.latitude, position.position.longitude);
      });
    }
  });

  Future<void> _savePoi(OsmPoi poi) async {
    if (_saving.contains(poi.reference)) {
      return;
    }
    setState(() => _saving.add(poi.reference));
    try {
      final id = await _saved.save(poi, _result!.fetchedAtUtc);
      if (mounted) {
        setState(() => _savedIds[poi.reference] = id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save POI locally.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving.remove(poi.reference));
      }
    }
  }

  Future<void> _showMap() => _execute(() async {
    final result = _result;
    if (result == null) {
      return;
    }
    await widget.globe.showSituationalOverlay({
      'id': 'osm-poi',
      'visible': true,
      'features': [
        for (final poi in result.pois.take(300))
          {
            'id': poi.reference,
            'name': poi.name.length > 200
                ? poi.name.substring(0, 200)
                : poi.name,
            'detail': _mapDetail(poi, result.fetchedAtUtc),
            'geometry': {
              'type': 'Point',
              'coordinates': [poi.longitude, poi.latitude],
            },
          },
      ],
    });
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  });

  String _mapDetail(OsmPoi poi, DateTime retrievedAt) {
    final fields = poi.suppliedDetails.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    final text =
        '${poi.category.label}\n${poi.sourceUrl}\n$fields\nRetrieved: ${retrievedAt.toUtc().toIso8601String()}\n© OpenStreetMap contributors · ODbL';
    return text.length > 1200 ? text.substring(0, 1200) : text;
  }

  @override
  void dispose() {
    _revision++;
    _latitude.dispose();
    _longitude.dispose();
    if (widget.service == null) {
      unawaited(_service.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.localized(
            "Optional nearby points from OpenStreetMap via Overpass. Each request is initiated manually, limited to 2 km and six categories. Missing results do not prove that a facility does not exist. Never use these results as an authoritative source of drinking-water safety or access.",
            (l10n) => l10n.commonOptionalNearbyPointsFrom6d1c26fc,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Spot>>(
          future: _spots,
          builder: (context, state) => DropdownButtonFormField<int>(
            key: ValueKey('osm_poi_spot_$_spotId'),
            initialValue: state.data?.any((s) => s.id == _spotId) == true
                ? _spotId
                : null,
            decoration: InputDecoration(
              labelText: context.localized(
                "Search around saved spot (optional)",
                (l10n) => l10n.mobilitySearchAroundSavedSpot88def52e,
              ),
            ),
            isExpanded: true,
            items: [
              for (final spot in state.data ?? <Spot>[])
                DropdownMenuItem(
                  value: spot.id,
                  child: Text(spot.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !state.hasData
                ? null
                : (id) {
                    final spot = state.data!
                        .where((s) => s.id == id)
                        .firstOrNull;
                    if (spot != null) {
                      setState(() {
                        _spotId = id;
                        _setCenter(spot.latitude, spot.longitude);
                      });
                    }
                  },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final input in [
              (controller: _latitude, name: 'Latitude'),
              (controller: _longitude, name: 'Longitude'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    key: ValueKey('osm_poi_${input.name}'),
                    controller: input.controller,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: input.name),
                    onChanged: (_) => setState(() {
                      _spotId = null;
                      _result = null;
                    }),
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _deviceLocation,
            icon: const Icon(Icons.my_location),
            label: Text(
              context.localized(
                "Use device location",
                (l10n) => l10n.mobilityUseDeviceLocation37b5a739,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey('osm_poi_radius_$_radius'),
          initialValue: _radius,
          decoration: InputDecoration(
            labelText: context.localized(
              "Search radius (metres)",
              (l10n) => l10n.mobilitySearchRadiusMetres9f19e093,
            ),
          ),
          items: [250, 500, 1000, 2000]
              .map((r) => DropdownMenuItem(value: r, child: Text('$r m')))
              .toList(),
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _radius = v ?? 500;
                  _result = null;
                }),
        ),
        const SizedBox(height: 12),
        Text(
          context.localized(
            "Categories",
            (l10n) => l10n.mobilityCategories6ccb6007,
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final category in OsmPoiCategory.values)
              FilterChip(
                label: Text(category.label),
                selected: _categories.contains(category),
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          _categories.add(category);
                        } else if (_categories.length > 1) {
                          _categories.remove(category);
                        }
                        _result = null;
                      }),
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          title: Text(
            context.localized(
              "Send selected center, radius and categories to the public Overpass API.",
              (l10n) => l10n.commonSendSelectedCenterRadiusdd0ed3a0,
            ),
          ),
          subtitle: Text(
            context.localized(
              "No automatic polling. Queries are limited locally to 12/hour and at least 15 seconds apart. The provider may apply stricter limits.",
              (l10n) => l10n.mobilityNoAutomaticPollingQueries62b013f8,
            ),
          ),
          onChanged: _busy
              ? null
              : (v) => setState(() => _consent = v ?? false),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy || !_consent ? null : () => _search(),
              icon: const Icon(Icons.search),
              label: Text(
                context.localized(
                  "Find nearby places",
                  (l10n) => l10n.mobilityFindNearbyPlacesd0091995,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _busy || !_consent ? null : () => _search(force: true),
              child: Text(
                context.localized(
                  "Refresh from Overpass",
                  (l10n) => l10n.mobilityRefreshFromOverpass6925d82f,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _cache,
              child: Text(
                context.localized(
                  "Show saved search offline",
                  (l10n) => l10n.mobilityShowSavedSearchOffline9f9ba558,
                ),
              ),
            ),
          ],
        ),
        if (widget.globe.situationalVisible('osm-poi'))
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _execute(() async {
                      await widget.globe.showSituationalOverlay({
                        'id': 'osm-poi',
                        'visible': false,
                      });
                    }),
              child: Text(
                context.localized(
                  "Hide POIs on 3D map",
                  (l10n) => l10n.mobilityHidePoisOnD072cee45,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          context.localized(
            "Web availability depends on the public endpoint’s CORS policy; direct requests may fail in browsers. No proxy or intermediary is configured. This search does not download OSM map tiles.",
            (l10n) => l10n.mobilityWebAvailabilityDependsOna0047196,
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (snapshot != null) ...[
          const SizedBox(height: 16),
          Text(
            context.localizedWithArgs(
              "{0} OSM places · retrieved {1}{2}",
              [
                snapshot.pois.length,
                snapshot.fetchedAtUtc.toLocal().toIso8601String(),
                snapshot.fromCache ? ' · cached snapshot' : '',
              ],
              (l10n, value) => l10n.mobilityOsmPlacesRetrieved45a236fa(
                value(0),
                value(1),
                value(2),
              ),
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (snapshot.isOutdated(DateTime.now()))
            Text(
              context.localized(
                "OUTDATED: This offline snapshot may no longer reflect available facilities.",
                (l10n) => l10n.mobilityOutdatedThisOfflineSnapshot5eb25014,
              ),
            ),
          if (snapshot.fallbackToCache)
            Text(
              context.localized(
                "Provider unavailable; showing a dated cached snapshot instead.",
                (l10n) => l10n.mobilityProviderUnavailableShowingA4e8d9841,
              ),
            ),
          if (snapshot.truncated)
            Text(
              context.localized(
                "Results truncated to protect the device. Reduce your radius or category selection.",
                (l10n) => l10n.mobilityResultsTruncatedToProtect98dcb26a,
              ),
            ),
          Text(
            context.localized(
              "OpenStreetMap coverage is incomplete and attributes may be absent or outdated.",
              (l10n) => l10n.mobilityOpenstreetmapCoverageIsIncompletee9ae81d0,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy || snapshot.pois.isEmpty ? null : _showMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              context.localized(
                "Show POIs on 3D map",
                (l10n) => l10n.mobilityShowPoisOnD87e9f7a8,
              ),
            ),
          ),
          for (final poi in snapshot.pois.take(60))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      poi.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('${poi.category.label} · OSM ${poi.reference}'),
                    Text(
                      '${poi.latitude.toStringAsFixed(6)}, ${poi.longitude.toStringAsFixed(6)}',
                    ),
                    for (final field in poi.suppliedDetails.entries)
                      Text('${field.key}: ${field.value}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => launchUrl(poi.sourceUrl),
                          child: Text(
                            context.localized(
                              "View OSM source",
                              (l10n) => l10n.mobilityViewOsmSource395c9b71,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed:
                              _saving.contains(poi.reference) ||
                                  _savedIds.containsKey(poi.reference)
                              ? null
                              : () => _savePoi(poi),
                          child: Text(
                            _savedIds.containsKey(poi.reference)
                                ? context.localizedWithArgs(
                                    "Saved as spot #{0}",
                                    [_savedIds[poi.reference]],
                                    (l10n, value) => l10n
                                        .mobilitySavedAsSpota5bf3429(value(0)),
                                  )
                                : context.localized(
                                    "Save as personal spot",
                                    (l10n) =>
                                        l10n.mobilitySaveAsPersonalSpotc26312fd,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (snapshot.pois.length > 60)
            Text(
              context.localized(
                "Showing the first 60 POI detail cards; up to 300 points can be rendered on the map.",
                (l10n) => l10n.mobilityShowingTheFirstPoie98a81e6,
              ),
            ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          child: const Text(
            '© OpenStreetMap contributors · Open Database License (ODbL 1.0)',
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://wiki.openstreetmap.org/wiki/Overpass_API'),
          ),
          child: Text(
            context.localized(
              "Overpass API documentation and fair-use policy",
              (l10n) => l10n.mobilityOverpassApiDocumentationAnd4c33de59,
            ),
          ),
        ),
      ],
    );
  }
}
