import 'package:flutter/material.dart';

import 'dart:async';

import 'core/database/fpv_database.dart';
import 'core/database/repositories/drone_repository.dart';
import 'core/database/repositories/battery_repository.dart';
import 'core/database/repositories/radio_equipment_repository.dart';
import 'features/radio/radio_equipment_screen.dart';
import 'core/database/repositories/flight_plan_repository.dart';
import 'features/routes/flight_routes_screen.dart';
import 'features/routes/route_layers_controller.dart';
import 'features/routes/route_layers_section.dart';
import 'features/globe/ground_view_button.dart';
import 'features/airspace/uas_zone_details_panel.dart';
import 'features/airspace/uas_data_quality_banner.dart';
import 'features/batteries/batteries_screen.dart';
import 'core/database/repositories/user_preferences_repository.dart';
import 'features/drones/drones_screen.dart';
import 'features/spots/data/spot_repository.dart';
import 'features/spots/data/spot_query.dart';
import 'features/spots/spot_details_screen.dart';
import 'features/spots/spots_screen.dart';
import 'features/spots/spot_photo_viewer.dart';
import 'features/globe/globe_controller.dart';
import 'features/globe/terrain_status_banner.dart';
import 'features/globe/globe_view.dart';
import 'features/globe/map_layers_sheet.dart';
import 'features/globe/terrain_information_dialog.dart';

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
  const FPVHomeScreen({
    super.key,
    this.spotRepository,
    this.droneRepository,
    this.batteryRepository,
    this.radioEquipmentRepository,
    this.flightPlanRepository,
    this.preferencesRepository,
  });

  /// An injected repository remains owned by its caller.
  final SpotRepository? spotRepository;
  final DroneRepository? droneRepository;
  final BatteryRepository? batteryRepository;
  final RadioEquipmentRepository? radioEquipmentRepository;
  final FlightPlanRepository? flightPlanRepository;
  final UserPreferencesRepository? preferencesRepository;

  @override
  State<FPVHomeScreen> createState() => _FPVHomeScreenState();
}

enum _MapAction { home, coordinates, terrain, layers }

class _FPVHomeScreenState extends State<FPVHomeScreen> {
  final GlobeController _globeController = GlobeController();
  FpvDatabase? _database;
  SpotRepository? _spotRepository;
  DroneRepository? _droneRepository;
  BatteryRepository? _batteryRepository;
  RadioEquipmentRepository? _radioEquipmentRepository;
  FlightPlanRepository? _flightPlanRepository;
  RouteLayersController? _routeLayers;
  bool _preferencesStarted = false;
  String? _lastGroundReason;

  StreamSubscription<List<SpotMapEntry>>? _spotsSubscription;
  Map<int, SpotMapEntry> _spotsById = const {};

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
    final routes = _routeLayers ??= RouteLayersController(
      repository: _flightPlanRepository ??=
          widget.flightPlanRepository ??
          FlightPlanRepository(_database ??= FpvDatabase.open()),
      globe: _globeController,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (context) => MapLayersSheet(
        controller: _globeController,
        routeControls: RouteLayersSection(controller: routes),
      ),
    );
  }

  Future<void> _openSpots() async {
    await _leaveGroundView();
    if (!mounted) return;
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

  Future<void> _openDrones() async {
    await _leaveGroundView();
    if (!mounted) return;
    final repository = _droneRepository ??=
        widget.droneRepository ??
        DroneRepository(_database ??= FpvDatabase.open());
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => DronesScreen(repository: repository),
      ),
    );
  }

  Future<void> _openBatteries() async {
    await _leaveGroundView();
    if (!mounted) return;
    final repository = _batteryRepository ??=
        widget.batteryRepository ??
        BatteryRepository(_database ??= FpvDatabase.open());
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BatteriesScreen(repository: repository),
      ),
    );
  }

  Future<void> _openRadioEquipment() async {
    await _leaveGroundView();
    if (!mounted) return;
    final repository = _radioEquipmentRepository ??=
        widget.radioEquipmentRepository ??
        RadioEquipmentRepository(_database ??= FpvDatabase.open());
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => RadioEquipmentScreen(repository: repository),
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

  Future<void> _leaveGroundView() async {
    if (_globeController.groundViewActive ||
        _globeController.groundViewPending) {
      await _runCommand(_globeController.exitGroundView);
    }
  }

  Future<void> _openRoutes() async {
    await _leaveGroundView();
    if (!mounted) return;
    final repository = _flightPlanRepository ??=
        widget.flightPlanRepository ??
        FlightPlanRepository(_database ??= FpvDatabase.open());
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => FlightRoutesScreen(repository: repository),
      ),
    );
  }

  Future<void> _openSpotDetails(int id) async {
    final spot = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (context) =>
            SpotDetailsScreen(repository: _spotRepository!, spotId: id),
      ),
    );
    if (spot == null || !mounted) return;
    await _runCommand(
      () => _globeController.focusSpot(
        latitude: spot.latitude,
        longitude: spot.longitude,
        rangeMeters: 300,
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

    _routeLayers?.dispose();
    unawaited(_closeSpotResources(_spotsSubscription, _database));

    _globeController.dispose();
    super.dispose();
  }

  void _startSpotSynchronization() {
    if (_spotsSubscription != null) return;

    final repository = _spotRepository ??=
        widget.spotRepository ??
        SpotRepository(_database ??= FpvDatabase.open());

    _spotsSubscription = repository.watchMapSpots().listen(
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
    StreamSubscription<List<SpotMapEntry>>? subscription,
    FpvDatabase? database,
  ) async {
    await _routeLayers?.settled;
    if (subscription != null) {
      await subscription.cancel();
    }

    if (database != null) {
      await _globeController.preferencesSettled;
      await database.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _globeController.addListener(_onGlobeStateChanged);
  }

  void _onGlobeStateChanged() {
    final reason = _globeController.groundViewMessage;
    if (reason != null && reason != _lastGroundReason && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
    }
    _lastGroundReason = reason;
    if (_globeController.isReady && !_preferencesStarted) {
      _preferencesStarted = true;
      unawaited(
        _globeController.initializePreferences(
          widget.preferencesRepository ??
              UserPreferencesRepository(_database ??= FpvDatabase.open()),
        ),
      );
    }
    if (_globeController.isReady && _spotsSubscription == null) {
      _startSpotSynchronization();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const ListTile(
                title: Text('FPVManager'),
                subtitle: Text('Places & equipment'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('FPV Spots'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openSpots());
                },
              ),
              ListTile(
                leading: const Icon(Icons.flight_outlined),
                title: const Text('Drone profiles'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openDrones());
                },
              ),
              ListTile(
                leading: const Icon(Icons.battery_full_outlined),
                title: const Text('Battery inventory'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openBatteries());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_input_antenna),
                title: const Text('Radio & video equipment'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openRadioEquipment());
                },
              ),
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Flight routes'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openRoutes());
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('FPVManager'),
        backgroundColor: const Color(0xFF101820),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 720)
            IconButton(
              tooltip: 'FPV Spots',
              onPressed: _openSpots,
              icon: const Icon(Icons.bookmark_outline),
            ),

          ListenableBuilder(
            listenable: _globeController,
            builder: (context, child) {
              final ready = _globeController.isReady;

              if (MediaQuery.sizeOf(context).width < 720) {
                final terrain =
                    ready &&
                    _globeController.terrainAvailable &&
                    _globeController.selectedPoint != null &&
                    _globeController.selectedUasZone == null;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _groundButton(),
                    PopupMenuButton<_MapAction>(
                      tooltip: 'Map actions',
                      onSelected: (action) {
                        switch (action) {
                          case _MapAction.home:
                            unawaited(
                              _runCommand(_globeController.resetCamera),
                            );
                          case _MapAction.coordinates:
                            unawaited(_openCoordinatesDialog());
                          case _MapAction.terrain:
                            unawaited(_showTerrainElevation());
                          case _MapAction.layers:
                            unawaited(_openMapLayers());
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _MapAction.home,
                          enabled: ready,
                          child: const Text('Home'),
                        ),
                        PopupMenuItem(
                          value: _MapAction.coordinates,
                          enabled: ready,
                          child: const Text('Go to coordinates'),
                        ),
                        PopupMenuItem(
                          value: _MapAction.terrain,
                          enabled: terrain,
                          child: const Text('Query terrain elevation'),
                        ),
                        PopupMenuItem(
                          value: _MapAction.layers,
                          enabled: ready,
                          child: const Text('Map layers'),
                        ),
                      ],
                    ),
                  ],
                );
              }

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
                            _globeController.terrainAvailable &&
                            _globeController.selectedPoint != null &&
                            _globeController.selectedUasZone == null
                        ? _showTerrainElevation
                        : null,
                    icon: const Icon(Icons.terrain_outlined),
                  ),
                  _groundButton(),
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
      body: Column(
        children: [
          TerrainStatusBanner(controller: _globeController),
          UasDataQualityBanner(
            controller: _globeController,
            onDetails: _openMapLayers,
          ),
          Expanded(child: GlobeView(controller: _globeController)),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _globeController,
        builder: (context, child) {
          if (_globeController.groundViewActive ||
              _globeController.groundViewPending) {
            return const SizedBox.shrink();
          }
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
                            onPressed: () => _openSpotDetails(selectedSpot.id),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Details'),
                          ),
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
            return UasZoneDetailsPanel(
              zone: selectedZone,
              source: _globeController.uasSource,
              downloadedAtUtc:
                  _globeController.uasDisplayedDataset?.fetchedAtUtc,
              onClose: _globeController.clearSelectedUasZone,
            );
          }
          final point = _globeController.selectedPoint;
          if (point != null && _globeController.error == null) {
            return const SizedBox.shrink();
          }
          final error = _globeController.error;

          String status;

          if (error != null) {
            status = 'Map error: $error';
          } else if (!_globeController.isReady) {
            status = 'Loading globe...';
          } else if (!_globeController.terrainAvailable) {
            status = 'Flat map — terrain heights unavailable';
          } else if (_globeController.uasZonesError != null) {
            status = 'UAS zones: ${_globeController.uasZonesError}';
          } else if (_globeController.uasZonesLoading) {
            status = 'Loading Swiss UAS zones...';
          } else if (_globeController.uasZonesVisible) {
            status = 'Swiss UAS zones active | Source: FOCA';
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

  Widget _groundButton() {
    final spot = _spotsById[_globeController.selectedSpotId];
    return GroundViewButton(
      controller: _globeController,
      onCommand: _runCommand,
      latitude: spot?.latitude,
      longitude: spot?.longitude,
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
