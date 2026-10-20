import 'package:flutter/material.dart';

import 'dart:async';

import 'core/database/fpv_database.dart';
import 'features/spots/data/spot_repository.dart';
import 'features/spots/spots_screen.dart';
import 'features/spots/spot_photo_viewer.dart';
import 'features/globe/globe_controller.dart';
import 'features/globe/globe_view.dart';
import 'features/globe/map_layers_sheet.dart';
import 'features/globe/terrain_information_dialog.dart';
import 'core/geo/geo_coordinate_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FPVManagerApp());
}

class FPVManagerApp extends StatelessWidget {
  const FPVManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPVManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101820),
      ),
      home: const FPVHomeScreen(),
    );
  }
}

class FPVHomeScreen extends StatefulWidget {
  const FPVHomeScreen({super.key, this.spotRepository});

  /// An injected repository remains owned by its caller.
  final SpotRepository? spotRepository;

  @override
  State<FPVHomeScreen> createState() => _FPVHomeScreenState();
}

class _FPVHomeScreenState extends State<FPVHomeScreen> {
  final GlobeController _globeController = GlobeController();
  FpvDatabase? _database;
  SpotRepository? _spotRepository;

  StreamSubscription<List<Spot>>? _spotsSubscription;
  Map<int, Spot> _spotsById = const {};

  Future<void> _runCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Map error: $error')));
    }
  }

  Future<void> _openMapLayers() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (context) => MapLayersSheet(controller: _globeController),
    );
  }

  Future<void> _openSpots() async {
    _startSpotSynchronization();

    final repository = _spotRepository!;

    final point = _globeController.selectedUasZone == null
        ? _globeController.selectedPoint
        : null;

    final spot = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (context) => SpotsScreen(
          repository: repository,
          initialLatitude: point?.latitude,
          initialLongitude: point?.longitude,
        ),
      ),
    );

    if (!mounted || spot == null) return;

    await _runCommand(
      () => _globeController.focusSpot(
        latitude: spot.latitude,
        longitude: spot.longitude,
        rangeMeters: 300,
      ),
    );
  }

  Future<void> _openCoordinatesDialog() async {
    final point = await showDialog<GlobePoint>(
      context: context,
      builder: (context) => const _CoordinatesDialog(),
    );

    if (point == null || !mounted) return;

    await _runCommand(
      () => _globeController.flyTo(
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: 12000,
      ),
    );
  }

  Future<void> _showTerrainElevation() async {
    final point = _globeController.selectedPoint;
    if (point == null) return;
    try {
      final result = await _globeController.queryTerrainElevation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted || !identical(point, _globeController.selectedPoint)) return;
      await showDialog<void>(
        context: context,
        builder: (context) => TerrainInformationDialog(terrain: result),
      );
    } catch (error) {
      if (!mounted || !identical(point, _globeController.selectedPoint)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terrain query failed: $error')));
    }
  }

  @override
  void dispose() {
    _globeController.removeListener(_onGlobeStateChanged);

    unawaited(_closeSpotResources(_spotsSubscription, _database));

    _globeController.dispose();
    super.dispose();
  }

  void _startSpotSynchronization() {
    if (_spotsSubscription != null) return;

    final repository = _spotRepository ??=
        widget.spotRepository ??
        SpotRepository(_database ??= FpvDatabase.open());

    _spotsSubscription = repository.watchSpots().listen(
      (spots) {
        if (!mounted) return;

        setState(() {
          _spotsById = {for (final spot in spots) spot.id: spot};
        });

        final markers = spots.map((spot) {
          return SpotMapMarker(
            id: spot.id,
            name: spot.name,
            latitude: spot.latitude,
            longitude: spot.longitude,
          );
        }).toList();

        unawaited(
          _globeController.setSpotMarkers(markers).catchError((
            Object error,
            StackTrace stack,
          ) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Spot marker sync failed: $error')),
            );
          }),
        );
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load stored spots: $error')),
        );
      },
    );
  }

  Future<void> _closeSpotResources(
    StreamSubscription<List<Spot>>? subscription,
    FpvDatabase? database,
  ) async {
    if (subscription != null) {
      await subscription.cancel();
    }

    if (database != null) {
      await database.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _globeController.addListener(_onGlobeStateChanged);
  }

  void _onGlobeStateChanged() {
    if (_globeController.isReady && _spotsSubscription == null) {
      _startSpotSynchronization();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FPVManager'),
        backgroundColor: const Color(0xFF101820),
        actions: [
          IconButton(
            tooltip: 'FPV Spots',
            onPressed: _openSpots,
            icon: const Icon(Icons.bookmark_outline),
          ),

          ListenableBuilder(
            listenable: _globeController,
            builder: (context, child) {
              final ready = _globeController.isReady;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Home',
                    onPressed: ready
                        ? () => _runCommand(_globeController.resetCamera)
                        : null,
                    icon: const Icon(Icons.home_outlined),
                  ),
                  IconButton(
                    tooltip: 'Go to coordinates',
                    onPressed: ready ? _openCoordinatesDialog : null,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  IconButton(
                    tooltip: 'Query terrain elevation',
                    onPressed:
                        ready &&
                            _globeController.selectedPoint != null &&
                            _globeController.selectedUasZone == null
                        ? _showTerrainElevation
                        : null,
                    icon: const Icon(Icons.terrain_outlined),
                  ),
                  IconButton(
                    tooltip: 'Map layers',
                    onPressed: ready ? _openMapLayers : null,
                    icon: const Icon(Icons.layers_outlined),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: GlobeView(controller: _globeController),
      bottomNavigationBar: ListenableBuilder(
        listenable: _globeController,
        builder: (context, child) {
          final spotId = _globeController.selectedSpotId;

          final selectedSpot = spotId == null ? null : _spotsById[spotId];

          if (selectedSpot != null) {
            return SafeArea(
              top: false,
              child: Card(
                margin: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.place,
                        color: Colors.cyanAccent,
                      ),
                      title: Text(selectedSpot.name),
                      subtitle: Text(
                        '${selectedSpot.latitude.toStringAsFixed(8)}, '
                        '${selectedSpot.longitude.toStringAsFixed(8)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Close spot details',
                        onPressed: _globeController.clearSelectedSpot,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => SpotPhotosDialog(
                                repository: _spotRepository!,
                                spotId: selectedSpot.id,
                                spotName: selectedSpot.name,
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Photos'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _runCommand(
                              () => _globeController.focusSpot(
                                latitude: selectedSpot.latitude,
                                longitude: selectedSpot.longitude,
                                rangeMeters: 300,
                              ),
                            ),
                            icon: const Icon(Icons.navigation),
                            label: const Text('Fly to Spot'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final selectedZone = _globeController.selectedUasZone;
          if (selectedZone != null) {
            return _UasZoneDetailsPanel(
              zone: selectedZone,
              onClose: _globeController.clearSelectedUasZone,
            );
          }
          final point = _globeController.selectedPoint;
          final error = _globeController.error;

          String status;

          if (error != null) {
            status = 'Map error: $error';
          } else if (!_globeController.isReady) {
            status = 'Loading globe...';
          } else if (_globeController.uasZonesError != null) {
            status = 'UAS zones: ${_globeController.uasZonesError}';
          } else if (_globeController.uasZonesLoading) {
            status = 'Loading Swiss UAS zones...';
          } else if (_globeController.uasZonesVisible) {
            status = 'Swiss UAS zones active | Source: FOCA';
          } else if (point != null) {
            status =
                '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)} | '
                '${point.altitude.toStringAsFixed(1)} m '
                '(${point.heightReference.label})';
          } else {
            status = '3D globe ready';
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                status,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog();

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final _formKey = GlobalKey<FormState>();

  final _latitude = TextEditingController(text: '46.7');
  final _longitude = TextEditingController(text: '8.4');

  double? _parse(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _validate(String? value, double minimum, double maximum) {
    final number = _parse(value ?? '');

    if (number == null ||
        !number.isFinite ||
        number < minimum ||
        number > maximum) {
      return 'Enter a value from $minimum to $maximum';
    }

    return null;
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to coordinates'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
              validator: (value) => _validate(value, -90, 90),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
              validator: (value) => _validate(value, -180, 180),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.pop(
              context,
              GlobePoint(
                latitude: _parse(_latitude.text)!,
                longitude: _parse(_longitude.text)!,
                altitude: 0,
              ),
            );
          },
          child: const Text('Go'),
        ),
      ],
    );
  }
}

class _UasZoneDetailsPanel extends StatelessWidget {
  const _UasZoneDetailsPanel({required this.zone, required this.onClose});

  final UasZoneDetails zone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final attributes = zone.attributes.entries.toList();

    return SafeArea(
      top: false,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.shield_outlined,
                color: Colors.orangeAccent,
              ),
              title: Text(
                zone.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('UAS Geographical Zone · FOCA / BAZL'),
              trailing: IconButton(
                tooltip: 'Close details',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ),

            const Divider(height: 1),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: attributes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No additional attributes available.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: attributes.length,
                      itemBuilder: (context, index) {
                        final attribute = attributes[index];

                        return ListTile(
                          dense: true,
                          title: Text(
                            attribute.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: SelectableText(attribute.value),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Source: Swiss Federal Office of Civil '
                'Aviation (FOCA). Verify current '
                'restrictions with official sources '
                'before flying.',
                style: TextStyle(fontSize: 11, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
