import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/fpv_database.dart';
import '../../core/osint/api_credential_vault.dart';
import '../../core/osint/osint_provider_state.dart';
import '../globe/globe_controller.dart';
import '../spots/data/spot_repository.dart';
import '../spots/data/spot_location_service.dart';
import 'mobility_preferences.dart';
import 'ojp/public_transport_section.dart';
import 'osm_poi/osm_poi_section.dart';
import 'ev_charging/ev_charging_models.dart';
import 'ev_charging/ev_charging_section.dart';
import 'shared_mobility/shared_mobility_section.dart';
import 'road_routing.dart';
import 'destination_search.dart';
import 'situational_layers_section.dart';
import 'situational_provider.dart';
import 'traffic_bulletin.dart';
import 'traffic_incident.dart';
import 'traffic_counters_provider.dart';
import 'traffic_counters_section.dart';
import 'road_route_comparison.dart';
import 'navigation_location.dart';
import 'road_navigation.dart';
import 'road_navigation_screen.dart';
import 'tmc_repository.dart';
import 'tmc_section.dart';

class MobilityScreen extends StatefulWidget {
  const MobilityScreen({
    super.key,
    required this.spots,
    required this.preferences,
    required this.globe,
    this.initialSpotId,
    this.initialCenter,
    this.initialTab = 0,
    this.router,
    this.cachedMaps = false,
    this.tmcRepository,
  });
  final SpotRepository spots;
  final MobilityPreferences preferences;
  final GlobeController globe;
  final int? initialSpotId;
  final MobilityPoint? initialCenter;
  final int initialTab;
  final RoadRouter? router;
  final bool cachedMaps;
  final TmcRepository? tmcRepository;
  @override
  State<MobilityScreen> createState() => _MobilityScreenState();
}

class _MobilityScreenState extends State<MobilityScreen> {
  final _fields = {
    for (final key in [
      'originLat',
      'originLon',
      'destinationLat',
      'destinationLon',
      'parkingLat',
      'parkingLon',
      'accessLat',
      'accessLon',
      'areaLat',
      'areaLon',
    ])
      key: TextEditingController(),
  };
  final _key = TextEditingController();
  late final RoadRouter _router = widget.router ?? RoadRouter();
  late final _spots = widget.spots.getAllSpots();
  final _vault = LocalApiCredentialVault.shared;
  late final _tmc = widget.tmcRepository ?? TmcRepository();
  Spot? _spot;
  bool _freeDestination = false;
  String? _destinationName;
  int _selection = 0;
  MobilityPoint? _sharedMobilityCenter;
  RoadRoute? _route;
  RoadRoute? _routeBundle;
  bool _trafficRouting = false;
  bool _busy = false,
      _roadConsent = false,
      _airConsent = false,
      _trafficTerms = false;
  String? _message;
  SituationalProvider? _traffic, _aircraft;
  TrafficCountersProvider? _counters;
  Timer? _freshness;
  @override
  void initState() {
    super.initState();
    final center = widget.initialCenter;
    if (center != null) {
      _fields['areaLat']!.text = '${center.latitude}';
      _fields['areaLon']!.text = '${center.longitude}';
    }
    _freshness = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_loadSpot());
  }

  Future<void> _loadSpot() async {
    try {
      final spots = await _spots;
      final selected =
          spots.where((s) => s.id == widget.initialSpotId).firstOrNull ??
          spots.firstOrNull;
      if (mounted && selected != null) await _chooseSpot(selected);
      if (mounted && spots.isEmpty) setState(() => _freeDestination = true);
    } catch (_) {
      if (mounted) setState(() => _message = 'Saved spots unavailable.');
    }
  }

  Future<void> _chooseSpot(Spot value) async {
    final operation = ++_selection;
    for (final key in ['parkingLat', 'parkingLon', 'accessLat', 'accessLon']) {
      _fields[key]!.clear();
    }
    setState(() {
      _spot = value;
      _route = null;
      _message = null;
      _busy = true;
    });
    try {
      final access = await widget.preferences.loadAccess(value.id);
      if (!mounted || operation != _selection) return;
      for (final pair in [
        ('parking', access.parking),
        ('access', access.access),
      ]) {
        _fields['${pair.$1}Lat']!.text = pair.$2 == null
            ? ''
            : '${pair.$2!.latitude}';
        _fields['${pair.$1}Lon']!.text = pair.$2 == null
            ? ''
            : '${pair.$2!.longitude}';
      }
      if (widget.initialCenter == null) {
        _aircraft?.dispose();
        _aircraft = null;
        _fields['areaLat']!.text = '${value.latitude}';
        _fields['areaLon']!.text = '${value.longitude}';
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to load parking/access notes.');
      }
    } finally {
      if (mounted && operation == _selection) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _selection++;
    _freshness?.cancel();
    for (final field in _fields.values) {
      field.dispose();
    }
    _key.dispose();
    _traffic?.dispose();
    _counters?.dispose();
    _aircraft?.dispose();
    if (widget.tmcRepository == null) _tmc.dispose();
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  MobilityPoint? _point(String prefix, {bool optional = false}) {
    final lat = _fields['${prefix}Lat']!.text.trim(),
        lon = _fields['${prefix}Lon']!.text.trim();
    if (optional && lat.isEmpty && lon.isEmpty) return null;
    final a = double.tryParse(lat.replaceAll(',', '.')),
        b = double.tryParse(lon.replaceAll(',', '.'));
    if (a == null || b == null) {
      throw const FormatException(
        'Enter both latitude and longitude in decimal degrees.',
      );
    }
    return MobilityPoint(a, b);
  }

  Widget _pointFields(String prefix, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final axis in ['Lat', 'Lon']) ...[
            if (axis == 'Lon') const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: ValueKey('$prefix$axis'),
                controller: _fields['$prefix$axis'],
                enabled: !_busy,
                onChanged: (_) => setState(() {
                  if (prefix == 'area') {
                    _aircraft?.dispose();
                    _aircraft = null;
                  } else {
                    if (prefix == 'destination') _destinationName = null;
                    _route = null;
                  }
                }),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: axis == 'Lat'
                      ? context.localized(
                          "Latitude",
                          (l10n) => l10n.mobilityLatitudeced3905e,
                        )
                      : context.localized(
                          "Longitude",
                          (l10n) => l10n.mobilityLongitude6f9f011c,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error) {
            FormatException() => error.message,
            OsintProviderException() => error.message,
            SpotLocationException() => error.message,
            _ => 'Unable to complete this request. Check coordinates, access and network, then retry.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _map() => Navigator.of(context).popUntil((route) => route.isFirst);
  Future<void> _show(Map<String, dynamic> overlay) async {
    await widget.globe.showSituationalOverlay(overlay);
    if (mounted) _map();
  }

  Future<void> _deviceOrigin() => _run(() async {
    final location = await const SpotLocationService().currentLocation();
    if (!mounted) return;
    _fields['originLat']!.text = '${location.position.latitude}';
    _fields['originLon']!.text = '${location.position.longitude}';
    _route = null;
  });
  Widget _road() => FutureBuilder<List<Spot>>(
    future: _spots,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.localized(
            "Driving route to an address, coordinates or saved spot. Times are OSRM baseline estimates. Available traffic can help compare alternatives. Verify parking, private roads and the final approach locally.",
            (l10n) => l10n.commonDrivingRouteToAn298a4f2a,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                context.localized(
                  "Saved spot",
                  (l10n) => l10n.commonSavedSpot64ad0674,
                ),
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                context.localized(
                  "Freies Ziel",
                  (l10n) => l10n.mobilityFreiesZiele762f189,
                ),
              ),
            ),
          ],
          selected: {_freeDestination},
          onSelectionChanged: _busy
              ? null
              : (v) => setState(() {
                  _freeDestination = v.first;
                  _route = null;
                  _message = null;
                }),
        ),
        const SizedBox(height: 12),
        if (_freeDestination) ...[
          RoadDestinationSearch(
            onSelected: (result) => setState(() {
              _fields['destinationLat']!.text = '${result.point.latitude}';
              _fields['destinationLon']!.text = '${result.point.longitude}';
              _destinationName = result.name;
              _route = null;
            }),
          ),
          if (_destinationName != null)
            Text(
              context.localizedWithArgs("Ziel: {0}", [
                _destinationName,
              ], (l10n, value) => l10n.mobilityZiel85926175(value(0))),
            ),
          const SizedBox(height: 12),
          _pointFields(
            'destination',
            'Zielkoordinaten (auch direkt eingebbar)',
          ),
        ] else if (snapshot.hasError)
          Text(
            context.localized(
              "Saved spots unavailable.",
              (l10n) => l10n.mobilitySavedSpotsUnavailableb5814146,
            ),
          )
        else if (!snapshot.hasData)
          const LinearProgressIndicator()
        else if (snapshot.data!.isEmpty)
          Text(
            context.localized(
              "No saved spots. Choose Freies Ziel to enter a destination.",
              (l10n) => l10n.mobilityNoSavedSpotsChoose44cb95eb,
            ),
          )
        else
          DropdownButtonFormField<int>(
            key: ValueKey(_spot?.id),
            initialValue: _spot?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.localized(
                "Destination spot",
                (l10n) => l10n.mobilityDestinationSpotdfb0a64e,
              ),
            ),
            items: [
              for (final spot in snapshot.data!)
                DropdownMenuItem(value: spot.id, child: Text(spot.name)),
            ],
            onChanged: _busy
                ? null
                : (id) {
                    final spot = snapshot.data!
                        .where((s) => s.id == id)
                        .firstOrNull;
                    if (spot != null) unawaited(_chooseSpot(spot));
                  },
          ),
        const SizedBox(height: 16),
        _pointFields('origin', 'Start location'),
        OutlinedButton.icon(
          onPressed: _busy ? null : _deviceOrigin,
          icon: const Icon(Icons.my_location),
          label: Text(
            context.localized(
              "Use device location",
              (l10n) => l10n.mobilityUseDeviceLocation37b5a739,
            ),
          ),
        ),
        Text(
          context.localized(
            "Location access is requested only when pressed; coordinates are sent to the routing provider only when you calculate.",
            (l10n) => l10n.mobilityLocationAccessIsRequestedab7f6719,
          ),
        ),
        const SizedBox(height: 16),
        if (!_freeDestination)
          ExpansionTile(
            title: Text(
              context.localized(
                "Optional parking & access points",
                (l10n) => l10n.mobilityOptionalParkingAccessPoints7538207e,
              ),
            ),
            children: [
              _pointFields('parking', 'Parking (optional)'),
              _pointFields('access', 'Access point (optional)'),
              OutlinedButton(
                onPressed: _busy || _spot == null
                    ? null
                    : () => _run(() async {
                        final notes = SpotAccess(
                          parking: _point('parking', optional: true),
                          access: _point('access', optional: true),
                        );
                        await widget.preferences.saveAccess(_spot!.id, notes);
                        if (mounted) {
                          setState(
                            () => _message =
                                'Parking/access notes saved locally.',
                          );
                        }
                      }),
                child: Text(
                  context.localized(
                    "Save access notes locally",
                    (l10n) => l10n.mobilitySaveAccessNotesLocallyf5e29d86,
                  ),
                ),
              ),
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _roadConsent,
          onChanged: (v) => setState(() => _roadConsent = v ?? false),
          title: Text(
            context.localized(
              "Allow sending start and destination to FOSSGIS / OpenStreetMap routing.",
              (l10n) => l10n.mobilityAllowSendingStartAnde6a35229,
            ),
          ),
          subtitle: Text(
            context.localized(
              "FOSSGIS logs the route request. Spot names and notes stay in the app.",
              (l10n) => l10n.mobilityFossgisLogsTheRoute7ac53fd4,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed:
              _busy || !_roadConsent || (!_freeDestination && _spot == null)
              ? null
              : () => _run(() async {
                  final origin = _point('origin')!,
                      destination = _freeDestination
                          ? _point('destination')!
                          : _point('parking', optional: true) ??
                                _point('access', optional: true) ??
                                MobilityPoint(
                                  _spot!.latitude,
                                  _spot!.longitude,
                                );
                  final result = await _router.calculate(origin, destination);
                  if (mounted) {
                    setState(() {
                      _route = result;
                      _routeBundle = result;
                    });
                  }
                }),
          icon: const Icon(Icons.directions_car_outlined),
          label: Text(
            context.localized(
              "Calculate driving route",
              (l10n) => l10n.mobilityCalculateDrivingRoute59eac3f8,
            ),
          ),
        ),
        if (_route != null) ...[
          const SizedBox(height: 12),
          Builder(
            builder: (roadContext) => RoadRouteComparison(
              key: ValueKey(_routeBundle),
              routes: _routeBundle?.choices ?? [_route!],
              selected: _route!,
              enabled: _trafficRouting,
              traffic: _traffic,
              counters: _counters,
              onSelected: (route) => setState(() => _route = route),
              onEnabled: (value) => setState(() => _trafficRouting = value),
              onOpenTraffic: () =>
                  DefaultTabController.of(roadContext).animateTo(1),
            ),
          ),
          Text(
            context.localizedWithArgs(
              "{0} km · {1} min estimated",
              [
                (_route!.distanceMeters / 1000).toStringAsFixed(1),
                (_route!.durationSeconds / 60).ceil(),
              ],
              (l10n, value) =>
                  l10n.mobilityKmMinEstimated439c5826(value(0), value(1)),
            ),
          ),
          Text(
            context.localizedWithArgs(
              "Calculated: {0} · {1}. The routing service may snap endpoints to nearby roads.",
              [
                _route!.retrievedUtc.toIso8601String(),
                _freeDestination
                    ? 'Free destination'
                    : 'destination priority: parking → access point → spot',
              ],
              (l10n, value) => l10n.mobilityCalculatedTheRoutingService9f5e2267(
                value(0),
                value(1),
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _run(() => _show(_route!.overlay)),
            child: Text(
              context.localized(
                "Show driving route on map",
                (l10n) => l10n.mobilityShowDrivingRouteOn3860ee86,
              ),
            ),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            FilledButton.icon(
              onPressed: _busy ? null : _startNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Navigation starten'),
            ),
        ],
        _link(
          'OSRM / FOSSGIS · privacy & service policy',
          'https://routing.openstreetmap.de/about.html',
        ),
        _link(
          '© OpenStreetMap contributors · ODbL',
          'https://www.openstreetmap.org/copyright',
        ),
        _link(
          context.localized(
            'Report a map error',
            (l10n) => l10n.mobilityReportAMapError8ddb12c3,
          ),
          'https://www.openstreetmap.org/fixthemap',
        ),
      ],
    ),
  );
  Future<void> _startNavigation() async {
    final route = _route;
    if (route == null || _busy) return;
    bool hasKey, hasCountersKey;
    try {
      hasKey = await _vault.contains(astraTrafficAccess);
      hasCountersKey = await _vault.contains(astraCountersAccess);
    } catch (_) {
      hasKey = false;
      hasCountersKey = false;
    }
    if (!mounted) return;
    var useTraffic = hasKey,
        useCounters = hasCountersKey,
        automaticTraffic = true;
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Navigation starten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.localized(
                    "Bei Routenabweichungen sendet die App Standort und Ziel an FOSSGIS. Der Dienst protokolliert die Anfrage. Im Hintergrund pausiert die Navigation.",
                    (l10n) =>
                        l10n.mobilityBeiRoutenabweichungenSendetDie131b098f,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: useTraffic,
                  onChanged: hasKey
                      ? (value) => update(() => useTraffic = value ?? false)
                      : null,
                  title: Text(
                    context.localized(
                      "ASTRA-Verkehrsmeldungen laden",
                      (l10n) =>
                          l10n.mobilityAstraVerkehrsmeldungenLadenf278469c,
                    ),
                  ),
                  subtitle: Text(
                    hasKey
                        ? context.localized(
                            "Nutzt deinen gespeicherten Zugang. Aktualisierung bei Bedarf in der Navigation; keine Stauzeiten in der Ankunftsschätzung.",
                            (l10n) => l10n
                                .mobilityNutztDeinenGespeichertenZugang06987d0c,
                          )
                        : context.localized(
                            "Zuerst im Traffic-Tab den Token für Road traffic - traffic situations speichern und die Anbieterbedingungen akzeptieren.",
                            (l10n) => l10n.mobilityZuerstImTrafficTab4547f06d,
                          ),
                  ),
                ),
                if (hasCountersKey)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useCounters,
                    onChanged: (v) => update(() => useCounters = v ?? false),
                    title: Text(
                      context.localized(
                        "ASTRA-Messwerte laden",
                        (l10n) => l10n.mobilityAstraMesswerteLadencc594459,
                      ),
                    ),
                    subtitle: Text(
                      context.localized(
                        "Geschwindigkeiten und Fahrzeugraten an bis zu 100 Detektoren im gewählten 30-km-Gebiet.",
                        (l10n) => l10n
                            .mobilityGeschwindigkeitenUndFahrzeugratenAnba71d451,
                      ),
                    ),
                  ),
                if (useTraffic || useCounters)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: automaticTraffic,
                    onChanged: (v) =>
                        update(() => automaticTraffic = v ?? false),
                    title: Text(
                      context.localized(
                        "Verkehr automatisch aktualisieren",
                        (l10n) => l10n
                            .mobilityVerkehrAutomatischAktualisieren83ed17ce,
                      ),
                    ),
                    subtitle: Text(
                      context.localized(
                        "Alle 60 Sekunden, solange die Navigation aktiv ist. Im Hintergrund pausiert der Abruf.",
                        (l10n) => l10n.commonAlleSekundenSolangeDie8b77bd0f,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.localized(
                  "Abbrechen",
                  (l10n) => l10n.commonAbbrechen07af7cb3,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.localized(
                  "Starten",
                  (l10n) => l10n.mobilityStarten2beb7350,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (start != true || !mounted) return;
    RoadNavigation navigation;
    try {
      navigation = RoadNavigation(
        route: route,
        router: _router,
        locations: const DeviceNavigationLocation(),
        traffic: useTraffic ? _provider(SituationalKind.traffic) : null,
        counters: useCounters ? _countersProvider() : null,
        automaticTrafficUpdates:
            (useTraffic || useCounters) && automaticTraffic,
        trafficAwareRouting: _trafficRouting,
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
      return;
    }
    try {
      await widget.globe.setRenderingPaused(true).catchError((Object _) {});
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => RoadNavigationScreen(
            settingsController: widget.globe,
            cachedMaps: widget.cachedMaps,
            navigation: navigation,
            initialMapStyle: widget.globe.mapStyle,
            initialRoadsVisible: widget.globe.roadsVisible,
            initialRoadsOpacity: widget.globe.roadsOpacity,
          ),
        ),
      );
    } finally {
      navigation.dispose();
      unawaited(
        widget.globe.setRenderingPaused(false).catchError((Object _) {}),
      );
    }
  }

  Widget _link(String label, String url) => TextButton.icon(
    onPressed: () => _run(() async {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Unable to open link');
      }
    }),
    icon: const Icon(Icons.open_in_new),
    label: Text(label),
  );
  TrafficCountersProvider _countersProvider() {
    final center =
        (_route == null ? null : _routeBundle)?.points.first ??
        _route?.points.first ??
        widget.initialCenter ??
        (_spot == null
            ? MobilityPoint(46.95, 7.44)
            : MobilityPoint(_spot!.latitude, _spot!.longitude));
    if (_counters != null &&
        _counters!.center.latitude == center.latitude &&
        _counters!.center.longitude == center.longitude) {
      return _counters!;
    }
    _counters?.dispose();
    return _counters = TrafficCountersProvider(
      center: center,
      readKey: () => _vault.readForProvider(astraCountersAccess),
    );
  }

  SituationalProvider _provider(SituationalKind kind) {
    final center = kind == SituationalKind.aircraft
        ? _point('area')!
        : MobilityPoint(47, 8);
    final old = kind == SituationalKind.aircraft ? _aircraft : _traffic;
    if (old != null &&
        old.center.latitude == center.latitude &&
        old.center.longitude == center.longitude) {
      return old;
    }
    old?.dispose();
    final provider = SituationalProvider(
      kind: kind,
      center: center,
      readTrafficKey: () => _vault.readForProvider(astraTrafficAccess),
      tmc: kind == SituationalKind.traffic ? _tmc : null,
    );
    if (kind == SituationalKind.aircraft) {
      _aircraft = provider;
    } else {
      _traffic = provider;
    }
    return provider;
  }

  Future<void> _import(SituationalKind kind) => _run(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: kind == SituationalKind.traffic
              ? 'DATEX XML'
              : 'Aircraft JSON',
          extensions: [kind == SituationalKind.traffic ? 'xml' : 'json'],
        ),
      ],
    );
    if (file == null) return;
    final length = await file.length();
    final maxBytes = kind == SituationalKind.traffic
        ? trafficMaxResponseBytes
        : 4 * 1024 * 1024;
    if (length <= 0 || length > maxBytes) {
      throw FormatException(
        'Choose a snapshot up to ${maxBytes ~/ (1024 * 1024)} MiB.',
      );
    }
    if (kind == SituationalKind.traffic) {
      await _provider(kind).importTrafficStream(file.openRead(0, length));
      return;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (bytes.length + chunk.length > 4 * 1024 * 1024) {
        throw const FormatException('Snapshot too large');
      }
      bytes.add(chunk);
    }
    await _provider(kind).importText(utf8.decode(bytes.takeBytes()));
  });
  Widget _dataset(SituationalKind kind) {
    final provider = kind == SituationalKind.aircraft ? _aircraft : _traffic;
    final dataset = provider?.status.dataset, data = dataset?.data;
    if (provider == null) {
      return Text(
        context.localized(
          "No information loaded. Missing data does not mean clear roads or empty airspace.",
          (l10n) => l10n.mobilityNoInformationLoadedMissing2c3854cc,
        ),
      );
    }
    if (kind == SituationalKind.traffic) {
      return TrafficBulletin(
        provider: provider,
        onShowMap: _busy
            ? null
            : () => _run(
                () => _show({
                  'id': 'traffic',
                  'visible': true,
                  'features': trafficMapFeatures(
                    (provider.status.dataset?.data['features'] as List?) ?? [],
                    latitude: provider.center.latitude,
                    longitude: provider.center.longitude,
                  ),
                }),
              ),
      );
    }
    final features = (data?['features'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(provider.status.dataState.label),
        if (provider.status.error != null)
          Text(
            provider.status.error!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (dataset != null) ...[
          if (kind == SituationalKind.aircraft &&
              (dataset.publishedAtUtc == null ||
                  dataset.publishedAtUtc!.difference(DateTime.now().toUtc()) >
                      const Duration(seconds: 5) ||
                  DateTime.now().toUtc().difference(dataset.publishedAtUtc!) >
                      const Duration(seconds: 30)))
            Text(
              context.localized(
                "Source snapshot is delayed, its publication time is unknown, or the source/device clocks disagree. Retrieval/import time does not make old positions current.",
                (l10n) => l10n.commonSourceSnapshotIsDelayed341226cb,
              ),
            ),
          Text(
            context.localizedWithArgs(
              "{0}\n{1}\nRetrieved/imported: {2}\nSource publication: {3}\nDataset validity: not declared; individual records may provide dates.",
              [
                provider.source.attribution,
                data?['transport'],
                dataset.fetchedAtUtc.toIso8601String(),
                dataset.publishedAtUtc?.toIso8601String() ?? "unknown",
              ],
              (l10n, value) =>
                  l10n.mobilityRetrievedImportedSourcePublicationadd5e4e8(
                    value(0),
                    value(1),
                    value(2),
                    value(3),
                  ),
            ),
          ),
          Text(
            context.localizedWithArgs(
              "{0}\n{1} positioned records · {2} without usable positions · {3} omitted.",
              [
                data?['coverage'],
                features.length,
                data?['unlocated'],
                data?['omitted'],
              ],
              (l10n, value) =>
                  l10n.mobilityPositionedRecordsWithoutUsable456e69a4(
                    value(0),
                    value(1),
                    value(2),
                    value(3),
                  ),
            ),
          ),
          if (kind == SituationalKind.aircraft)
            Text(
              context.localized(
                "Snapshots are delayed and incomplete. Amber markers are older than 30 seconds; positions older than 5 minutes are hidden. Markers sit on the terrain; reported aircraft altitudes are available in details. Never use this to replace visual airspace observation or official aviation information.",
                (l10n) => l10n.mobilitySnapshotsAreDelayedAnd4458e3d6,
              ),
            ),
          if (features.isNotEmpty)
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _show({
                        'id': kind.name,
                        'visible': true,
                        'features': features,
                      }),
                    ),
              child: Text(
                context.localized(
                  "Show snapshot on map",
                  (l10n) => l10n.mobilityShowSnapshotOnMap1ce6224b,
                ),
              ),
            ),
          for (final raw in features.take(100))
            ExpansionTile(
              title: Text((raw as Map)['name'] as String),
              subtitle: Text('${raw['geometry']['coordinates']}'),
              children: [SelectableText(raw['detail'] as String)],
            ),
          if (features.length > 100)
            Text(
              context.localized(
                "First 100 details shown here. Other positioned records remain selectable on the map.",
                (l10n) => l10n.mobilityFirstDetailsShownHere859f2457,
              ),
            ),
          for (final raw in (data?['unlocatedRecords'] as List? ?? const []))
            ExpansionTile(
              title: Text(
                context.localizedWithArgs("Unlocated · {0}", [
                  (raw as Map)["name"],
                ], (l10n, value) => l10n.mobilityUnlocated0f6d01d4(value(0))),
              ),
              children: [SelectableText(raw['detail'] as String)],
            ),
        ],
        _link(
          'Source API & documentation',
          provider.source.metadataUri.toString(),
        ),
        _link('Source terms', provider.source.licenseUri.toString()),
      ],
    );
  }

  Widget _trafficPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.localized(
          "ASTRA / VMZ-CH traffic situations · Swiss road network. Registered API access is required. TMC-only references require the matching official topology. Unlocated or uncertain messages remain information; sufficiently matched current data can be enabled for route comparison.",
          (l10n) => l10n.mobilityAstraVmzChTraffic19a07166,
        ),
      ),
      _link(
        'ASTRA access, terms and six-month standard access',
        'https://opentransportdata.swiss/de/tac-fedro/',
      ),
      _link(
        'Register your own free-tier API access',
        'https://api-manager.opentransportdata.swiss/',
      ),
      if (kIsWeb)
        Text(
          context.localized(
            "The ASTRA API rejects direct browser requests (CORS), before a token can be sent. Use Android for direct refresh, or import a DATEX XML snapshot downloaded with your own registered access. No public proxy is used.",
            (l10n) => l10n.commonTheAstraApiRejectsdfbcd277,
          ),
        ),
      if (!kIsWeb) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _trafficTerms,
          onChanged: (v) => setState(() => _trafficTerms = v ?? false),
          title: Text(
            context.localized(
              "I have registered access and accepted the provider terms for my own use.",
              (l10n) => l10n.mobilityIHaveRegisteredAccessa282c504,
            ),
          ),
        ),
        TextField(
          controller: _key,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.localized(
              "Own ASTRA API key",
              (l10n) => l10n.mobilityOwnAstraApiKey38bbd3b9,
            ),
            helperText: context.localized(
              "Use the Token for Road traffic - traffic situations, not Token Hash or OJP.",
              (l10n) => l10n.commonUseTheTokenFor892c903f,
            ),
            helperMaxLines: 3,
          ),
        ),
        Text(
          context.localized(
            "Keys use device secure storage and are sent only to the official ASTRA endpoint.",
            (l10n) => l10n.mobilityKeysUseDeviceSecuref60f66e8,
          ),
        ),
      ],
      Wrap(
        spacing: 8,
        children: [
          if (!kIsWeb)
            OutlinedButton(
              onPressed: _busy || !_trafficTerms
                  ? null
                  : () => _run(() async {
                      await _vault.save(astraTrafficAccess, _key.text.trim());
                      _key.clear();
                      if (mounted) setState(() => _message = 'API key saved.');
                    }),
              child: Text(
                context.localized(
                  "Save key",
                  (l10n) => l10n.commonSaveKeyf5216b3a,
                ),
              ),
            ),
          if (!kIsWeb)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _vault.remove(astraTrafficAccess)),
              child: Text(
                context.localized(
                  "Remove key",
                  (l10n) => l10n.commonRemoveKey582d9a78,
                ),
              ),
            ),
          FilledButton(
            onPressed: _busy || !_trafficTerms || kIsWeb
                ? null
                : () => _run(() async {
                    await _provider(SituationalKind.traffic)
                        .fetch(forceRefresh: true);
                  }),
            child: Text(
              context.localized(
                "Refresh traffic",
                (l10n) => l10n.mobilityRefreshTrafficde6624d5,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _import(SituationalKind.traffic),
            child: Text(
              context.localized(
                "Import DATEX XML",
                (l10n) => l10n.mobilityImportDatexXml5eb44537,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _dataset(SituationalKind.traffic),
      TmcSection(
        repository: _tmc,
        provider: _provider(SituationalKind.traffic),
      ),
      TrafficCountersSection(provider: _countersProvider(), onShowMap: _show),
      _link(
        'Weitere offizielle Daten: Geschwindigkeiten und Fahrzeugmengen an Zählstellen',
        'https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/rt-road-traffic-counters/',
      ),
    ],
  );
  Widget _aircraftPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.localized(
          "Optional adsb.lol community reception snapshot within 25 nautical miles (≈46 km). No automatic polling, history or extrapolation. No data is downloaded until requested. OpenSky is not used because application integration requires a written licence.",
          (l10n) => l10n.commonOptionalAdsbLolCommunity571b79fc,
        ),
      ),
      _pointFields('area', 'Search area centre'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _airConsent,
        onChanged: (v) => setState(() => _airConsent = v ?? false),
        title: Text(
          context.localized(
            "Allow sending this area centre to adsb.lol.",
            (l10n) => l10n.mobilityAllowSendingThisAread1710796,
          ),
        ),
      ),
      if (kIsWeb)
        Text(
          context.localized(
            "Direct browser requests are blocked by the provider CORS policy. Import a readsb/adsb.lol JSON snapshot or use Android; no public proxy is involved.",
            (l10n) => l10n.mobilityDirectBrowserRequestsAre8f6307e5,
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: _busy || !_airConsent || kIsWeb
                ? null
                : () => _run(() async {
                    await _provider(SituationalKind.aircraft)
                        .fetch(forceRefresh: true);
                  }),
            child: Text(
              context.localized(
                "Refresh aircraft",
                (l10n) => l10n.mobilityRefreshAircraftcf46fb55,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _import(SituationalKind.aircraft),
            child: Text(
              context.localized(
                "Import aircraft JSON",
                (l10n) => l10n.mobilityImportAircraftJson444ad3f1,
              ),
            ),
          ),
        ],
      ),
      _link('adsb.lol source map', 'https://www.adsb.lol/'),
      const SizedBox(height: 12),
      _dataset(SituationalKind.aircraft),
    ],
  );
  Widget _page(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 8,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Mobility & OSINT",
            (l10n) => l10n.mobilityMobilityOsint1a8134ea,
          ),
        ),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Road route'),
            Tab(text: 'Public transport'),
            Tab(text: 'Traffic'),
            Tab(text: 'Aircraft'),
            Tab(text: 'Environment'),
            Tab(text: 'Nearby POIs'),
            Tab(text: 'EV Charging'),
            Tab(text: 'Shared Mobility'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
          Expanded(
            child: TabBarView(
              children: [
                _page(_road()),
                _page(
                  Builder(
                    builder: (transportContext) => PublicTransportSection(
                      onShowNearbyMobility: (center) {
                        setState(() => _sharedMobilityCenter = center);
                        DefaultTabController.of(transportContext).animateTo(7);
                      },
                      spots: widget.spots,
                      preferences: widget.preferences,
                      globe: widget.globe,
                      initialSpotId: widget.initialSpotId,
                      initialMapPoint: widget.initialCenter,
                    ),
                  ),
                ),
                _page(_trafficPage()),
                _page(_aircraftPage()),
                _page(
                  SituationalLayersSection(
                    globe: widget.globe,
                    initialCenter:
                        widget.initialCenter ??
                        (_spot == null
                            ? null
                            : MobilityPoint(_spot!.latitude, _spot!.longitude)),
                  ),
                ),
                _page(
                  OsmPoiSection(
                    spots: widget.spots,
                    preferences: widget.preferences,
                    globe: widget.globe,
                    initialSpotId: widget.initialSpotId,
                    initialMapPoint: widget.initialCenter,
                  ),
                ),
                _page(
                  Builder(
                    builder: (tabContext) => EvChargingSection(
                      spots: widget.spots,
                      globe: widget.globe,
                      route: _route,
                      initialSpotId: widget.initialSpotId,
                      initialMapPoint: widget.initialCenter,
                      onDriveTo: (EvChargingStation station) {
                        setState(() {
                          _freeDestination = true;
                          _destinationName = station.name;
                          _fields['destinationLat']!.text =
                              '${station.latitude}';
                          _fields['destinationLon']!.text =
                              '${station.longitude}';
                          _route = null;
                          _routeBundle = null;
                        });
                        DefaultTabController.of(tabContext).animateTo(0);
                      },
                    ),
                  ),
                ),
                _page(
                  SharedMobilitySection(
                    spots: widget.spots,
                    globe: widget.globe,
                    initialSpotId: widget.initialSpotId,
                    initialMapPoint:
                        _sharedMobilityCenter ?? widget.initialCenter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
