import 'dart:async';

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
import '../../core/database/repositories/user_preferences_repository.dart';
import '../globe/map_layers_sheet.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import '../obstacles/obstacle_details_panel.dart';
import '../obstacles/obstacle_layers_section.dart';
import '../../core/osint/osint_provider.dart';

enum _RouteAction { equipment, planning, layers }

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
  });
  final FlightPlanRepository repository;
  final int? routeId;
  final GlobeController? globeController;
  final Widget Function(GlobeController)? mapBuilder;
  final SwissObstacleProvider? obstacleProvider;
  final OsintProvider<Map<String, dynamic>>? uasProvider;
  final UserPreferencesRepository? preferencesRepository;
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
  bool _allowPop = false, _framed = false;

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
          const SnackBar(content: Text('Map command failed. Please retry.')),
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
          title: const Text('Discard route changes?'),
          content: const Text('The current draft has unsaved changes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
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
          title: const Text('Route editor'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _editor.saving ? null : _close,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            PopupMenuButton<_RouteAction>(
              tooltip: 'Route options',
              enabled:
                  !_editor.loading && !_editor.saving && !_editor.loadFailed,
              onSelected: (action) {
                switch (action) {
                  case _RouteAction.equipment:
                    showRouteEquipment(context, _editor);
                  case _RouteAction.planning:
                    showRoutePlanningSettings(context, _editor);
                  case _RouteAction.layers:
                    _layers();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _RouteAction.equipment,
                  child: Text('Route equipment'),
                ),
                const PopupMenuItem(
                  value: _RouteAction.planning,
                  child: Text('Planning assumptions'),
                ),
                PopupMenuItem(
                  value: _RouteAction.layers,
                  enabled: _globe.isReady,
                  child: const Text('Map layers'),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _editor.canSave
                  ? () async {
                      FocusScope.of(context).unfocus();
                      if (await _editor.save() && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Route saved locally')),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(_editor.saving ? 'Saving…' : 'Save'),
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
                        labelText: 'Route name',
                        counterText: '',
                        suffixText: _editor.dirty
                            ? 'Unsaved'
                            : _editor.routeId == null
                            ? 'Draft'
                            : 'Saved',
                      ),
                      onChanged: _editor.rename,
                    ),
                  ),
                  TerrainStatusBanner(controller: _globe),
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
                        GlobeView(controller: _globe),
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
                              child: const Text('Retry loading'),
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
