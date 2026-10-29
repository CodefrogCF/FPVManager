import 'dart:async';

import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';
import '../globe/globe_view.dart';
import 'navigation_platform.dart';
import 'road_navigation.dart';
import 'traffic_bulletin.dart';
import 'traffic_counters_section.dart';
import 'road_route_comparison.dart';
import '../offline/cached_map_notice.dart';

String navigationDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

class RoadNavigationScreen extends StatefulWidget {
  const RoadNavigationScreen({
    super.key,
    required this.navigation,
    this.platform = const NavigationPlatform(),
    this.mapBuilder,
    this.initialMapStyle = GlobeMapStyle.satellite,
    this.initialRoadsVisible = false,
    this.initialRoadsOpacity = .8,
    this.cachedMaps = false,
  });
  final RoadNavigation navigation;
  final NavigationPlatform platform;
  final Widget Function(GlobeController controller)? mapBuilder;
  final GlobeMapStyle initialMapStyle;
  final bool initialRoadsVisible;
  final double initialRoadsOpacity;
  final bool cachedMaps;
  @override
  State<RoadNavigationScreen> createState() => _RoadNavigationScreenState();
}

class _RoadNavigationScreenState extends State<RoadNavigationScreen>
    with WidgetsBindingObserver {
  final _globe = GlobeController();
  bool _follow = true, _voice = false;
  bool _mapConfigured = false;
  static const _cameraDistances = <double>[
    60,
    100,
    150,
    250,
    400,
    550,
    800,
    1200,
    1800,
  ];
  int _zoomIndex = 5;
  String? _voiceMessage, _mapError;
  final _spoken = <String>{};
  Object? _lastFix;
  Object? _lastTraffic;
  Object? _lastCounters;
  String? _lastTrafficIds;
  bool? _lastReliable;
  int _routeRevision = -1;
  RoadNavigation get nav => widget.navigation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _globe.addListener(_cameraChanged);
    nav.addListener(_changed);
    _changed();
    nav.start();
    unawaited(widget.platform.keepAwake(true));
  }

  void _cameraChanged() {
    if (_globe.isReady && !_mapConfigured) {
      _mapConfigured = true;
      // Readiness can arrive during a platform-view build. Configure afterwards.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await _globe.setMapStyle(widget.initialMapStyle);
          if (widget.initialRoadsVisible && mounted) {
            await _globe.setRoadsOverlay(
              visible: true,
              opacity: widget.initialRoadsOpacity,
            );
          }
          if (mounted) setState(() {});
        } catch (_) {
          if (mounted) {
            setState(
              () => _mapError =
                  'Kartendarstellung konnte nicht übernommen werden.',
            );
          }
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    final follow = _globe.roadNavigationFollowing;
    if (mounted && follow != null && follow != _follow) {
      setState(() => _follow = follow);
    }
  }

  void _zoom(int delta) {
    setState(
      () => _zoomIndex = (_zoomIndex + delta).clamp(
        0,
        _cameraDistances.length - 1,
      ),
    );
    _updateMap();
  }

  void _changed() {
    if (!mounted) return;
    if (_routeRevision != nav.routeRevision) {
      _routeRevision = nav.routeRevision;
      _spoken.clear();
      unawaited(
        _globe.showSituationalOverlay(nav.route.overlay).catchError((Object _) {
          if (mounted) {
            setState(() => _mapError = 'Routenanzeige fehlgeschlagen.');
          }
        }),
      );
    }
    final upcomingTraffic = nav.upcomingTraffic;
    final trafficIds = upcomingTraffic.map((f) => f['id']).join('|');
    if (!identical(_lastTraffic, nav.trafficAlerts) ||
        _lastTrafficIds != trafficIds) {
      _lastTraffic = nav.trafficAlerts;
      _lastTrafficIds = trafficIds;
      unawaited(
        _globe
            .showSituationalOverlay({
              'id': 'traffic',
              'visible': true,
              'features': upcomingTraffic,
            })
            .catchError((Object _) {
              if (mounted) {
                setState(() => _mapError = 'Verkehrsanzeige fehlgeschlagen.');
              }
            }),
      );
    }
    final counterData = nav.counters?.status.dataset?.data;
    if (counterData != null && !identical(_lastCounters, counterData)) {
      _lastCounters = counterData;
      unawaited(
        _globe
            .showSituationalOverlay({
              'id': 'traffic-counters',
              'visible': true,
              'features': counterData['features'],
            })
            .catchError((Object _) {
              if (mounted) {
                setState(
                  () =>
                      _mapError = 'Messstellen konnten nicht angezeigt werden.',
                );
              }
            }),
      );
    }
    if (!identical(_lastFix, nav.fix) || _lastReliable != nav.reliable) {
      _lastFix = nav.fix;
      _lastReliable = nav.reliable;
      _updateMap();
    }
    if (_voice && nav.reliable && !nav.offRoute && !nav.recalculating) {
      final step = nav.nextManeuver,
          distance =
              (step?.atMeters ?? nav.route.distanceMeters) - nav.progressMeters;
      final threshold = (nav.fix?.speedMetersPerSecond ?? 0) > 15 ? 400 : 150;
      final key =
          '${nav.routeRevision}:${step?.atMeters}:${distance < 40 ? 'now' : 'ahead'}';
      if (nav.arrived && _spoken.add('arrived')) {
        unawaited(_speak('Ziel erreicht'));
      } else if (!nav.arrived &&
          step != null &&
          distance <= threshold &&
          _spoken.add(key)) {
        unawaited(
          _speak(
            '${distance > 40 ? 'In ${navigationDistance(distance)}: ' : ''}${step.instruction}${step.road.isEmpty ? '' : ', ${step.road}'}',
          ),
        );
      }
    }
    setState(() {});
  }

  Future<void> _speak(String text) async {
    final ok = await widget.platform.speak(text);
    if (mounted && !ok) {
      setState(() {
        _voice = false;
        _voiceMessage = 'Offline-Sprachausgabe derzeit nicht verfügbar. Installierte deutsche Stimme prüfen.';
      });
    }
  }

  void _updateMap() {
    final p = nav.reliable ? nav.fix?.point : null;
    unawaited(
      _globe
          .setRoadNavigation(
            active: nav.active,
            follow: _follow,
            cameraDistanceMeters: _cameraDistances[_zoomIndex],
            latitude: p?.latitude,
            longitude: p?.longitude,
            heading: nav.travelHeadingDegrees ?? nav.match?.heading ?? 0,
          )
          .catchError((Object _) {
            if (mounted) {
              setState(() => _mapError = 'Standortanzeige fehlgeschlagen.');
            }
          }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      nav.start();
      unawaited(widget.platform.keepAwake(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      nav.pause();
      unawaited(widget.platform.stopVoice());
      unawaited(widget.platform.keepAwake(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nav.removeListener(_changed);
    nav.pause();
    unawaited(widget.platform.stopVoice());
    unawaited(widget.platform.keepAwake(false));
    _globe.removeListener(_cameraChanged);
    _globe.dispose();
    super.dispose();
  }

  IconData _turn(String? modifier) => switch (modifier) {
    'left' || 'sharp left' => Icons.turn_left,
    'right' || 'sharp right' => Icons.turn_right,
    'slight left' => Icons.turn_slight_left,
    'slight right' => Icons.turn_slight_right,
    'uturn' => Icons.u_turn_left,
    _ => Icons.straight,
  };
  void _traffic() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: nav,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Verkehr entlang der Route',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Meldungen im 300-m-Umfeld; Straße und Fahrtrichtung sind nicht bestätigt. Die Ankunftsschätzung enthält keine Stauzeiten.',
                  ),
                  if (nav.traffic == null && nav.counters == null)
                    const Text('Verkehrsdaten ausgeschaltet'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Verkehr bei Neuberechnung berücksichtigen',
                    ),
                    subtitle: const Text(
                      'Nur ausreichend zugeordnete aktuelle Daten. Neue Meldungen allein lösen keinen Routenwechsel aus.',
                    ),
                    value: nav.trafficAwareRouting,
                    onChanged: nav.setTrafficAwareRouting,
                  ),
                  OutlinedButton(
                    onPressed:
                        nav.reliable && !nav.recalculating && !nav.arrived
                        ? nav.reroute
                        : null,
                    child: const Text('Routenalternativen neu berechnen'),
                  ),
                  const Text(
                    'Neuberechnungen sind frühestens alle 30 Sekunden möglich. Die Ankunftsschätzung bleibt ohne Verkehrszuschläge.',
                  ),
                  if (nav.routeTrafficEvaluation case final evaluation?) ...[
                    RouteTrafficAssessmentView(
                      assessment:
                          evaluation.assessments[evaluation.recommendedIndex],
                    ),
                    RouteTrafficExplanation(evaluation: evaluation),
                  ],
                  if (nav.traffic != null || nav.counters != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatisch aktualisieren'),
                      subtitle: const Text(
                        'Alle 60 Sekunden während der aktiven Navigation',
                      ),
                      value: nav.automaticTrafficUpdates,
                      onChanged: nav.setAutomaticTrafficUpdates,
                    ),
                  if (nav.traffic != null) ...[
                    FilledButton.icon(
                      onPressed: nav.traffic!.status.update.name == 'loading'
                          ? null
                          : () => nav.refreshTraffic(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Verkehr aktualisieren'),
                    ),
                    TrafficBulletin(
                      provider: nav.traffic!,
                      routeRecords: nav.trafficAlerts
                          .where(
                            (f) =>
                                (f['alongMeters'] as num) >=
                                (nav.match?.along ?? 0) - 100,
                          )
                          .toList(),
                      progressMeters: nav.match?.along ?? 0,
                    ),
                  ],
                  if (nav.counters != null) ...[
                    Text(
                      'Messstellen im gewählten Gebiet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TrafficCountersReadout(provider: nav.counters!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, step = nav.nextManeuver;
    final distance =
        ((step?.atMeters ?? nav.route.distanceMeters) - nav.progressMeters)
            .clamp(0.0, double.infinity);
    final eta = DateTime.now().add(
      Duration(seconds: nav.remainingSeconds.round()),
    );
    final title = nav.arrived
        ? 'Ziel erreicht'
        : nav.recalculating
        ? 'Route wird neu berechnet'
        : !nav.reliable
        ? 'Warte auf zuverlässiges GPS'
        : nav.passedDestination
        ? 'Am Ziel vorbeigefahren'
        : nav.wrongDirection
        ? 'Fahrtrichtung weicht von der Route ab'
        : nav.offRoute
        ? 'Abseits der Route'
        : step?.instruction ?? 'Der Route folgen';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Kartendarstellung',
            icon: const Icon(Icons.layers_outlined),
            enabled: _globe.isReady,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'topographic',
                child: Text('Topografische Karte'),
              ),
              const PopupMenuItem(
                value: 'satellite',
                child: Text('Satellitenkarte'),
              ),
              CheckedPopupMenuItem(
                value: 'roads',
                checked: _globe.roadsVisible,
                child: const Text('Straßen und Wege'),
              ),
            ],
            onSelected: (choice) async {
              try {
                if (choice == 'roads') {
                  await _globe.setRoadsOverlay(visible: !_globe.roadsVisible);
                } else {
                  await _globe.setMapStyle(GlobeMapStyle.values.byName(choice));
                }
                if (mounted) setState(() {});
              } catch (_) {
                if (mounted) {
                  setState(
                    () => _mapError =
                        'Kartendarstellung konnte nicht geändert werden.',
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: _voice
                ? 'Sprachausgabe ausschalten'
                : 'Offline-Sprachausgabe einschalten',
            icon: Icon(_voice ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() {
                _voice = !_voice;
                _spoken.clear();
                _voiceMessage = null;
              });
              if (!_voice) {
                unawaited(widget.platform.stopVoice());
              } else {
                _changed();
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Beenden'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!nav.reliable)
            TextButton.icon(
              onPressed: () {
                nav.pause();
                nav.start();
              },
              icon: const Icon(Icons.my_location),
              label: const Text('GPS erneut verbinden'),
            ),
          Material(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    nav.arrived ? Icons.flag : _turn(step?.modifier),
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nav.reliable && !nav.arrived)
                          Text(
                            navigationDistance(distance),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (nav.reliable &&
                            step != null &&
                            step.road.isNotEmpty)
                          Text(step.road),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nav.error ?? nav.routeError ?? _voiceMessage ?? _mapError
              case final String message)
            Padding(padding: const EdgeInsets.all(8), child: Text(message)),
          if (widget.cachedMaps) const CachedMapNotice(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      widget.mapBuilder?.call(_globe) ??
                      GlobeView(
                        controller: _globe,
                        cachedMaps: widget.cachedMaps,
                      ),
                ),
                Positioned(
                  right: 12,
                  bottom: 55,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_follow)
                        Material(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          elevation: 3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Näher heranzoomen',
                                onPressed: _zoomIndex > 0
                                    ? () => _zoom(-1)
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                tooltip: 'Weiter herauszoomen',
                                onPressed:
                                    _zoomIndex < _cameraDistances.length - 1
                                    ? () => _zoom(1)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'navigation-follow',
                        tooltip: _follow
                            ? 'Karte frei bewegen'
                            : 'Standort folgen',
                        onPressed: () {
                          setState(() => _follow = !_follow);
                          _updateMap();
                        },
                        child: Icon(
                          _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                        ),
                      ),
                    ],
                  ),
                ),
                if (nav.reliable)
                  Positioned(
                    left: 12,
                    bottom: 55,
                    child: Chip(
                      label: Text(
                        nav.fix?.speedMetersPerSecond == null
                            ? '— km/h'
                            : '${(nav.fix!.speedMetersPerSecond! * 3.6).round()} km/h',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    nav.reliable
                        ? '${(nav.remainingSeconds / 60).ceil()} min · ${navigationDistance(nav.remainingMeters)} · Ankunft ${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}'
                        : 'Fortschritt pausiert · GPS prüfen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'OSRM / FOSSGIS · © OpenStreetMap · Schätzung ohne Live-Verkehr',
                  ),
                  TextButton.icon(
                    onPressed: _traffic,
                    icon: const Icon(Icons.traffic),
                    label: Text(
                      '${nav.upcomingTraffic.length} Hinweise · ${nav.trafficBadge}',
                    ),
                  ),
                  if (nav.offRoute)
                    TextButton.icon(
                      onPressed: nav.recalculating ? null : () => nav.reroute(),
                      icon: const Icon(Icons.alt_route),
                      label: const Text('Route neu berechnen'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
