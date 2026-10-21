import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import '../globe/globe_controller.dart';
import '../globe/globe_view.dart';
import '../globe/terrain_status_banner.dart';
import '../airspace/airspace_check_sheet.dart';
import 'route_editor_controller.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../globe/map_layers_sheet.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import '../obstacles/obstacle_details_panel.dart';
import '../obstacles/obstacle_layers_section.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({
    super.key,
    required this.repository,
    this.routeId,
    this.globeController,
    this.mapBuilder,
    this.obstacleProvider,
    this.preferencesRepository,
  });
  final FlightPlanRepository repository;
  final int? routeId;
  final GlobeController? globeController;
  final Widget Function(GlobeController)? mapBuilder;
  final SwissObstacleProvider? obstacleProvider;
  final UserPreferencesRepository? preferencesRepository;
  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  late final GlobeController _globe =
      widget.globeController ??
      GlobeController(obstacleProvider: widget.obstacleProvider);
  late final RouteEditorController _editor = RouteEditorController(
    repository: widget.repository,
    globe: _globe,
    routeId: widget.routeId,
  );
  final _name = TextEditingController();
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
            IconButton(
              tooltip: 'Map layers',
              onPressed: _globe.isReady ? _layers : null,
              icon: const Icon(Icons.layers_outlined),
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
                  ObstacleStatusBanner(
                    controller: _globe.obstacles,
                    onDetails: _layers,
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

  Widget _tools(BuildContext context) {
    final point = _editor.selected;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editor.moveId != null ? 'Click the new position on the map.' : 'Click map to add · Drag a point to move · Right-click / Delete to remove',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Text(
                '3D preview · 30 m AGL at waypoints',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_editor.points.length} waypoints${point == null ? '' : ' · Selected ${_editor.points.indexOf(point) + 1}'}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Check route airspace',
                    onPressed:
                        !_editor.saving &&
                            !_editor.loadFailed &&
                            _editor.points.isNotEmpty
                        ? () => showAirspaceCheck(
                            context,
                            controller: _globe,
                            name: _editor.name,
                            positions: [
                              for (final p in _editor.points) p.position,
                            ],
                            route: true,
                          )
                        : null,
                    icon: const Icon(Icons.shield_outlined),
                  ),
                  IconButton(
                    tooltip: 'Undo waypoint change',
                    onPressed: _editor.canUndo ? _editor.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Show entire route',
                    onPressed: _globe.isReady && _editor.points.isNotEmpty
                        ? () => _command(_globe.frameRoute)
                        : null,
                    icon: const Icon(Icons.fit_screen),
                  ),
                ],
              ),
              if (point != null) ...[
                Text(
                  '${point.position.latitude.toStringAsFixed(6)}, ${point.position.longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !_editor.saving ? _editor.toggleMove : null,
                      icon: const Icon(Icons.open_with),
                      label: Text(
                        _editor.moveId == null ? 'Move point' : 'Cancel move',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_editor.saving
                          ? () => _editor.deletePoint(point.key)
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete point'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _layers() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: MapLayersSheet(controller: _globe),
    ),
  );
}
