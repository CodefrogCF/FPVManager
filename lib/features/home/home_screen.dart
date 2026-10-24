import 'package:flutter/material.dart';

import 'dart:async';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import '../../core/database/repositories/battery_repository.dart';
import '../../core/database/repositories/radio_equipment_repository.dart';
import '../radio/radio_equipment_screen.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import '../routes/flight_routes_screen.dart';
import '../routes/route_layers_controller.dart';
import '../routes/route_layers_section.dart';
import '../globe/ground_view_button.dart';
import '../airspace/uas_data_quality_banner.dart';
import '../batteries/batteries_screen.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../drones/drones_screen.dart';
import '../spots/data/spot_repository.dart';
import '../spots/data/spot_query.dart';
import '../spots/spot_details_screen.dart';
import '../spots/spots_screen.dart';
import '../globe/globe_controller.dart';
import '../weather/weather_screen.dart';
import '../weather/weather_preferences.dart';
import '../globe/terrain_status_banner.dart';
import '../globe/globe_view.dart';
import '../globe/globe_input_scope.dart';
import '../mobility/mobility_screen.dart';
import '../mobility/mobility_preferences.dart';
import '../mobility/road_routing.dart';
import '../mobility/situational_layers_section.dart';
import '../globe/map_layers_sheet.dart';
import '../obstacles/obstacle_layers_section.dart';
import '../globe/terrain_information_dialog.dart';

import 'coordinates_dialog.dart';
import 'home_navigation_drawer.dart';
import 'map_action_menu.dart';
import 'map_selection_panel.dart';
import '../simulation/simulation_settings.dart';
import '../simulation/simulation_settings_sheet.dart';
import '../preflight/preflight_screen.dart';

class FPVHomeScreen extends StatefulWidget {
  const FPVHomeScreen({
    super.key,
    this.spotRepository,
    this.droneRepository,
    this.batteryRepository,
    this.radioEquipmentRepository,
    this.flightPlanRepository,
    this.preferencesRepository,
    this.globeController,
  });

  /// An injected repository remains owned by its caller.
  final SpotRepository? spotRepository;
  final DroneRepository? droneRepository;
  final BatteryRepository? batteryRepository;
  final RadioEquipmentRepository? radioEquipmentRepository;
  final FlightPlanRepository? flightPlanRepository;
  final UserPreferencesRepository? preferencesRepository;
  final GlobeController? globeController;

  @override
  State<FPVHomeScreen> createState() => _FPVHomeScreenState();
}

class _FPVHomeScreenState extends State<FPVHomeScreen> {
  bool _drawerOpen = false;
  Future<void> _openPreflight() async {
    await _leaveGroundView();
    if (!mounted) return;
    final database = _database ??= FpvDatabase.open();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PreflightScreen(database: database)),
    );
  }

  late final GlobeController _globeController =
      widget.globeController ?? GlobeController();
  FpvDatabase? _database;
  SpotRepository? _spotRepository;
  DroneRepository? _droneRepository;
  BatteryRepository? _batteryRepository;
  RadioEquipmentRepository? _radioEquipmentRepository;
  FlightPlanRepository? _flightPlanRepository;
  RouteLayersController? _routeLayers;
  bool _preferencesStarted = false;
  String? _lastGroundReason;
  String? _lastSimulationReason;
  SimulationSettings _simulationSettings = const SimulationSettings();
  int _lastSituationalRevision = 0;
  Future<void> _openMobility({int? initialSpotId}) async {
    await _leaveGroundView();
    if (!mounted) return;
    final database = _database ??= FpvDatabase.open();
    final point = _globeController.selectedPoint;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MobilityScreen(
          spots: _spotRepository ??=
              widget.spotRepository ?? SpotRepository(database),
          preferences: MobilityPreferences(database),
          globe: _globeController,
          initialSpotId: initialSpotId ?? _globeController.selectedSpotId,
          initialCenter: point == null
              ? null
              : MobilityPoint(point.latitude, point.longitude),
        ),
      ),
    );
  }

  Future<void> _openSimulation() async {
    final spot = _spotsById[_globeController.selectedSpotId],
        point = _globeController.selectedPoint;
    final settings = await showSimulationSettings(
      context,
      repository: _droneRepository ??=
          widget.droneRepository ??
          DroneRepository(_database ??= FpvDatabase.open()),
      initial: _simulationSettings.withCameraTilt(
        _globeController.simulationCameraTiltDegrees ??
            _simulationSettings.cameraTiltDegrees,
      ),
      hasSelection: spot != null || point != null,
    );
    if (settings == null || !mounted) return;
    _simulationSettings = settings;
    await _runCommand(
      () => _globeController.enterSimulation(
        settings,
        latitude: spot?.latitude ?? point?.latitude,
        longitude: spot?.longitude ?? point?.longitude,
      ),
    );
  }

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

  Future<void> _openMapLayers({MapLayerTab initialTab = MapLayerTab.map}) {
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
        initialTab: initialTab,
        controller: _globeController,
        routeControls: RouteLayersSection(controller: routes),
        situationalControls: SituationalLayersSection(
          globe: _globeController,
          onOpen: () {
            Navigator.pop(context);
            unawaited(_openMobility());
          },
        ),
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
          onRoadRoute: (id) => _openMobility(initialSpotId: id),
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

  Future<void> _openWeather() async {
    await _leaveGroundView();
    if (!mounted) return;
    final database = _database ??= FpvDatabase.open();
    final spotRepository = _spotRepository ??=
        widget.spotRepository ?? SpotRepository(database);
    final droneRepository = _droneRepository ??=
        widget.droneRepository ?? DroneRepository(database);
    final point = _globeController.selectedPoint;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WeatherScreen(
          spots: spotRepository,
          drones: droneRepository,
          globe: _globeController,
          preferences: WeatherPreferencesRepository(database),
          initialLatitude: point?.latitude,
          initialLongitude: point?.longitude,
        ),
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
      builder: (context) => const CoordinatesDialog(),
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
        _globeController.groundViewPending ||
        _globeController.simulationActive ||
        _globeController.simulationPending) {
      await _runCommand(_globeController.exitNavigation);
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
        builder: (context) => FlightRoutesScreen(
          repository: repository,
          obstacleProvider: _globeController.obstacles.provider,
          uasProvider: _globeController.uasProvider,
          preferencesRepository:
              widget.preferencesRepository ??
              UserPreferencesRepository(_database ??= FpvDatabase.open()),
        ),
      ),
    );
    if (mounted) await _globeController.retryLoadingPreferences();
  }

  Future<void> _openSpotDetails(int id) async {
    final spot = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (context) => SpotDetailsScreen(
          repository: _spotRepository!,
          spotId: id,
          onRoadRoute: () => _openMobility(initialSpotId: id),
        ),
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

    if (widget.globeController == null) _globeController.dispose();
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
    final selection = _globeController.situationalSelection;
    if (selection != null &&
        _lastSituationalRevision !=
            _globeController.situationalSelectionRevision) {
      _lastSituationalRevision = _globeController.situationalSelectionRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(selection.name),
              content: SingleChildScrollView(
                child: SelectableText(selection.detail),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      });
    }
    final reason = _globeController.groundViewMessage;
    if (reason != null && reason != _lastGroundReason && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
    }
    _lastGroundReason = reason;
    final simulationReason = _globeController.simulationMessage;
    if (simulationReason != null &&
        simulationReason != _lastSimulationReason &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(simulationReason)));
    }
    _lastSimulationReason = simulationReason;
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
      onDrawerChanged: (open) => setState(() => _drawerOpen = open),
      drawer: HomeNavigationDrawer(
        onSpots: _openSpots,
        onRoutes: _openRoutes,
        onMobility: _openMobility,
        onPreflight: _openPreflight,
        onWeather: _openWeather,
        onDrones: _openDrones,
        onBatteries: _openBatteries,
        onRadio: _openRadioEquipment,
      ),
      appBar: AppBar(
        title: const Text('FPVManager'),
        actions: [
          MapActionMenu(
            controller: _globeController,
            groundButtonBuilder: _groundButton,
            onHome: () => _runCommand(_globeController.resetCamera),
            onCoordinates: _openCoordinatesDialog,
            onTerrain: _showTerrainElevation,
            onLayers: _openMapLayers,
            onWeather: _openWeather,
            onSimulation: _openSimulation,
          ),
        ],
      ),
      body: GlobeInputScope(
        enabled: !_drawerOpen,
        child: Column(
          children: [
            TerrainStatusBanner(controller: _globeController),
            ObstacleStatusBanner(
              controller: _globeController.obstacles,
              onDetails: () =>
                  _openMapLayers(initialTab: MapLayerTab.obstacles),
            ),
            UasDataQualityBanner(
              controller: _globeController,
              onDetails: () => _openMapLayers(initialTab: MapLayerTab.airspace),
            ),
            Expanded(child: GlobeView(controller: _globeController)),
          ],
        ),
      ),
      bottomNavigationBar: MapSelectionPanel(
        controller: _globeController,
        spotsById: _spotsById,
        spotRepository: _spotRepository,
        onSpotDetails: _openSpotDetails,
        onCommand: _runCommand,
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
