import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import '../globe/globe_controller.dart';
import '../globe/globe_view.dart';
import '../globe/terrain_status_banner.dart';
import '../airspace/uas_data_quality_banner.dart';
import 'route_editor_controller.dart';
import 'route_equipment_sheet.dart';
import 'route_editor_toolbar.dart';
import 'analysis/route_planning_settings_sheet.dart';
import 'analysis/route_analysis_controller.dart';
import 'analysis/route_analysis_sheet.dart';
import 'analysis/route_constraints_sheet.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../globe/map_layers_sheet.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import '../obstacles/obstacle_details_panel.dart';
import '../obstacles/obstacle_layers_section.dart';
import '../../core/osint/osint_provider.dart';
import '../signal/radio_analysis_controller.dart';
import '../signal/radio_analysis_sheet.dart';
import '../spots/data/spot_repository.dart';
import '../mobility/destination_search.dart';
import 'route_start_sheet.dart';
import '../offline/cached_map_notice.dart';
import 'route_scene_time_sheet.dart';

enum _RouteAction { equipment, planning, constraints, signal, layers, sunTime }

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({
    super.key,
    required this.repository,
    this.routeId,
    this.globeController,
    this.mapBuilder,
    this.obstacleProvider,
    this.uasProvider,
    this.preferencesRepository,
    this.spots,
    this.placeSearch,
    this.cachedMaps = false,
  });
  final FlightPlanRepository repository;
  final int? routeId;
  final GlobeController? globeController;
  final Widget Function(GlobeController)? mapBuilder;
  final SwissObstacleProvider? obstacleProvider;
  final OsintProvider<Map<String, dynamic>>? uasProvider;
  final UserPreferencesRepository? preferencesRepository;
  final SpotRepository? spots;
  final DestinationSearch? placeSearch;
  final bool cachedMaps;
  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  late final GlobeController _globe =
      widget.globeController ??
      GlobeController(
        obstacleProvider: widget.obstacleProvider,
        uasProvider: widget.uasProvider,
      );
  late final RouteEditorController _editor = RouteEditorController(
    repository: widget.repository,
    globe: _globe,
    routeId: widget.routeId,
  );
  final _name = TextEditingController();
  late final _analysis = RouteAnalysisController(_editor);
  late final _radio = RadioAnalysisController(_editor);
  bool _allowPop = false, _framed = false;
  bool _choosingStart = false;

  Future<void> _chooseStart({required bool search}) async {
    if (_choosingStart) return;
    setState(() => _choosingStart = true);
    try {
      final location = await showRouteStartLocation(
        context,
        search: search,
        spots: widget.spots,
        placeSearch: widget.placeSearch,
      );
      if (location == null ||
          !mounted ||
          !_globe.isReady ||
          _editor.points.isNotEmpty) {
        return;
      }
      await _command(() async {
        try {
          await _globe.focusSpot(
            latitude: location.position.latitude,
            longitude: location.position.longitude,
            rangeMeters: 800,
          );
        } catch (_) {
          // A missing offline terrain tile must not prevent choosing an area.
          if (!mounted || !_globe.isReady) rethrow;
          await _globe.flyTo(
            latitude: location.position.latitude,
            longitude: location.position.longitude,
            altitude: 6000,
          );
        }
        if (!mounted) return;
        if (location.spotId case final id?) {
          _framed = true;
          _editor.startAtSpot(spotId: id, position: location.position);
        }
      });
    } finally {
      if (mounted) setState(() => _choosingStart = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _globe.addListener(_ready);
    if (widget.preferencesRepository case final repository?) {
      unawaited(_globe.initializePreferences(repository));
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    await _editor.load();
    if (mounted) {
      _name.text = _editor.name;
      _ready();
    }
  }

  void _ready() {
    if (_framed ||
        !_globe.isReady ||
        _editor.loading ||
        _editor.points.isEmpty) {
      return;
    }
    _framed = true;
    unawaited(
      _command(() async {
        await _editor.syncMap();
        if (mounted && _globe.isReady) await _globe.frameRoute();
      }),
    );
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.translate("Map command failed. Please retry."),
            ),
          ),
        );
      }
    }
  }

  Future<void> _close() async {
    if (_editor.saving) return;
    if (_editor.dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.translate("Discard route changes?")),
          content: Text(
            context.translate("The current draft has unsaved changes."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.translate("Keep editing")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _globe.removeListener(_ready);
    _analysis.dispose();
    _radio.dispose();
    _editor.dispose();
    _name.dispose();
    if (widget.globeController == null) _globe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_editor, _globe]),
    builder: (context, _) => PopScope(
      canPop: _allowPop || (!_editor.dirty && !_editor.saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.translate("Route editor")),
          leading: IconButton(
            tooltip: context.translate("Back"),
            onPressed: _editor.saving ? null : _close,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            PopupMenuButton<_RouteAction>(
              tooltip: context.translate("Route options"),
              enabled:
                  !_editor.loading && !_editor.saving && !_editor.loadFailed,
              onSelected: (action) {
                switch (action) {
                  case _RouteAction.equipment:
                    showRouteEquipment(context, _editor);
                  case _RouteAction.planning:
                    showRoutePlanningSettings(context, _editor);
                  case _RouteAction.constraints:
                    showRouteConstraints(context, _editor);
                  case _RouteAction.signal:
                    showRadioAnalysis(context, _radio);
                  case _RouteAction.layers:
                    _layers();
                  case _RouteAction.sunTime:
                    showRouteSceneTime(context, _editor);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _RouteAction.sunTime,
                  child: Text(context.translate("Sonnen- und Mondzeit")),
                ),
                PopupMenuItem(
                  value: _RouteAction.equipment,
                  child: Text(context.translate("Route equipment")),
                ),
                PopupMenuItem(
                  value: _RouteAction.planning,
                  child: Text(context.translate("Planning assumptions")),
                ),
                PopupMenuItem(
                  value: _RouteAction.constraints,
                  child: Text(context.translate("Route constraints")),
                ),
                PopupMenuItem(
                  value: _RouteAction.signal,
                  enabled: _editor.points.length >= 2,
                  child: Text(context.translate("Terrain & radio path")),
                ),
                PopupMenuItem(
                  value: _RouteAction.layers,
                  enabled: _globe.isReady,
                  child: Text(context.translate("Map layers")),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _editor.canSave && !_choosingStart
                  ? () async {
                      FocusScope.of(context).unfocus();
                      if (await _editor.save() && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.translate("Route saved locally"),
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _editor.saving
                    ? context.translate("Saving…")
                    : context.translate("Save"),
              ),
            ),
          ],
        ),
        body: _editor.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: TextField(
                      controller: _name,
                      enabled: !_editor.saving && !_editor.loadFailed,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: context.translate("Route name"),
                        counterText: '',
                        suffixText: _editor.dirty
                            ? context.translate("Unsaved")
                            : _editor.routeId == null
                            ? 'Draft'
                            : context.translate("Saved"),
                      ),
                      onChanged: _editor.rename,
                    ),
                  ),
                  TerrainStatusBanner(controller: _globe),
                  if (widget.cachedMaps) const CachedMapNotice(),
                  if (_editor.points.isEmpty && !_editor.loadFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (widget.spots != null)
                            OutlinedButton.icon(
                              onPressed:
                                  !_globe.isReady ||
                                      _choosingStart ||
                                      _editor.saving
                                  ? null
                                  : () => _chooseStart(search: false),
                              icon: const Icon(Icons.place_outlined),
                              label: Text(context.translate("Saved spot")),
                            ),
                          OutlinedButton.icon(
                            onPressed:
                                !_globe.isReady ||
                                    _choosingStart ||
                                    _editor.saving
                                ? null
                                : () => _chooseStart(search: true),
                            icon: const Icon(Icons.search),
                            label: Text(context.translate("Search place")),
                          ),
                        ],
                      ),
                    ),
                  UasDataQualityBanner(
                    controller: _globe,
                    onDetails: () => _layers(initialTab: MapLayerTab.airspace),
                  ),
                  ObstacleStatusBanner(
                    controller: _globe.obstacles,
                    onDetails: () => _layers(initialTab: MapLayerTab.obstacles),
                  ),
                  Expanded(
                    child:
                        widget.mapBuilder?.call(_globe) ??
                        GlobeView(
                          controller: _globe,
                          cachedMaps: widget.cachedMaps,
                        ),
                  ),
                  if (_editor.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _editor.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          if (_editor.loadFailed)
                            TextButton(
                              onPressed: _load,
                              child: Text(context.translate("Retry loading")),
                            ),
                        ],
                      ),
                    ),
                  if (_editor.mapError != null)
                    TextButton(
                      onPressed: _editor.syncMap,
                      child: Text(_editor.mapError!),
                    ),
                  if (MediaQuery.viewInsetsOf(context).bottom == 0)
                    if (_globe.obstacles.selected case final feature?)
                      ObstacleDetailsPanel(
                        feature: feature,
                        snapshot:
                            _globe.obstacles.provider.status.dataset?.data,
                        onClose: _globe.obstacles.clearSelection,
                      )
                    else
                      _tools(context),
                ],
              ),
      ),
    ),
  );

  Widget _tools(BuildContext context) => RouteEditorToolbar(
    editor: _editor,
    onAnalysis:
        !_editor.saving && !_editor.loadFailed && _editor.points.length >= 2
        ? () => showRouteAnalysis(context, _analysis)
        : null,
    onFrame: _globe.isReady && _editor.points.isNotEmpty
        ? () => _command(_globe.frameRoute)
        : null,
  );

  Future<void> _layers({MapLayerTab initialTab = MapLayerTab.map}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.9,
          child: MapLayersSheet(controller: _globe, initialTab: initialTab),
        ),
      );
}
