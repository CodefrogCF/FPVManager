import 'package:flutter/material.dart';

import 'dart:async';

import '../data_management/data_management_screen.dart';
import '../offline/offline_region.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import '../../core/database/repositories/battery_repository.dart';
import '../../core/database/repositories/radio_equipment_repository.dart';
import '../../core/osint/osint_provider.dart';
import '../radio/radio_equipment_screen.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import '../routes/flight_routes_screen.dart';
import '../routes/route_layers_controller.dart';
import '../routes/route_layers_section.dart';
import '../globe/ground_view_button.dart';
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
import '../weather/wind_settings_sheet.dart';
import '../globe/globe_view.dart';
import '../globe/globe_input_scope.dart';
import '../mobility/mobility_screen.dart';
import '../mobility/mobility_preferences.dart';
import '../mobility/road_routing.dart';
import '../mobility/destination_search.dart';
import '../mobility/situational_layers_section.dart';
import '../globe/map_layers_sheet.dart';
import '../globe/terrain_information_dialog.dart';

import 'coordinates_dialog.dart';
import 'home_navigation_drawer.dart';
import 'map_action_menu.dart';
import 'map_selection_panel.dart';
import 'home_map_workspace.dart';
import 'home_map_status.dart';
import '../globe/map_floating_surface.dart';
import '../simulation/simulation_settings.dart';
import '../simulation/simulation_settings_sheet.dart';
import '../simulation/flight_recording_sheet.dart';
import '../signal/live_radio_sheet.dart';
import '../routes/route_editor_screen.dart';
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
  bool _cachedMaps = false;
  int _mapCacheRevision = 0;
  OfflineRegion? _pendingOfflineRegion;
  bool _awaitOfflineRenderer = false;
  Future<void> _openData() async {
    await _leaveGroundView();
    if (!mounted) return;
    final database = _database ??= FpvDatabase.open();
    try {
      await _globeController.setRenderingPaused(true);
    } catch (_) {
      /* Offline preparation can proceed without a ready renderer. */
    }
    if (!mounted) return;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => DataManagementScreen(
            database: database,
            latitude: _globeController.selectedPoint?.latitude ?? 46.8,
            longitude: _globeController.selectedPoint?.longitude ?? 8.3,
            cachedMaps: _cachedMaps,
            prepareOfflineSnapshots: (selected) async {
              final results = <String>[];
              for (final id in selected) {
                final OsintProvider<Object> provider = switch (id) {
                  'uas' => _globeController.uasProvider,
                  'obstacles' => _globeController.obstacles.provider,
                  _ => _globeController.avalanche.provider,
                };
                try {
                  await provider.fetch(forceRefresh: true);
                } catch (_) {
                  /* The provider retains and reports its previous snapshot. */
                }
                final status = provider.status;
                results.add(
                  '${switch (id) {
                    'uas' => 'UAS-Zonen',
                    'obstacles' => 'Vektorhindernisse',
                    _ => 'SLF-Bulletin',
                  }}: ${status.dataset == null
                      ? 'nicht verfügbar'
                      : status.error != null
                      ? 'vorheriger Datenstand; Aktualisierung fehlgeschlagen'
                      : status.cacheError != null
                      ? 'lokale Speicherung fehlgeschlagen; Offline-Verfügbarkeit nicht bestätigt'
                      : 'Datenstand lokal vorhanden; Gültigkeit separat prüfen'}',
                );
              }
              return results.join('\n');
            },
            onCachedMaps: (value) {
              if (mounted) setState(() => _cachedMaps = value);
            },
            onRegionsChanged: (region) {
              if (mounted) {
                setState(() {
                  _pendingOfflineRegion = region;
                  _awaitOfflineRenderer = true;
                  _mapCacheRevision++;
                });
              }
            },
            beforeRestore: () => _globeController.preferencesSettled,
            onRestored: () => _globeController.retryLoadingPreferences(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        try {
          await _globeController.setRenderingPaused(false);
        } catch (_) {
          /* The requested state is restored when the renderer recovers. */
        }
      }
    }
  }

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
  String? _lastLocationMessage;
  String? _lastSimulationReason;
  String? _lastRecordingMessage;
  SimulationSettings _simulationSettings = const SimulationSettings();
  bool _recordingReviewOpen = false;
  void _recordingReviewHandler() => unawaited(_openRecordingReview());
  Future<void> _openRecordingReview() async {
    if (_recordingReviewOpen ||
        !mounted ||
        !_globeController.recording.hasSamples ||
        _globeController.recording.busy) {
      return;
    }
    _recordingReviewOpen = true;
    try {
      if (_globeController.recording.running) {
        await _runCommand(() => _globeController.recording.control('stop'));
      }
      if (!mounted || !_globeController.recording.hasSamples) return;
      final flight = _globeController.recording.snapshot();
      final repository = _flightPlanRepository ??=
          widget.flightPlanRepository ??
          FlightPlanRepository(_database ??= FpvDatabase.open());
      final routeId = await showFlightRecordingReview(
        context,
        flight: flight,
        repository: repository,
        onDiscard: _globeController.discardFlightRecording,
      );
      if (!mounted || routeId == null) return;
      if (_globeController.recording.id == flight.id) {
        await _runCommand(_globeController.discardFlightRecording);
      }
      await _leaveGroundView();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => RouteEditorScreen(
            routeId: routeId,
            repository: repository,
            cachedMaps: _cachedMaps,
            spots: _spotRepository ??=
                widget.spotRepository ??
                SpotRepository(_database ??= FpvDatabase.open()),
            obstacleProvider: _globeController.obstacles.provider,
            uasProvider: _globeController.uasProvider,
            preferencesRepository:
                widget.preferencesRepository ??
                UserPreferencesRepository(_database ??= FpvDatabase.open()),
          ),
        ),
      );
      if (mounted) await _globeController.retryLoadingPreferences();
    } finally {
      _recordingReviewOpen = false;
    }
  }

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
          cachedMaps: _cachedMaps,
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
        sceneTime:
            _globeController.simulationSceneTime ??
            _simulationSettings.sceneTime,
        graphicsProfile:
            _globeController.simulationGraphicsProfile ??
            _simulationSettings.graphicsProfile,
        hudStyle:
            _globeController.simulationHudStyle ?? _simulationSettings.hudStyle,
        showCoordinates:
            _globeController.simulationShowCoordinates ??
            _simulationSettings.showCoordinates,
        controller:
            _globeController.simulationController ??
            _simulationSettings.controller,
      ),
      hasSelection: spot != null || point != null,
      windControls: WindControlsLauncher(globe: _globeController, flight: true),
      radioControls: LiveRadioLauncher(
        globe: _globeController,
        spots: _spotRepository ??=
            widget.spotRepository ??
            SpotRepository(_database ??= FpvDatabase.open()),
      ),
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
  AppLifecycleListener? _windLifecycle;
  bool _windSheetOpen = false;
  bool _radioSheetOpen = false;
  void _radioRequestHandler() => unawaited(_openRadioPreview());
  Future<void> _openRadioPreview() async {
    if (!mounted || _radioSheetOpen) return;
    _radioSheetOpen = true;
    try {
      await showLiveRadioSettings(
        context,
        _globeController,
        spots: _spotRepository ??=
            widget.spotRepository ??
            SpotRepository(_database ??= FpvDatabase.open()),
      );
    } finally {
      _radioSheetOpen = false;
    }
  }

  void _windRequestHandler() => unawaited(_openWindSettings());
  Future<void> _openWindSettings() async {
    if (!mounted || _windSheetOpen) return;
    _windSheetOpen = true;
    try {
      await showWindSettings(context, _globeController);
    } finally {
      _windSheetOpen = false;
    }
  }

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
    return showMapPanel<void>(
      context,
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

  Future<void> _openMapStatus() => showMapPanel<void>(
    context,
    builder: (context) => HomeMapStatusSheet(
      controller: _globeController,
      cachedMaps: _cachedMaps,
      onLayers: (tab) {
        Navigator.pop(context);
        unawaited(_openMapLayers(initialTab: tab));
      },
    ),
  );

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
    final result = await showDialog<RoadDestination>(
      context: context,
      builder: (context) => const CoordinatesDialog(),
    );

    if (result == null || !mounted) return;

    await _runCommand(
      () => _globeController.selectSearchDestination(
        name: result.name,
        latitude: result.point.latitude,
        longitude: result.point.longitude,
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
          cachedMaps: _cachedMaps,
          repository: repository,
          spots: _spotRepository ??=
              widget.spotRepository ??
              SpotRepository(_database ??= FpvDatabase.open()),
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
    if (_globeController.onLiveRadioSettingsRequested == _radioRequestHandler) {
      _globeController.onLiveRadioSettingsRequested = null;
    }
    _windLifecycle?.dispose();
    unawaited(_globeController.location.foreground(false));
    if (_globeController.onWindSettingsRequested == _windRequestHandler) {
      _globeController.onWindSettingsRequested = null;
    }
    if (_globeController.onRecordingReviewRequested ==
        _recordingReviewHandler) {
      _globeController.onRecordingReviewRequested = null;
    }
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
    _globeController.onWindSettingsRequested = _windRequestHandler;
    _globeController.onRecordingReviewRequested = _recordingReviewHandler;
    _globeController.onLiveRadioSettingsRequested = _radioRequestHandler;
    _windLifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _globeController.wind.foreground(state == AppLifecycleState.resumed);
        unawaited(
          _globeController.location.foreground(
            state == AppLifecycleState.resumed,
          ),
        );
      },
    );
  }

  void _onGlobeStateChanged() {
    final locationMessage = _globeController.location.message;
    if (locationMessage != null &&
        locationMessage != _lastLocationMessage &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(locationMessage)));
    }
    _lastLocationMessage = locationMessage;
    final recordingMessage = _globeController.recording.message;
    if (recordingMessage != null &&
        recordingMessage != _lastRecordingMessage &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(recordingMessage)));
    }
    _lastRecordingMessage = recordingMessage;
    _globeController.wind.flying(_globeController.simulationActive);
    if (!_globeController.isReady) _awaitOfflineRenderer = false;
    if (!_awaitOfflineRenderer &&
        _globeController.isReady &&
        _preferencesStarted &&
        _globeController.canEditPreferences &&
        _pendingOfflineRegion != null) {
      final region = _pendingOfflineRegion!;
      _pendingOfflineRegion = null;
      unawaited(
        _runCommand(() async {
          await _globeController.setMapStyle(
            region.style == 'relief'
                ? GlobeMapStyle.relief
                : GlobeMapStyle.topographic,
          );
          await _globeController.flyTo(
            latitude: (region.south + region.north) / 2,
            longitude: (region.west + region.east) / 2,
          );
        }),
      );
    }
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
        onData: _openData,
      ),
      body: SafeArea(
        child: GlobeInputScope(
          enabled: !_drawerOpen,
          child: HomeMapWorkspace(
            globe: GlobeView(
              floatingControls: true,
              cacheRevision: _mapCacheRevision,
              controller: _globeController,
              cachedMaps: _cachedMaps,
            ),
            navigation: ListenableBuilder(
              listenable: _globeController,
              builder: (context, _) => Builder(
                builder: (context) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Open navigation menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                    if (MediaQuery.sizeOf(context).width >= 900 &&
                        !_globeController.simulationActive)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text('FPVManager'),
                      ),
                    HomeMapStatusButton(
                      controller: _globeController,
                      cachedMaps: _cachedMaps,
                      onPressed: _openMapStatus,
                    ),
                    if (_globeController.simulationActive)
                      _mapActions(compact: true),
                  ],
                ),
              ),
            ),
            actions: ListenableBuilder(
              listenable: _globeController,
              builder: (context, _) => _globeController.simulationActive
                  ? const SizedBox.shrink()
                  : _mapActions(),
            ),
            selection: MapSelectionPanel(
              floating: true,
              controller: _globeController,
              spotsById: _spotsById,
              spotRepository: _spotRepository,
              onSpotDetails: _openSpotDetails,
              onCommand: _runCommand,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapActions({bool compact = false}) => MapActionMenu(
    compact: compact,
    controller: _globeController,
    groundButtonBuilder: _groundButton,
    onHome: () => _runCommand(_globeController.resetCamera),
    onCoordinates: _openCoordinatesDialog,
    onTerrain: _showTerrainElevation,
    onLayers: _openMapLayers,
    onWeather: _openWeather,
    onSimulation: _openSimulation,
    onRecordingReview: _openRecordingReview,
    onExitNavigation: () => _runCommand(_globeController.exitNavigation),
  );

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
